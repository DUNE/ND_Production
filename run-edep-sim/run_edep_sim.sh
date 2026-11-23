#!/usr/bin/env bash

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-mjkramer/sim2x2:ndlar011}
export ND_PRODUCTION_SPACK_ENVIRONMENT=${ND_PRODUCTION_SPACK_ENVIRONMENT:-/exp/dune/app/users/abooth/Postdoc/nd-sim-reco/abooth-nd-run-edep-sim-ndlar012}
export ND_PRODUCTION_SPACK_VERSION=${ND_PRODUCTION_SPACK_VERSION:-v1.2.2}

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

if [[ "$ND_PRODUCTION_CONTAINER" == *"fnal-wn-el9"* ]]; then
    #source /cvmfs/dune.opensciencegrid.org/spack/"${ND_PRODUCTION_SPACK_VERSION}"/share/spack/setup-env.sh
    source /exp/dune/app/users/abooth/Postdoc/nd-sim-reco/spack_build_instance_261105/share/spack/setup-env.sh

    if [[ -n "$ND_PRODUCTION_SPACK_USER_CACHE_PATH" ]]; then
        export SPACK_USER_CACHE_PATH="$ND_PRODUCTION_SPACK_USER_CACHE_PATH"
    fi

    #spack env activate "${ND_PRODUCTION_SPACK_ENVIRONMENT}"
    spack env activate -d "${ND_PRODUCTION_SPACK_ENVIRONMENT}"
fi

simulation=${ND_PRODUCTION_SIM:-GENIE}
inputFile=""

if [[ "$simulation" == "GENIE" ]]; then
    inputPrefix=${ND_PRODUCTION_OUTDIR_BASE}/run-genie/${ND_PRODUCTION_GENIE_NAME}/GTRAC/$subDir/${ND_PRODUCTION_GENIE_NAME}.$globalIdx
    inputFile=$inputPrefix.GTRAC.root

elif [[ "$simulation" == "CORSIKA" ]]; then
    inputPrefix=${ND_PRODUCTION_OUTDIR_BASE}/run-corsika/${ND_PRODUCTION_CORSIKA_NAME}/CORSIKA/$subDir/${ND_PRODUCTION_CORSIKA_NAME}.$globalIdx
    inputFile=$inputPrefix.CORSIKA.root

elif [[ "$simulation" == "BOMB" ]]; then
    : # no input file, nothing to do here

else
    echo "Unsupported \$ND_PRODUCTION_SIM type. Exiting."
    echo "\$ND_PRODUCTION_SIM = ${ND_PRODUCTION_SIM}"
    exit 1
fi

if [[ -n "$ND_PRODUCTION_CHERRYPICKER_SCRIPT" ]]; then
    if [[ -z "$inputFile" ]]; then
        echo "\$ND_PRODUCTION_CHERRYPICKER_SCRIPT can only be used when edep-sim " \
            "takes an input file (e.g. from GENIE or CORSIKA)"
        exit 1
    fi
    origInputFile=$inputFile
    inputFile=$tmpOutDir/$(basename "$inputFile" .root).PICKED.root
    rm -f "$inputFile"
    run python3 "$ND_PRODUCTION_CHERRYPICKER_SCRIPT" -i "$origInputFile" -o "$inputFile"
fi

edepCode=()

if [[ -n "$inputFile" ]]; then
    edepCode+=("/generator/kinematics/rooTracker/input $inputFile")
    rootCode='
    auto t = (TTree*) _file0->Get("gRooTracker");
    std::cout << t->GetEntries() << std::endl;'
    nEvents=$(echo "$rootCode" | root -l -b "$inputFile" | tail -1)
else
    if [[ -z "$ND_PRODUCTION_NUM_EVENTS" ]]; then
        echo "Please set \$ND_PRODUCTION_NUM_EVENTS"
        exit 1
    fi
    nEvents=$ND_PRODUCTION_NUM_EVENTS
    if [[ -n "$ND_PRODUCTION_MPVMPR_CONFIG" ]]; then
        edepCode+=("/generator/kinematics/bomb/config $ND_PRODUCTION_MPVMPR_CONFIG")
    fi
fi

edepRootFile=$tmpOutDir/${outName}.EDEPSIM.root
rm -f "$edepRootFile"

edepCode+=("/edep/runId $runNo")

# The geometry file is given relative to the root of ND_Production
export ND_PRODUCTION_GEOM_EDEP=$baseDir/${ND_PRODUCTION_GEOM_EDEP:-$ND_PRODUCTION_GEOM}

run edep-sim -C -g "$ND_PRODUCTION_GEOM_EDEP" -o "$edepRootFile" -e "$nEvents" \
    <(printf "%s\n" "${edepCode[@]}") "$ND_PRODUCTION_EDEP_MAC"

mkdir -p "$outDir/EDEPSIM/$subDir"
mv "$edepRootFile" "$outDir/EDEPSIM/$subDir"

if [[ -n "$ND_PRODUCTION_CHERRYPICKER_SCRIPT" ]]; then
    rm "$inputFile"
fi
