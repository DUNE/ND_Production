#!/usr/bin/env bash

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-mjkramer/sim2x2:ndlar011}

source /storage/gpfs_data/neutrino/users/gsantoni/ND_Production/setup-edepsim.sh

cd $PWD

export ARCUBE_INDEX=${1}

# source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

simulation=${ND_PRODUCTION_SIM:-GENIE}

if [[ "$simulation" == "GENIE" ]]; then
    inputPrefix=${ND_PRODUCTION_OUTDIR_BASE}/run-genie/${ND_PRODUCTION_GENIE_NAME}/GTRAC/$subDir/${ND_PRODUCTION_GENIE_NAME}.$globalIdx
    inputFile=$inputPrefix.GTRAC.root

elif [[ "$simulation" == "CORSIKA" ]]; then
    inputPrefix=${ND_PRODUCTION_OUTDIR_BASE}/run-corsika/${ND_PRODUCTION_CORSIKA_NAME}/CORSIKA/$subDir/${ND_PRODUCTION_CORSIKA_NAME}.$globalIdx
    inputFile=$inputPrefix.CORSIKA.root

else
    echo "Unsupported \$ND_PRODUCTION_SIM type. Exiting."
    echo "\$ND_PRODUCTION_SIM = ${ND_PRODUCTION_SIM}"
    exit 1
fi

rootCode='
auto t = (TTree*) _file0->Get("gRooTracker");
std::cout << t->GetEntries() << std::endl;'
nEvents=$(echo "$rootCode" | root -l -b "$inputFile" | tail -1)

edepRootFile=$tmpOutDir/${outName}.EDEPSIM.root
rm -f "$edepRootFile"

edepCode="/generator/kinematics/rooTracker/input $inputFile
/edep/runId $runNo"

# The geometry file is given relative to the root of 2x2_sim
export ND_PRODUCTION_GEOM_EDEP=$baseDir/${ND_PRODUCTION_GEOM_EDEP:-$ND_PRODUCTION_GEOM}

run edep-sim -C -g "$ND_PRODUCTION_GEOM_EDEP" -o "$edepRootFile" -e "$nEvents" \
    <(echo "$edepCode") "$ND_PRODUCTION_EDEP_MAC"

mkdir -p "$outDir/EDEPSIM/$subDir"
mv "$edepRootFile" "$outDir/EDEPSIM/$subDir"
