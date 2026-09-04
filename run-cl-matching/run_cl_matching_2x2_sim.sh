#!/usr/bin/env bash
#
# 2x2 charge-light matching (simulation) -- .PT-FIRST, IDENTICAL logic to ND.
#
# Input  : run-ndlar-flow/<IN_NAME>/FLOW/<subDir>/<inName>.FLOW.hdf5
#          (a 2x2-configured flow file)
# Output : run-cl-matching/<OUT_NAME>/PT/<subDir>/<outName>.qlmatch2x2.pt   (source of truth)
#          run-cl-matching/<OUT_NAME>/FLOW/<subDir>/<outName>.FLOW.hdf5     (HDF5 filled from the .pt)
#
# Workflow (per file, matches run_cl_matching_ND_sim.sh):
#   1. Check if the .pt exists at the canonical PT/<subDir>/<outName>.qlmatch2x2.pt.
#      If yes -> skip the pipeline entirely; the .pt is the source of truth.
#      If no  -> run the pipeline, produce the .pt, move to that path.
#   2. Always fill a fresh copy of the flow HDF5 from the .pt (writing t_0,
#      t_cluster_id, t_confidence into charge/calib_prompt_hits AND
#      calib_final_hits) and move it to outDir/FLOW/<subDir>/.
#
# NOTE: for 2x2 sim files that PRE-DATE the ndlar_flow t_0-f4 dtype bump, the
# HDF5 has no reserved fields to fill; apply_pt_to_hdf5.py silently skips each
# missing field (the .pt is still the authoritative output). Regenerate the 2x2
# flow file with the current ndlar_flow to get real fill.
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

flowDstDir=$outDir/FLOW/$subDir
ptDstDir=$outDir/PT/$subDir
ptName=${outName}.qlmatch2x2.pt
ptFile=$ptDstDir/$ptName
outFile=$tmpOutDir/${outName}.FLOW.hdf5
workDir=$tmpOutDir/${outName}_work
rm -f "$outFile"
rm -rf "$workDir"

set -o errexit
mkdir -p "$flowDstDir" "$ptDstDir" "$workDir"

# ---- Stage 1: ensure the .pt exists ----
if [[ -f "$ptFile" ]]; then
    echo "PT cache hit: $ptFile"
    echo "  Skipping 2x2 pipeline; PT is the source of truth for this file."
else
    echo "PT cache miss: building $ptFile"
    cd "$CLMATCH_REPO"
    run env FILE="$inFile" \
        VERSION="$VERSION" \
        OUT_DIR="$workDir" \
        PT_DIR="$workDir/pt_outputs" \
        LOG_DIR="$workDir/logs" \
        PY="$PY" HERE="$CLMATCH_REPO" \
        bash scripts/run_2x2_sim.sh

    # The aggregator names the .pt as '<full basename incl. .hdf5>.qlmatch2x2.pt'
    # (it keeps the .hdf5 in the .pt filename).
    srcBasename=$(basename "$inFile")
    producedPt="$workDir/pt_outputs/${srcBasename}.qlmatch2x2.pt"
    if [[ ! -f "$producedPt" ]]; then
        echo "ERROR: expected .pt not found at $producedPt" >&2
        ls -la "$workDir/pt_outputs" >&2 || true
        exit 2
    fi
    mv "$producedPt" "$ptFile"
fi

# ---- Stage 2: apply .pt to a fresh copy of the flow HDF5, then publish ----
echo "Copying input flow file for fill:"
echo "  $inFile -> $outFile"
cp "$inFile" "$outFile"

run "$PY" "$ND_PRODUCTION_DIR/run-cl-matching/apply_pt_to_hdf5.py" \
    --pt "$ptFile" \
    --hdf5 "$outFile" \
    --summary-json "$workDir/qlmatch2x2_applier_summary.json"

mv "$outFile" "$flowDstDir/"

# preserve worker logs / applier summary; drop bulky shards.
mkdir -p "$logDir"
if compgen -G "$workDir/logs/worker*.log" > /dev/null; then
    mkdir -p "$logDir/${outName}_worker_logs"
    cp "$workDir/logs"/worker*.log "$logDir/${outName}_worker_logs/" 2>/dev/null || true
fi
[[ -f "$workDir/qlmatch2x2_applier_summary.json" ]] && \
    cp "$workDir/qlmatch2x2_applier_summary.json" "$logDir/${outName}_qlmatch2x2_applier_summary.json"
rm -rf "$workDir"
