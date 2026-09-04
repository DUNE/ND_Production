#!/usr/bin/env bash

export ND_PRODUCTION_RUNTIME=${ND_PRODUCTION_RUNTIME:-SHIFTER}

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-$ND_PRODUCTION_CONTAINER_CAF}
export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-fermilab/fnal-wn-sl7:latest}

source ../util/reload_in_container.inc.sh

set +o errexit

if [[ -d install ]]; then
    echo "CAFMaker appears to be installed already."
    echo "To force a reinstall, please delete the directory run-cafmaker/install"
    exit
fi

mkdir install
cd install

git clone -b main https://github.com/DUNE/ND_CAFMaker.git
cd ND_CAFMaker

#./build_deps.sh
source ndcaf_setup_deps.sh prof
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${PWD}/install
cmake --build build --target install
cd ../..

# Pre-compile
export ROOT_INCLUDE_PATH=$SQLITE_INC:$ROOT_INCLUDE_PATH
root -l -b -q -e ".L match_minerva.cpp+"

# Needed for match_minerva.cpp
wget https://portal.nersc.gov/project/dune/data/2x2/DB/RunsDB/releases/mx2x2runs_v0.2.sqlite
