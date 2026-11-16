#!/usr/bin/env bash

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-docker:baltig.infn.it:4567/dune/sand-ci/sand-prod-cpu:v1.2.0}

export APPLY_GAUSS_SMEARING="${APPLY_GAUSS_SMEARING:-"0"}"
export APPLY_GLUCK_SMEARING="${APPLY_GLUCK_SMEARING:-"0"}"

# Gauss smearing
if [ "$APPLY_GAUSS_SMEARING" -eq 1 ]; then
    export ENERGY_RESOLUTION="${ENERGY_RESOLUTION:-"0.057"}"      # energy resolution for gauss smearing
    export MOMENTUM_RESOLUTION="${MOMENTUM_RESOLUTION:-"0.05"}"   # momentum resolution for gauss smearing
    export POS_RESOLUTION="${POS_RESOLUTION:-"200e-3"}"           # position resolution for gauss smearing
fi          

# Gluckstern smearing
if [ "$APPLY_GLUCK_SMEARING" -eq 1 ]; then
    export POS_RES_TRANSVERSE_GLUCKSTERN="${POS_RES_TRANSVERSE_GLUCKSTERN:-"200e-3"}"   # transverse position resolution
    export POS_RES_LONGITUDINAL_GLUCKSTERN="${POS_RES_LONGITUDINAL_GLUCKSTERN:-"2"}"    # longitudinal position resolution
    export HIT_ENERGY_THRESHOLD="${HIT_ENERGY_THRESHOLD:-"250e-6"}"                     # hit energy threshold 
fi                         

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

# set useful input path
overlayName=$ND_PRODUCTION_IN_NAME.$globalIdx

inDir=$ND_PRODUCTION_OUTDIR_BASE/run-convert2edepsim-spill-format
overlayDir=$inDir/$ND_PRODUCTION_IN_NAME

overlayFile=$overlayDir/OVERLAY/$subDir/${overlayName}.OVERLAY.root
echo "input file is $overlayFile"

# set output path
SANDRECOfile=$tmpOutDir/${outName}.SANDRECO.root
rm -f "$SANDRECOfile"

# export some useful variables for json configuration
export overlayName
export subDir
export outName

# create configuration file
cfgFile=$(mktemp --suffix .json)
echo "configuration file is $cfgFile"

export CONFIG_JSON_FILE="$cfgFile"

# configure json file
python3 config/config_json.py

echo ===================
cat "$cfgFile"
echo ""
echo ===================

run ufwrun "$cfgFile"

# to follow the naming convention
mkdir -p "$outDir/SANDRECO/$subDir"
mv "$SANDRECOfile" "$outDir/SANDRECO/$subDir/$outName.SANDRECO.root"

echo "output file is $outDir/SANDRECO/$subDir/$outName.SANDRECO.root"

rm -f "$cfgFile"