#!/usr/bin/env bash
#
# 2x2 charge-light matching (real DATA) -- .PT-FIRST.
#
# Real 2x2 DAQ flow files are NOT produced by ND_Production's run-ndlar-flow
# step; they live on the dune cfs area (or wherever the user points us). The
# input file is therefore identified by env var rather than the production
# IN_NAME / INDEX convention used by sim steps.
#
# Input  : $ND_PRODUCTION_CLMATCH_DATA_FILE (absolute path to a 2x2 reflow file)
#          default = /global/cfs/cdirs/dune/www/data/2x2/reflows/v10/flow/beam/
#                    july10_2024/nominal_hv/packet-0050018-2024_07_10_09_36_12_CDT.FLOW.hdf5
# Output : run-cl-matching/<OUT_NAME>/PT/<subDir>/<outName>.qlmatch2x2.pt
#
# Workflow (mirrors the ND wrapper's .pt-first pattern):
#   1. Check if the .pt already exists at the canonical PT/<subDir>/<outName>.qlmatch2x2.pt.
#   2. If yes -> skip the pipeline entirely; the .pt is the source of truth.
#      If no  -> run the pipeline and move the produced .pt to that path.
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

ptDstDir=$outDir/PT/$subDir
ptName=${outName}.qlmatch2x2.pt
ptFile=$ptDstDir/$ptName

set -o errexit
mkdir -p "$ptDstDir"

# ---- Stage 1: PT-first check ----
if [[ -f "$ptFile" ]]; then
    echo "PT cache hit: $ptFile"
    echo "  Skipping 2x2 pipeline; PT is the source of truth for this file."
    exit 0
fi
echo "PT cache miss: building $ptFile"

workDir=$tmpOutDir/${outName}_work
rm -rf "$workDir"
mkdir -p "$workDir"

cd "$CLMATCH_REPO"

run env FILE="$inFile" \
    VERSION="$VERSION" \
    OUT_DIR="$workDir" \
    PT_DIR="$workDir/pt_outputs" \
    LOG_DIR="$workDir/logs" \
    PY="$PY" HERE="$CLMATCH_REPO" \
    bash scripts/run_2x2_data.sh

# The aggregator names the .pt as '<full basename incl. .hdf5>.qlmatch2x2.pt'.
srcBasename=$(basename "$inFile")
producedPt="$workDir/pt_outputs/${srcBasename}.qlmatch2x2.pt"
if [[ ! -f "$producedPt" ]]; then
    echo "ERROR: expected .pt not found at $producedPt" >&2
    echo "       contents of $workDir/pt_outputs:" >&2
    ls -la "$workDir/pt_outputs" >&2 || true
    exit 3
fi

mv "$producedPt" "$ptFile"
rm -f "$workDir"/*.npz "$workDir"/*.json
