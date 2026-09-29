#!/usr/bin/env bash

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-fermilab/fnal-wn-sl7:latest}

source ../util/reload_in_container.inc.sh

set +o errexit
source install/ND_CAFMaker/install/bin/ndcaf_setup.sh prof
set -o errexit

# Must go after ndcaf_setup.sh
source ../util/init.inc.sh
# Prevent excessive memory use
export OMP_NUM_THREADS=1

outFile=${tmpOutDir}/${outName}.CAF.root
flatOutFile=${tmpOutDir}/${outName}.CAF.flat.root
cfgFile=$(mktemp --suffix .cfg)

tmpDir=$(mktemp -d)

# Compulsory arguments regardless of use case.
args_gen_cafmaker_cfg=( \
    --caf-path "$outFile" \
    --cfg-file "$cfgFile"
    )


if [[ -n "$ND_PRODUCTION_SPINE_NAME" ]]; then
    spinePath=${ND_PRODUCTION_OUTDIR_BASE}/run-mlreco/${ND_PRODUCTION_SPINE_NAME}/MLRECO_SPINE/${subDir}/${ND_PRODUCTION_SPINE_NAME}.${fileId}.MLRECO_SPINE.hdf5
    args_gen_cafmaker_cfg+=( --spine-path "$spinePath" )
fi

if [[ -n "$ND_PRODUCTION_PANDORA_NAME" ]]; then
    pandoraPath=${ND_PRODUCTION_OUTDIR_BASE}/run-pandora/${ND_PRODUCTION_PANDORA_NAME}/LAR_RECO_ND/${subDir}/${ND_PRODUCTION_PANDORA_NAME}.${fileId}.LAR_RECO_ND.root
    args_gen_cafmaker_cfg+=( --pandora-path "$pandoraPath" )
fi

if [[ "$ND_PRODUCTION_CAFMAKER_DISABLE_IFBEAM" == "1" ]]; then
    args_gen_cafmaker_cfg+=( --disable-ifbeam )
fi

if [[ -n "$ND_PRODUCTION_MINERVA_FILES" ]]; then
    # The runs DB (used by match_minerva.cpp) uses the original binary filename
    # whereas ND_PRODUCTION_CHARGE_FILE is the packet file
    binaryChargeFile=$(basename ${ND_PRODUCTION_CHARGE_FILES[0]} | sed 's/^packet-/binary-/')
    run root -l -q "match_minerva.cpp+(\"$binaryChargeFile\", \"$tmpDir\")"
    minervaPath=$(ls $tmpDir/minerva_*.root)
    if [[ ! -e "$minervaPath" ]]; then
        echo "Ay caramba! Problem in building the matched Minerva file"
        rm -rf "$tmpDir"
        exit 1
    fi
    args_gen_cafmaker_cfg+=( --minerva-path "$minervaPath" )
fi

run ./gen_cafmaker_cfg.data.py "${args_gen_cafmaker_cfg[@]}"

echo ===================
run cat "$cfgFile"
echo ""
echo ===================

run makeCAF "--fcl=$cfgFile"

cafOutDir=$outDir
# HACK
flatCafOutDir=$(echo $cafOutDir | sed 's!/caf/!/caf.flat/!')
mkdir -p "$cafOutDir" "$flatCafOutDir"
mv "$outFile" "$cafOutDir"
mv "$flatOutFile" "$flatCafOutDir"

rm "$cfgFile"
rm -rf "$tmpDir"
