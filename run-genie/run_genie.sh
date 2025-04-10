#!/usr/bin/env bash

# export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-mjkramer/sim2x2:genie_edep.3_04_00.20230912}

source /storage/gpfs_data/neutrino/users/gsantoni/ND_Production/setup-genie.sh

cd $PWD

export ND_PRODUCTION_INDEX=${1}

# if I run on the cluster I need to comment this source because it is not needed, since I load the image in the submit file, 
# otherwise this source is needed
# source ../util/reload_in_container.inc.sh

# we need this source because inside the container we don't have the environment variables, because the environment file gets overwritten somewhere 
source ../admin/container_env.sim2x2_genie_edep.3_04_00.20230912.sif.sh
source ../util/init.inc.sh

# dk2nuAll=("$ND_PRODUCTION_DK2NU_DIR"/*.dk2nu*)
dk2nuAll=$(find "$ND_PRODUCTION_DK2NU_DIR" -type f -name "*.dk2nu*" -exec realpath {} \;)
echo "dk2nuAll is $dk2nuAll"
dk2nuAll=($dk2nuAll)
dk2nuCount=${#dk2nuAll[@]}
dk2nuIdx=$((ND_PRODUCTION_INDEX % dk2nuCount))
dk2nuFile=${dk2nuAll[$dk2nuIdx]}
echo "dk2nuIdx is $dk2nuIdx"
echo "dk2nuFile is $dk2nuFile"

export GXMLPATH=$PWD/flux            # contains GNuMIFlux.xml
echo "gxmlpath is $GXMLPATH"

maxPathFile=$PWD/maxpath/$(basename "$ND_PRODUCTION_GEOM" .gdml).maxpath.xml

echo "1 maxpath is $maxPathFile"

if [ ! -f "$maxPathFile" ]; then
    # Since I have no maxpath file already present, I need to convert gdml in root and then produce maxpath from the root file
    echo "TGeoManager::SetVerboseLevel(0); TGeoManager::Import(\"/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/$ND_PRODUCTION_GEOM\"); TFile f(\"/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/$(basename $ND_PRODUCTION_GEOM .gdml).root\",\"RECREATE\"); gGeoManager->Write(\"geo\"); f.Close();" | root -l -b
    echo "dopo import"
    # Evaluate max path lengths from ROOT geometry file
    echo $(basename $ND_PRODUCTION_GEOM .gdml)
    echo "/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/$(basename $ND_PRODUCTION_GEOM .gdml).root"
    gmxpl -f /storage/gpfs_data/neutrino/users/gsantoni/ND_Production/$(basename $ND_PRODUCTION_GEOM .gdml).root -L cm -D g_cm3 --tune $ND_PRODUCTION_TUNE -t $ND_PRODUCTION_TOP_VOLUME -o /storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-genie/maxpath/$(basename $ND_PRODUCTION_GEOM .gdml).maxpath.xml -seed 21304 --message-thresholds /storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-genie/Messenger.xml  &> ${ND_PRODUCTION_LOGDIR_BASE}/gmxpl.log
fi

echo "maxpath is $maxPathFile"

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
# ($baseDir is already an absoulte path)
geomFile=$baseDir/$ND_PRODUCTION_GEOM
ND_PRODUCTION_XSEC_FILE=$(realpath "$ND_PRODUCTION_XSEC_FILE")

tmpDir=$(mktemp -d)
pushd "$tmpDir"

rm -f "$genieOutPrefix".*

args_gevgen_fnal=( \
    -e "$ND_PRODUCTION_EXPOSURE" \
    -f "$dk2nuFile,$ND_PRODUCTION_DET_LOCATION,12,-12,14,-14" \
    -g "$geomFile" \
    -r "$runNo" \
    -L cm -D g_cm3 \
    --cross-sections "$ND_PRODUCTION_XSEC_FILE" \
    --tune "$ND_PRODUCTION_TUNE" \
    --seed "$seed" \
    -o "$genieOutPrefix" \
    -t "$ND_PRODUCTION_TOP_VOLUME" \
    -message-thresholds /storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-genie/Messenger.xml \
    )

[ "${USE_MAXPATH}" == 1 ] && args_gevgen_fnal+=( -m "$maxPathFile" )
[ -n "${ND_PRODUCTION_TOP_VOLUME}" ] && args_gevgen_fnal+=( -t "$ND_PRODUCTION_TOP_VOLUME" )
[ -n "${ND_PRODUCTION_FID_CUT_STRING}" ] && args_gevgen_fnal+=( -F "$ND_PRODUCTION_FID_CUT_STRING" )
[ -n "${ND_PRODUCTION_ZMIN}" ] && args_gevgen_fnal+=( -z "$ND_PRODUCTION_ZMIN" )
[ -n "${ND_PRODUCTION_EVENT_GEN_LIST}" ] && args_gevgen_fnal+=( --event-generator-list "$ND_PRODUCTION_EVENT_GEN_LIST" )

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