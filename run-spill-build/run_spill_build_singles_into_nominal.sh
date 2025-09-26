#!/usr/bin/env bash

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-mjkramer/sim2x2:ndlar011}

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

spillsName=$ND_PRODUCTION_SPILL_NAME.$globalIdx
singlesName=$ND_PRODUCTION_SINGLES_NAME.$globalIdx
echo "outName is $outName"

spillsInDir=$ND_PRODUCTION_OUTDIR_BASE/run-spill-build/$ND_PRODUCTION_SPILL_NAME
singlesInDir=$ND_PRODUCTION_OUTDIR_BASE/run-hadd/$ND_PRODUCTION_SINGLES_NAME

spillsInFile=$spillsInDir/EDEPSIM_SPILLS/$subDir/${spillsName}.EDEPSIM_SPILLS.root
singlesInFile=$singlesInDir/EDEPSIM/$subDir/${singlesName}.EDEPSIM.root

overlaidFile=$tmpOutDir/${outName}.EDEPSIM_SPILLS.root
rm -f "$overlaidFile"


# HACK: We need to "unload" edep-sim; if it's in our LD_LIBRARY_PATH, we have to
# use the "official" edepsim-io headers, which force us to use the getters, at
# least when using cling(?). overlaySinglesIntoSpills.C directly accesses the
# fields. So we apparently must use headers produced by MakeProject, but that
# would lead to a conflict with the ones from the edep-sim installation. Hence
# we unload the latter. Fun. See makeLibTG4Event.sh
libpath_remove /opt/generators/edep-sim/install/lib

# LIBTG4EVENT_DIR is provided by the podman-built containers
# If unset, fall back to the local build provided by install_spill_build.sh
LIBTG4EVENT_DIR=${LIBTG4EVENT_DIR:-libTG4Event}


run root -l -b -q \
    -e "gSystem->Load(\"$LIBTG4EVENT_DIR/libTG4Event.so\")" \
    "overlaySinglesIntoExistingSpillsSorted.C(\"$spillsInFile\", \"$singlesInFile\", \"$overlaidFile\", $ND_PRODUCTION_N_SINGLES_OVERLAID_PER_SPILL)"

mkdir -p "$outDir/EDEPSIM_SPILLS/$subDir"
mv "$overlaidFile" "$outDir/EDEPSIM_SPILLS/$subDir"
