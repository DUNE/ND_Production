#!/usr/bin/env bash

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-mjkramer/sim2x2:ndlar011}

source /storage/gpfs_data/neutrino/users/gsantoni/ND_Production/setup-edepsim.sh

cd $PWD

export ARCUBE_INDEX=${1}

# source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

genieOutPrefix=${ND_PRODUCTION_OUTDIR_BASE}/run-genie/${ND_PRODUCTION_GENIE_NAME}/GTRAC/$subDir/${ND_PRODUCTION_GENIE_NAME}.$globalIdx
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

# The geometry file is given relative to the root of 2x2_sim
export ND_PRODUCTION_GEOM_EDEP=$baseDir/${ND_PRODUCTION_GEOM_EDEP:-$ND_PRODUCTION_GEOM}

run edep-sim -C -g "$ND_PRODUCTION_GEOM_EDEP" -o "$edepRootFile" -e "$nEvents" \
    <(echo "$edepCode") "$ND_PRODUCTION_EDEP_MAC"

mkdir -p "$outDir/EDEPSIM/$subDir"
mv "$edepRootFile" "$outDir/EDEPSIM/$subDir"

cd $ND_PRODUCTION