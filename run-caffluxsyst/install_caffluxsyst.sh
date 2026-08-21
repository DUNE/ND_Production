#!/usr/bin/env bash

export ND_PRODUCTION_RUNTIME=${ND_PRODUCTION_RUNTIME:-SHIFTER}

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-$ND_PRODUCTION_CONTAINER_CAF}
export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-fermilab/fnal-wn-sl7:latest}

source ../util/reload_in_container.inc.sh

set +o errexit

if [[ -d install ]]; then
    echo "caffluxsyst appears to be installed already."
    echo "To force a reinstall, please delete the directory run-caffluxsyst/install"
    exit
fi

mkdir install
cd install

. /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
setup duneanaobj v04_01_00 -q "e20:prof"
setup cmake v3_27_4

git clone --depth 1 --branch v0.9.0 https://github.com/DUNE/duneanafluxtools.git
mkdir duneanafluxtools/build
cd duneanafluxtools/build

cmake ../
make install
ldd bin/caffluxweighter
