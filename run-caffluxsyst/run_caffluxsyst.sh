#!/usr/bin/env bash

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-fermilab/fnal-wn-sl7:latest}

source ../util/reload_in_container.inc.sh

# Setup environment.
setup() {
    . /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
    setup duneanaobj v04_01_00 -q "e20:prof"

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
