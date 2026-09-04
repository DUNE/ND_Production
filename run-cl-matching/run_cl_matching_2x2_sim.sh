#!/usr/bin/env bash
#
# 2x2 charge-light matching (simulation) -- .PT-FIRST.
#
# Input  : run-ndlar-flow/<IN_NAME>/FLOW/<subDir>/<inName>.FLOW.hdf5
#          (a 2x2-configured flow file)
# Output : run-cl-matching/<OUT_NAME>/PT/<subDir>/<outName>.qlmatch2x2.pt
#          (the .pt IS the output; no HDF5 modification for 2x2)
#
# Workflow (mirrors the ND wrapper's .pt-first pattern):
#   1. Check if the .pt already exists at the canonical PT/<subDir>/<outName>.qlmatch2x2.pt.
#   2. If yes -> skip the pipeline entirely; the .pt is the source of truth.
#      If no  -> run the pipeline and move the produced .pt to that path.
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
    bash scripts/run_2x2_sim.sh

# The aggregator names the .pt as '<full basename incl. .hdf5>.qlmatch2x2.pt'
# (it keeps the .hdf5 in the .pt filename).
srcBasename=$(basename "$inFile")
producedPt="$workDir/pt_outputs/${srcBasename}.qlmatch2x2.pt"
if [[ ! -f "$producedPt" ]]; then
    echo "ERROR: expected .pt not found at $producedPt" >&2
    echo "       contents of $workDir/pt_outputs:" >&2
    ls -la "$workDir/pt_outputs" >&2 || true
    exit 2
fi

mv "$producedPt" "$ptFile"
# Keep worker logs for debugging; drop the per-event NPZ shards (large, transient).
rm -f "$workDir"/*.npz "$workDir"/*.json
