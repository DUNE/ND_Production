#!/usr/bin/env bash

# export ARCUBE_CONTAINER=${ARCUBE_CONTAINER:-mjkramer/sim2x2:ndlar011}

source /storage/gpfs_data/neutrino/users/gsantoni/ND_Production/setup-edepsim.sh

cd $PWD

export ARCUBE_INDEX=${1}

# source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

genieOutPrefix=${ARCUBE_OUTDIR_BASE}/run-genie/${ARCUBE_GENIE_NAME}/GTRAC/$subDir/${ARCUBE_GENIE_NAME}.$globalIdx
genieFile="$genieOutPrefix".GTRAC.root

echo "genieFile is $genieFile"

rootCode='
auto t = (TTree*) _file0->Get("gRooTracker");
std::cout << t->GetEntries() << std::endl;'
nEvents=$(echo "$rootCode" | root -l -b "$genieFile" | tail -1)

edepRootFile=$tmpOutDir/${outName}.EDEPSIM.root
rm -f "$edepRootFile"

edepCode="/generator/kinematics/rooTracker/input $genieFile
/edep/runId $runNo"

# The geometry file is given relative to the root of ND_Production
export ARCUBE_GEOM_EDEP=$baseDir/${ARCUBE_GEOM_EDEP:-$ARCUBE_GEOM}

run edep-sim -C -g "$ARCUBE_GEOM_EDEP" -o "$edepRootFile" -e "$nEvents" \
    <(echo "$edepCode") "$ARCUBE_EDEP_MAC"

mkdir -p "$outDir/EDEPSIM/$subDir"
mv "$edepRootFile" "$outDir/EDEPSIM/$subDir"

cd $ND_PRODUCTION