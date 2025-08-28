#!/usr/bin/env bash

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-mjkramer/sim2x2:ndlar011}

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

# ghepFile="../productions-new-flux/run-genie/sand-events/GHEP/0000000/sand-events.0000000.GHEP.root"

nuName=$ND_PRODUCTION_NU_NAME.$globalIdx
# rockName=$ND_PRODUCTION_ROCK_NAME.$globalIdx
echo "outName is $outName"

inBaseDir=$ND_PRODUCTION_OUTDIR_BASE/run-genie
genieDir=$inBaseDir/$ND_PRODUCTION_NU_NAME
# rockInDir=$inBaseDir/$ND_PRODUCTION_ROCK_NAME

ghepFile=$genieDir/GHEP/$subDir/${nuName}.GHEP.root
gtracFile=$genieDir/GTRAC/$subDir/${nuName}.GTRAC.root
# rockInFile=$rockInDir/EDEPSIM_SPILLS/$subDir/${rockName}.EDEPSIM_SPILLS.root

LIBTG4EVENT_DIR=${LIBTG4EVENT_DIR:-libTG4Event}
# LD_PRELOAD="/usr/lib64/libxml2.so:/opt/generators/genie/lib/libGFwUtl-3.04.00.so:/opt/generators/root/lib/libHist.so:/opt/generators/root/lib/libPhysics.so" /opt/generators/root/bin/root.exe

run root -l -b -q \
    -e "gSystem->Load(\"$LIBTG4EVENT_DIR/libTG4Event.so\")" \
    "validate_transformation.cpp(\"$ghepFile\", \"$gtracFile\")"