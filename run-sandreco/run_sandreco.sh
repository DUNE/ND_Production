#!/usr/bin/env bash

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-docker:baltig.infn.it:4567/dune/sand-ci/sand-prod-cpu:v1.0.1}

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

run ufwrun "$cfgFile"

# to follow the naming convention
mkdir -p "$outDir/SANDRECO/$subDir"
mv "$SANDRECOfile" "$outDir/SANDRECO/$subDir/$outName.SANDRECO.root"

echo "output file is $outDir/SANDRECO/$subDir/$outName.SANDRECO.root"

rm -f "$cfgFile"