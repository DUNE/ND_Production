#!/usr/bin/env bash

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-fermilab/fnal-wn-sl7:latest}

source ../util/reload_in_container.inc.sh

# Setup environment.
setup() {
    . /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh

    # The duneanaobj version is defined by duneanafluxtools itself (its
    # DUNE_ANAOBJ_BRANCH CMake default), not by ND_Production. Read it out of
    # the source checkout so we don't have to duplicate/hardcode it here.
    duneanaobj_version=$(sed -n 's/^\s*set(DUNE_ANAOBJ_BRANCH \(.*\))/\1/p' "${PWD}"/install/duneanafluxtools/CMakeLists.txt)
    setup duneanaobj "$duneanaobj_version" -q "e20:prof"

    source "${PWD}"/install/duneanafluxtools/build/bin/setup.duneanafluxtools.sh
}

set +o errexit
setup
set -o errexit

# Must go after setup.
source ../util/init.inc.sh

inDir=${ND_PRODUCTION_OUTDIR_BASE}/run-cafmaker/$ND_PRODUCTION_IN_NAME
inName=$ND_PRODUCTION_IN_NAME.$globalIdx
inFile=$(realpath "$inDir"/CAF/$subDir/${inName}.CAF.root)

outFile=$tmpOutDir/${outName}.CAF.root
rm -f "$outFile"

run caffluxweighter "$inFile" "$outFile"

cafOutDir=$outDir/CAF/$subDir
mkdir -p "$cafOutDir"
mv "$outFile" "$cafOutDir"
