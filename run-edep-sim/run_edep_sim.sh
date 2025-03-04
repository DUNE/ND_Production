#!/usr/bin/env bash

export ARCUBE_CONTAINER=${ARCUBE_CONTAINER:-mjkramer/sim2x2:ndlar011}

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

simulation=${ARCUBE_SIM:-GENIE}

if [[ "$simulation" == "GENIE" ]]; then
    inputPrefix=${ARCUBE_OUTDIR_BASE}/run-genie/${ARCUBE_GENIE_NAME}/GTRAC/$subDir/${ARCUBE_GENIE_NAME}.$globalIdx
    inputFile=$inputPrefix.GTRAC.root

elif [[ "$simulation" == "CORSIKA" ]]; then
    inputPrefix=${ARCUBE_OUTDIR_BASE}/run-corsika/${ARCUBE_CORSIKA_NAME}/CORSIKA/$subDir/${ARCUBE_CORSIKA_NAME}.$globalIdx
    inputFile=$inputPrefix.CORSIKA.root

else
    echo "Unsupported \$ARCUBE_SIM type. Exiting."
    echo "\$ARCUBE_SIM = ${ARCUBE_SIM}"
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
export ARCUBE_GEOM_EDEP=$baseDir/${ARCUBE_GEOM_EDEP:-$ARCUBE_GEOM}

# gdb -ex=r --args edep-sim -C -g "$ARCUBE_GEOM_EDEP" -o "$edepRootFile" -e "$nEvents" \
run edep-sim -C -g "$ARCUBE_GEOM_EDEP" -o "$edepRootFile" -e "$nEvents" \
    <(echo "$edepCode") "$ARCUBE_EDEP_MAC"

mkdir -p "$outDir/EDEPSIM/$subDir"
mv "$edepRootFile" "$outDir/EDEPSIM/$subDir"
