#!/usr/bin/env bash

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-fermilab/fnal-wn-sl7:latest}

source ../util/reload_in_container.inc.sh

cd install/ND_CAFMaker
set +o errexit
source ndcaf_setup.sh
set -o errexit
cd ../..

# Must go after ndcaf_setup.sh
source ../util/init.inc.sh
# Prevent excessive memory use
export OMP_NUM_THREADS=1

outFile=${tmpOutDir}/${outName}.CAF.root
flatOutFile=${tmpOutDir}/${outName}.CAF.flat.root
cfgFile=$(mktemp --suffix .cfg)

# Compulsory arguments regardless of use case.
args_gen_cafmaker_cfg=( \
    --base-dir "$ND_PRODUCTION_OUTDIR_BASE" \
    --spine-name "$ND_PRODUCTION_SPINE_NAME" \
    --pandora-name "$ND_PRODUCTION_PANDORA_NAME" \
    --caf-path "$outFile" \
    --cfg-file "$cfgFile" \
    --file-id "$ND_PRODUCTION_INDEX" \
    )

[ -n "${ND_PRODUCTION_GHEP_NU_NAME}" ] && args_gen_cafmaker_cfg+=( --ghep-nu-name "$ND_PRODUCTION_GHEP_NU_NAME" )
[ -n "${ND_PRODUCTION_GHEP_ROCK_NAME}" ] && args_gen_cafmaker_cfg+=( --ghep-rock-name "$ND_PRODUCTION_GHEP_ROCK_NAME" )
[ -n "${ND_PRODUCTION_SPILL_NAME}" ] && args_gen_cafmaker_cfg+=( --edepsim-name "$ND_PRODUCTION_SPILL_NAME" )
[ -n "${ND_PRODUCTION_MINERVA_NAME}" ] && args_gen_cafmaker_cfg+=( --minerva-name "$ND_PRODUCTION_MINERVA_NAME" )
[ -n "${ND_PRODUCTION_TMSRECO_NAME}" ] && args_gen_cafmaker_cfg+=( --tmsreco-name "$ND_PRODUCTION_TMSRECO_NAME" )
[ -n "${ND_PRODUCTION_HADD_FACTOR}" ] && args_gen_cafmaker_cfg+=( --hadd-factor "$ND_PRODUCTION_HADD_FACTOR" )
[ -n "${ND_PRODUCTION_EXTRA_LINES}" ] && args_gen_cafmaker_cfg+=( --extra-lines "$ND_PRODUCTION_EXTRA_LINES" )

./gen_cafmaker_cfg.py "${args_gen_cafmaker_cfg[@]}"

echo ===================
cat "$cfgFile"
echo ""
echo ===================

run makeCAF "--fcl=$cfgFile"

cafOutDir=$outDir/CAF/$subDir
flatCafOutDir=$outDir/CAF.flat/$subDir
mkdir -p "$cafOutDir" "$flatCafOutDir"
mv "$outFile" "$cafOutDir"
mv "$flatOutFile" "$flatCafOutDir"

rm "$cfgFile"
