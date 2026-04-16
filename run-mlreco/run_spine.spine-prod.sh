#!/usr/bin/env bash

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-deeplearnphysics/larcv2:ub2204-cu124-torch251-larndsim}

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

source load_mlreco.inc.sh

# Only export onwards if the vars are filled. The exports are a tip from Kazu and
# required for NDLAr.
[ -n "$ND_PRODUCTION_SPINE_NUM_THREADS" ] && export NUM_THREADS=$ND_PRODUCTION_SPINE_NUM_THREADS
[ -n "$ND_PRODUCTION_SPINE_OPENBLAS_NUM_THREADS" ] && export OPENBLAS_NUM_THREADS=$ND_PRODUCTION_SPINE_OPENBLAS_NUM_THREADS

outFile=${tmpOutDir}/${outName}.MLRECO_SPINE.hdf5
inName=${ND_PRODUCTION_IN_NAME}.${globalIdx}
inFile=${ND_PRODUCTION_OUTDIR_BASE}/run-mlreco/${ND_PRODUCTION_IN_NAME}/LARCV/${subDir}/${inName}.LARCV.root

rm -f "$outFile"

source install/spine-prod/configure.sh


run python3 install/spine/bin/run.py \
    --config "$ND_PRODUCTION_SPINE_CONFIG" \
    --log-dir "$logDir" \
    --source "$inFile" \
    --output "$outFile"


infOutDir=${outDir}/MLRECO_SPINE/${subDir}
mkdir -p "$infOutDir"
mv "$outFile" "$infOutDir/"
