#!/usr/bin/env bash

# export ARCUBE_CONTAINER=${ARCUBE_CONTAINER:-mjkramer/sim2x2:genie_edep.3_04_00.20230912}

source /storage/gpfs_data/neutrino/users/gsantoni/ND_Production/setup-genie.sh

cd $PWD

export ARCUBE_INDEX=${1}

# if I run on the cluster I need to comment this source because it is not needed, since I load the image in the submit file, 
# otherwise this source is needed
# source ../util/reload_in_container.inc.sh

# we need this source because inside the container we don't have the environment variables, because the environment file gets overwritten somewhere 
source ../admin/container_env.sim2x2_genie_edep.3_04_00.20230912.sif.sh
source ../util/init.inc.sh

# dk2nuAll=("$ARCUBE_DK2NU_DIR"/*.dk2nu*)
dk2nuAll=$(find "$ARCUBE_DK2NU_DIR" -type f -name "*.dk2nu*" -exec realpath {} \;)
echo "dk2nuAll is $dk2nuAll"
dk2nuAll=($dk2nuAll)
dk2nuCount=${#dk2nuAll[@]}
dk2nuIdx=$((ARCUBE_INDEX % dk2nuCount))
dk2nuFile=${dk2nuAll[$dk2nuIdx]}
echo "dk2nuIdx is $dk2nuIdx"
echo "dk2nuFile is $dk2nuFile"

export GXMLPATH=$PWD/flux            # contains GNuMIFlux.xml
# maxPathFile=$PWD/maxpath/$(basename "$ARCUBE_GEOM" .gdml).$ARCUBE_TUNE.maxpath.xml

maxPathFile=$PWD/maxpath/$(basename "$ARCUBE_GEOM" .gdml).maxpath.xml

if [ ! -f "$maxPathFile" ]; then
    # Since I have no maxpath file already present, I need to convert gdml in root and then produce maxpath from the root file
    echo "TGeoManager::SetVerboseLevel(0); TGeoManager::Import(\"/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/geometry-sand/EC_yoke_corrected_1212_dev_SAND_complete_opt3_DRIFT1.gdml\"); TFile f(\"/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/geometry-sand/EC_yoke_corrected_1212_dev_SAND_complete_opt3_DRIFT1.root\",\"RECREATE\"); gGeoManager->Write(\"geo\"); f.Close();" | root -l -b
    # Evaluate max path lengths from ROOT geometry file
    gmxpl -f /storage/gpfs_data/neutrino/users/gsantoni/ND_Production/geometry-sand/EC_yoke_corrected_1212_dev_SAND_complete_opt3_DRIFT1.root -L cm -D g_cm3 -o /storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-genie/maxpath/EC_yoke_corrected_1212_dev_SAND_complete_opt3_DRIFT1.maxpath.xml -seed 21304 --message-thresholds /storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-genie/Messenger.xml  &> ${ARCUBE_LOGDIR_BASE}/gmxpl.log
fi


USE_MAXPATH=1

if [ ! -f "$maxPathFile" ]; then
    echo ""
    echo "WARNING!!! .maxpath.xml file not found. Is this what you intended???"
    echo "           I WILL CONTINUE WITH NO maxPathFile"
    echo ""
    USE_MAXPATH=0
fi

genieOutPrefix=$tmpOutDir/$outName

# HACK: gevgen_fnal hardcodes the name of the status file (unlike gevgen, which
# respects -o), so run it in a temporary directory. Need to get absolute paths.

dk2nuFile=$(realpath "$dk2nuFile")
# The geometry file is given relative to the root of 2x2_sim
# ($baseDir is already an absolute path)
geomFile=$baseDir/$ARCUBE_GEOM
ARCUBE_XSEC_FILE=$(realpath "$ARCUBE_XSEC_FILE")

tmpDir=$(mktemp -d)
pushd "$tmpDir"

rm -f "$genieOutPrefix".*

args_gevgen_fnal=( \
    -e "$ARCUBE_EXPOSURE" \
    -f "$dk2nuFile,$ARCUBE_DET_LOCATION,12,-12,14,-14" \
    -g "$geomFile" \
    -r "$runNo" \
    -L cm -D g_cm3 \
    --cross-sections "$ARCUBE_XSEC_FILE" \
    --tune "$ARCUBE_TUNE" \
    --seed "$seed" \
    -o "$genieOutPrefix" \
    -t "$ARCUBE_TOP_VOLUME" \
    -message-thresholds /storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-genie/Messenger.xml \
    )

[ "${USE_MAXPATH}" == 1 ] && args_gevgen_fnal+=( -m "$maxPathFile" )
[ -n "${ARCUBE_TOP_VOLUME}" ] && args_gevgen_fnal+=( -t "$ARCUBE_TOP_VOLUME" )
[ -n "${ARCUBE_FID_CUT_STRING}" ] && args_gevgen_fnal+=( -F "$ARCUBE_FID_CUT_STRING" )
[ -n "${ARCUBE_ZMIN}" ] && args_gevgen_fnal+=( -z "$ARCUBE_ZMIN" )
[ -n "${ARCUBE_EVENT_GEN_LIST}" ] && args_gevgen_fnal+=( --event-generator-list "$ARCUBE_EVENT_GEN_LIST" )


run gevgen_fnal "${args_gevgen_fnal[@]}"

statDir=$logBase/STATUS/$subDir
mkdir -p "$statDir"
mv genie-mcjob-"$runNo".status "$statDir/$outName.status"
popd
rmdir "$tmpDir"

# use consistent naming convention w/ rest of sim chain
mv "$genieOutPrefix"."$runNo".ghep.root "$genieOutPrefix".GHEP.root

run gntpc -i "$genieOutPrefix".GHEP.root -f rootracker \
    -o "$genieOutPrefix".GTRAC.root

mkdir -p "$outDir/GHEP/$subDir"  "$outDir/GTRAC/$subDir"
mv "$genieOutPrefix.GHEP.root" "$outDir/GHEP/$subDir"
mv "$genieOutPrefix.GTRAC.root" "$outDir/GTRAC/$subDir"

cd $ND_PRODUCTION