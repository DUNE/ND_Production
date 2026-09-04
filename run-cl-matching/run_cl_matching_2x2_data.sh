#!/usr/bin/env bash
#
# 2x2 charge-light matching (real DATA) -- .PT-FIRST, IDENTICAL logic to ND.
#
# Real 2x2 DAQ flow files are NOT produced by ND_Production's run-ndlar-flow
# step; they live on the dune cfs area (or wherever the user points us). The
# input file is therefore identified by env var rather than the production
# IN_NAME / INDEX convention used by sim steps.
#
# Input  : $ND_PRODUCTION_CLMATCH_DATA_FILE (absolute path to a 2x2 reflow file)
#          default = /global/cfs/cdirs/dune/www/data/2x2/reflows/v10/flow/beam/
#                    july10_2024/nominal_hv/packet-0050018-2024_07_10_09_36_12_CDT.FLOW.hdf5
# Output : run-cl-matching/<OUT_NAME>/PT/<subDir>/<outName>.qlmatch2x2.pt   (source of truth)
#          run-cl-matching/<OUT_NAME>/FLOW/<subDir>/<outName>.FLOW.hdf5     (HDF5 filled from the .pt)
#
# Workflow (per file, matches run_cl_matching_ND_sim.sh):
#   1. Check if the .pt exists at the canonical PT/<subDir>/<outName>.qlmatch2x2.pt.
#      If yes -> skip the pipeline entirely; the .pt is the source of truth.
#      If no  -> run the pipeline, produce the .pt, move to that path.
#   2. Always fill a fresh copy of the flow HDF5 from the .pt and move it to
#      outDir/FLOW/<subDir>/.
#
# NOTE: 2x2 DAQ reflow files were built with the old ndlar_flow and don't have
# t_0/t_cluster_id/t_confidence in the compound dtype yet. apply_pt_to_hdf5.py
# silently skips missing fields; the .pt is still the authoritative output.
# Once the reflow chain is updated to the new ndlar_flow dtype, the fill will
# start populating those fields automatically.
#
# Algorithm version (env ND_PRODUCTION_CLMATCH_VERSION):
#   v1.0 (default) = error-matrix small-cluster association
#   v2.0           = region-grow + learned-variance tiebreaker
#
# Requires a 4-GPU node. On Perlmutter:
#   salloc -A dune -q interactive -C gpu --gpus-per-node=4 -N 1 -t 60 \
#     srun -N1 -n1 --gpus-per-node=4 ./run_cl_matching_2x2_data.sh

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

CLMATCH_REPO=${ND_PRODUCTION_CLMATCH_REPO:-"$ND_PRODUCTION_INSTALL_DIR/CLMatching_AlphaRelease"}
PY=${PY:-/global/common/software/nersc/pe/conda-envs/26.1.0/python-3.13/nersc-python/bin/python}
VERSION=${ND_PRODUCTION_CLMATCH_VERSION:-v1.0}

DEFAULT_DATA_FILE=/global/cfs/cdirs/dune/www/data/2x2/reflows/v10/flow/beam/july10_2024/nominal_hv/packet-0050018-2024_07_10_09_36_12_CDT.FLOW.hdf5
inFile=${ND_PRODUCTION_CLMATCH_DATA_FILE:-$DEFAULT_DATA_FILE}

if [[ ! -d "$CLMATCH_REPO" ]]; then
    echo "ERROR: CLMatching repo not found at $CLMATCH_REPO"
    echo "       Run ./install_cl_matching.sh first, or set ND_PRODUCTION_CLMATCH_REPO." >&2
    exit 1
fi
if [[ ! -f "$inFile" ]]; then
    echo "ERROR: input data file not found: $inFile"
    echo "       Set ND_PRODUCTION_CLMATCH_DATA_FILE to point at a 2x2 reflow .FLOW.hdf5." >&2
    exit 2
fi

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
        bash scripts/run_2x2_data.sh

    srcBasename=$(basename "$inFile")
    producedPt="$workDir/pt_outputs/${srcBasename}.qlmatch2x2.pt"
    if [[ ! -f "$producedPt" ]]; then
        echo "ERROR: expected .pt not found at $producedPt" >&2
        ls -la "$workDir/pt_outputs" >&2 || true
        exit 3
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

mkdir -p "$logDir"
if compgen -G "$workDir/logs/worker*.log" > /dev/null; then
    mkdir -p "$logDir/${outName}_worker_logs"
    cp "$workDir/logs"/worker*.log "$logDir/${outName}_worker_logs/" 2>/dev/null || true
fi
[[ -f "$workDir/qlmatch2x2_applier_summary.json" ]] && \
    cp "$workDir/qlmatch2x2_applier_summary.json" "$logDir/${outName}_qlmatch2x2_applier_summary.json"
rm -rf "$workDir"
