#!/usr/bin/env bash

# export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-deeplearnphysics/larcv2:ub20.04-cuda11.6-pytorch1.13-larndsim}
export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-deeplearnphysics/larcv2:ub2204-cu124-torch251-larndsim}

source ../util/reload_in_container.inc.sh
source ../util/init.data.inc.sh

source load_mlreco.inc.sh

[ -z "$ND_PRODUCTION_SPINE_CONFIG" ] && export ND_PRODUCTION_SPINE_CONFIG="2x2_full_chain_data_240819.cfg"

# Only export onwards if the vars are filled. The exports are a tip from Kazu and
# required for NDLAr.
[ -n "$ND_PRODUCTION_SPINE_NUM_THREADS" ] && export NUM_THREADS=$ND_PRODUCTION_SPINE_NUM_THREADS
[ -n "$ND_PRODUCTION_SPINE_OPENBLAS_NUM_THREADS" ] && export OPENBLAS_NUM_THREADS=$ND_PRODUCTION_SPINE_OPENBLAS_NUM_THREADS

outName=$(basename "$ND_PRODUCTION_CHARGE_FILE" .h5).MLRECO_SPINE$ND_PRODUCTION_FILE_TAG.hdf5
# outFile=${tmpOutDir}/${outName}
inName=$(basename "$ND_PRODUCTION_CHARGE_FILE" .h5).LARCV$ND_PRODUCTION_FILE_TAG.root
inFile=${ND_PRODUCTION_SUPERA_DIR_BASE}/${relDir}/${inName}

config=$ND_PRODUCTION_SPINE_CONFIG

tmpDir=$(mktemp -d)
mkdir "${tmpDir}/log_trash"

sed "s!%TMPDIR%!${tmpDir}!g" "configs/${config}" > "${tmpDir}/${config}"

run python3 install/spine/bin/run.py \
    --config "${tmpDir}/${config}" \
    --log-dir "$logDir" \
    --source "$inFile" \
    --output "${tmpDir}/hack"

# mv "${outFile}" "${outDir}/${outName}"

mv ${tmpDir}/*hack* "${outDir}/${outName}"

rm -rf "$tmpDir"

echo "Written to $(realpath "${outDir}/${outName}")"
