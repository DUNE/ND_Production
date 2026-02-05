#!/bin/sh

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

# set useful input path
overlayName=$ND_PRODUCTION_IN_NAME.$globalIdx

inDir=$ND_PRODUCTION_OUTDIR_BASE/run-convert2edepsim-spill-format
overlayDir=$inDir/$ND_PRODUCTION_IN_NAME

overlayFile=$overlayDir/OVERLAY/$subDir/${overlayName}.OVERLAY.root
echo "input file is $overlayFile"

# set output path
CAFfile=$tmpOutDir/${outName}.CAF.root
rm -f "$CAFfile"

# export some useful variables for json configuration
export overlayName
export subDir
export outName

# configure json file
python3 config/config_json.py

run ufwrun config/config_sandreco.json

# to follow the naming convention
mkdir -p "$outDir/CAF/$subDir"
mv "$CAFfile" "$outDir/CAF/$subDir/$outName.CAF.root"

echo "output file is $outDir/CAF/$subDir/$outName.CAF.root"

