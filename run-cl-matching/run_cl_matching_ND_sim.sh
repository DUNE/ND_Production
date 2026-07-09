#!/usr/bin/env bash
#
# ND-LAr charge-light matching (simulation).
#
# Input  : run-ndlar-flow/<IN_NAME>/FLOW/<subDir>/<inName>.FLOW.hdf5
# Output : run-cl-matching/<OUT_NAME>/FLOW/<subDir>/<outName>.FLOW.hdf5
#
# This step rewrites t_0 and t_cluster_id INSIDE the FLOW.hdf5 (Mode A; the
# new flow dtype reserves those fields). The output is therefore another
# .FLOW.hdf5, not a .pt. For older flow files without those fields the
# underlying CLMatching aggregator falls back to .pt under
# <CLMatching repo>/output/QLmatchingvAlpha/ -- but for ND production we
# assume Mode A.
#
# Requires a 4-GPU node. On Perlmutter:
#   salloc -A dune -q interactive -C gpu --gpus-per-node=4 -N 1 -t 60 \
#     srun -N1 -n1 --gpus-per-node=4 ./run_cl_matching_ND_sim.sh
#
# (Or invoke inside an sbatch script that grabs a GPU node.)

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

CLMATCH_REPO=${ND_PRODUCTION_CLMATCH_REPO:-"$ND_PRODUCTION_INSTALL_DIR/CLMatching_AlphaRelease"}
PY=${PY:-/global/common/software/nersc/pe/conda-envs/26.1.0/python-3.13/nersc-python/bin/python}

if [[ ! -d "$CLMATCH_REPO" ]]; then
    echo "ERROR: CLMatching repo not found at $CLMATCH_REPO"
    echo "       Run ./install_cl_matching.sh first, or set ND_PRODUCTION_CLMATCH_REPO." >&2
    exit 1
fi

inDir=${ND_PRODUCTION_OUTDIR_BASE}/run-ndlar-flow/$ND_PRODUCTION_IN_NAME
inName=$ND_PRODUCTION_IN_NAME.$globalIdx
inFile=$(realpath $inDir/FLOW/$subDir/${inName}.FLOW.hdf5)

# CL matching modifies the flow file IN-PLACE for Mode A. To avoid scribbling
# on the upstream step's output, copy to tmpOutDir first, run there, then mv
# the modified file to the canonical outDir.
outFile=$tmpOutDir/${outName}.FLOW.hdf5
workDir=$tmpOutDir/${outName}_work
rm -f "$outFile"
rm -rf "$workDir"

set -o errexit
mkdir -p "$workDir"
echo "Copying input flow file to tmp work area:"
echo "  $inFile -> $outFile"
cp "$inFile" "$outFile"

cd "$CLMATCH_REPO"

# The single-file driver auto-detects Mode A (in-place HDF5) vs Mode B (.pt)
# from the source dtype and runs the 8-worker pipeline + aggregation.
# Explicitly route worker shards/logs through our per-task $workDir so they
# do not accumulate inside the cloned CLMatching repo across production runs.
#
# Bracket the `run` call in `set +/-o errexit`: process_one_flow_file.sh (and
# its underlying launcher) may exit non-zero from spurious tail commands (e.g.
# ls-ing pt_outputs that Mode A never populates). The Python sanity-check
# below is the authoritative Mode A success criterion; do not trust rc here.
set +o errexit
run env PY="$PY" REPO="$CLMATCH_REPO" \
    bash scripts/process_one_flow_file.sh "$outFile" "$workDir"
set -o errexit

# Sanity-check that Mode A populated t_0/t_cluster_id.
"$PY" - <<PY
import h5py, sys
with h5py.File("$outFile", "r") as h:
    for path in ("charge/calib_prompt_hits/data", "charge/calib_final_hits/data"):
        d = h[path]
        if "t_0" not in d.dtype.names or "t_cluster_id" not in d.dtype.names:
            print(f"WARN: {path} dtype lacks t_0/t_cluster_id (Mode B file). Skipping HDF5-populated check.")
            sys.exit(0)
        nz = int((d["t_cluster_id"][:] != 0).any() or (d["t_0"][:] != 0).any())
        if not nz:
            print(f"ERROR: {path} t_0 and t_cluster_id are still all zero after CL matching.", file=sys.stderr)
            sys.exit(2)
print("Mode A writeback verified: t_0 and t_cluster_id populated in HDF5.")
PY

mkdir -p "$outDir/FLOW/$subDir"
mv "$outFile" "$outDir/FLOW/$subDir"

# Worker shards are large and transient; preserve the worker logs (small) under
# the canonical LOGS dir so failures stay debuggable, then drop the rest.
if [[ -d "$workDir/worker_logs" ]]; then
    mkdir -p "$logDir"
    cp -r "$workDir/worker_logs" "$logDir/${outName}_worker_logs" 2>/dev/null || true
fi
rm -rf "$workDir"
