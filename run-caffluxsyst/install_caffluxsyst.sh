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
setup cmake v3_27_4

# Should maybe checkout a tag here the first time we run real production.
git clone https://github.com/DUNE/duneanafluxtools.git

# The duneanaobj version is defined by duneanafluxtools itself (its
# DUNE_ANAOBJ_BRANCH CMake default), not by ND_Production. Read it out so we
# don't have to duplicate/hardcode the version here.
duneanaobj_version=$(sed -n 's/^\s*set(DUNE_ANAOBJ_BRANCH \(.*\))/\1/p' duneanafluxtools/CMakeLists.txt)
setup duneanaobj "$duneanaobj_version" -q "e20:prof"

mkdir duneanafluxtools/build
cd duneanafluxtools/build

cmake ../
make install
ldd bin/caffluxweighter
