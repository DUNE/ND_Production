#!/usr/bin/env bash
#
# 2x2 charge-light matching (simulation).
#
# Input  : run-ndlar-flow/<IN_NAME>/FLOW/<subDir>/<inName>.FLOW.hdf5
#          (a 2x2-configured flow file)
# Output : run-cl-matching/<OUT_NAME>/PT/<subDir>/<outName>.qlmatch2x2.pt
#
# The 2x2 workflow always produces a .pt (the 2x2 calib_*_hits dtypes do not
# yet reserve t_0/t_cluster_id, so we cannot do in-place HDF5 writeback).
#
# Algorithm version (env ND_PRODUCTION_CLMATCH_VERSION):
#   v1.0 (default) = error-matrix small-cluster association (greedy, unit-var)
#   v2.0           = region-grow + learned-variance tiebreaker
#
# Requires a 4-GPU node. On Perlmutter:
#   salloc -A dune -q interactive -C gpu --gpus-per-node=4 -N 1 -t 60 \
#     srun -N1 -n1 --gpus-per-node=4 ./run_cl_matching_2x2_sim.sh

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

CLMATCH_REPO=${ND_PRODUCTION_CLMATCH_REPO:-"$ND_PRODUCTION_INSTALL_DIR/CLMatching_AlphaRelease"}
PY=${PY:-/global/common/software/nersc/pe/conda-envs/26.1.0/python-3.13/nersc-python/bin/python}
VERSION=${ND_PRODUCTION_CLMATCH_VERSION:-v1.0}

if [[ ! -d "$CLMATCH_REPO" ]]; then
    echo "ERROR: CLMatching repo not found at $CLMATCH_REPO"
    echo "       Run ./install_cl_matching.sh first, or set ND_PRODUCTION_CLMATCH_REPO." >&2
    exit 1
fi

inDir=${ND_PRODUCTION_OUTDIR_BASE}/run-ndlar-flow/$ND_PRODUCTION_IN_NAME
inName=$ND_PRODUCTION_IN_NAME.$globalIdx
inFile=$(realpath $inDir/FLOW/$subDir/${inName}.FLOW.hdf5)

# 2x2 produces a .pt, not a modified HDF5. Stage workers/shards in a per-file
# tmp dir; mv the final .pt into the canonical outDir at the end.
workDir=$tmpOutDir/${outName}_work
ptName=${outName}.qlmatch2x2.pt
rm -rf "$workDir"

set -o errexit
mkdir -p "$workDir"

cd "$CLMATCH_REPO"

run env FILE="$inFile" \
    VERSION="$VERSION" \
    OUT_DIR="$workDir" \
    PT_DIR="$workDir/pt_outputs" \
    LOG_DIR="$workDir/logs" \
    PY="$PY" HERE="$CLMATCH_REPO" \
    bash scripts/run_2x2_sim.sh

# The aggregator names the .pt as '<full basename incl. .hdf5>.qlmatch2x2.pt'
# (yes, it keeps the .hdf5 in the .pt filename).
srcBasename=$(basename "$inFile")
producedPt="$workDir/pt_outputs/${srcBasename}.qlmatch2x2.pt"
if [[ ! -f "$producedPt" ]]; then
    echo "ERROR: expected .pt not found at $producedPt" >&2
    echo "       contents of $workDir/pt_outputs:" >&2
    ls -la "$workDir/pt_outputs" >&2 || true
    exit 2
fi

mkdir -p "$outDir/PT/$subDir"
mv "$producedPt" "$outDir/PT/$subDir/$ptName"
# Keep worker logs for debugging; drop the per-event NPZ shards (large, transient).
rm -f "$workDir"/*.npz "$workDir"/*.json
