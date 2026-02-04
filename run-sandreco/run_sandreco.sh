#!/bin/sh

# load container
# N.B. actually, if we run in batch mode (on the cluster), we don't need to run manually the image, 
# since the image is loaded directly in the submit file. To avoid the loading of the image we need
# to set $SINGULARITY_NAME = $ND_PRODUCTION_CONTAINER.
# However, this step can be useful for users who run it with other container managers
source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

############################################################################################
# check correct json configuration file --> use json schema
#
# N.B. this should be removed since this step should be done inside ufw when we call ufwrun
if pip show check-jsonschema &>/dev/null; then
    echo "check-jsonschema is already installed"
else
    echo "Installing check-jsonschema..."
    if pip install check-jsonschema; then
        echo "Installation completed successfully!"
    else 
        echo "Installation failed, no json schema validation"
    fi
fi
PATH="$HOME/.local/bin:$PATH"

if check-jsonschema --schemafile $JSON_SCHEMA_CONTAINER_PATH $JSON_FILE_CONTAINER_PATH; then
    echo "JSON file correctly configured"
else 
    echo "JSON file wrong! Check again"
fi
############################################################################################

# set useful input path
overlayName=$ND_PRODUCTION_IN_NAME.$globalIdx

inDir=$ND_PRODUCTION_OUTDIR_BASE/run-convert2edepsim-spill-format/
overlayDir=$inDir/$ND_PRODUCTION_IN_NAME

overlayFile=$overlayDir/OVERLAY/$subDir/${overlayName}.OVERLAY.root
echo "input file is $overlayFile"

# set output path
CAFfile=$tmpOutDir/${outName}.CAF.root
rm -f "$CAFfile"

# export some useful variables for json configuration
export globalIdx
export overlayName
export outName

# configure json file
python3 config/config_json.py

# some problems since test files are in /usr/local, but we can't write to /usr/local
# since we are not root users. This will be solved because the .json will be written by the user
run ufwrun config/config_sandreco.json

# to follow the naming convention
mkdir -p "$outDir/CAF/$subDir"
mv "$CAFfile" "$outDir/CAF/$subDir/$outName.CAF.root"

echo "output file is $outDir/CAF/$subDir/$outName.CAF.root"

