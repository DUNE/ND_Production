#!/bin/sh

# load container
# N.B. actually, if we run in batch mode (on the cluster), we don't need to run manually the image, 
# since the image is loaded directly in the submit file. To avoid the loading of the image we need
# to set $SINGULARITY_NAME = $ND_PRODUCTION_CONTAINER.
# However, this step can be useful for users who run it with other container managers
source ../util/init.inc.sh
source ../util/reload_in_container.inc.sh

# check correct json configuration file --> use json schema
# N.B. this should be removed when check-jsonschema will be installed in the image (I hope it will be installed)
if pip show check-jsonschema &>/dev/null; then
    echo "check-jsonschema is already installed"
else
    echo "Installing check-jsonschema..."
    pip install check-jsonschema
fi
PATH="/home/NEUTRINO/gsantonineutrino/.local/bin:$PATH" # it must change

JSON_SCHEMA_CONTAINER_PATH="${ND_PRODUCTION_DIR}/run-sandreco/config/config.schema.json"
JSON_FILE_CONTAINER_PATH="${ND_PRODUCTION_DIR}/run-sandreco/config/config_sandreco.json"

if check-jsonschema --schemafile $JSON_SCHEMA_CONTAINER_PATH $JSON_FILE_CONTAINER_PATH; then
    echo "JSON file correctly configured"
else 
    echo "JSON file wrong! Check again"
fi

# create output folder
inDir=$ND_PRODUCTION_OUTDIR_BASE/run-convert2edepsim-spill-format/sand-events-4/OVERLAY/$subDir

mkdir -p "$outDir/DIGI/$subDir"
echo $outDir/DIGI/$subDir

echo "tmp " $tmpOutDir
digiFile=$inDir/drift_fast_digi.root

# some problems since test files are in /usr/local, but we can't write to /usr/local
# since we are not root users. This will be solved because the .json will be written by the user
run ufwrun config/config_sandreco.json

mv "$digiFile" "$outDir/DIGI/$subDir/$outName.DIGI.root"

/storage/gpfs_data/neutrino/users/gsantoni/ND_Production_main/workspace/output/productions-full-prod-02-12/run-convert2edepsim-spill-format/sand-events-4/OVERLAY/0000000/drift_fast_digi.root

