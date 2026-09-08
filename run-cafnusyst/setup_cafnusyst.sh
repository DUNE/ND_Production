#!/bin/bash

export SPACK_USER_CACHE_PATH=/home/workspace/spack-cache

echo "# . /cvmfs/dune.opensciencegrid.org/spack/v1.1.1/setup-env.sh"
. /cvmfs/dune.opensciencegrid.org/spack/v1.1.1/setup-env.sh

# Not necessary unless you build the package
#spack load /wrkusgq        # gcc
#spack load /64q3lof        # cmake

echo "# . subspack_env/setup-env.sh"
. /home/workspace/subspack_env/setup-env.sh

echo "# spack env activate build_genie_v03_04_02"
spack env activate build_genie_v03_04_02

echo "# Loading gcc, genie, genie-xsec, pythia6, eigen, yaml-cpp, duneanaobj, py-srproxy, cmake"
spack load genie
spack load genie-xsec
spack load pythia6
export PYTHIA6=$(spack location -i pythia6)/lib
spack load eigen
spack load yaml-cpp
spack load duneanaobj
spack load py-srproxy
export CPLUS_INCLUDE_PATH="$(spack location -i py-srproxy)/include:$CPLUS_INCLUDE_PATH"

export CAFNUSYST_WORKSPACE=/home/workspace
echo "# source ${CAFNUSYST_WORKSPACE}/systematicstools-build/Linux/bin/setup.systematicstools.sh"
source ${CAFNUSYST_WORKSPACE}/systematicstools-install/bin/setup.systematicstools.sh

echo "# source ${CAFNUSYST_WORKSPACE}/nusystematics-build/Linux/bin/setup.nusystematics.sh"
source ${CAFNUSYST_WORKSPACE}/nusystematics-install/bin/setup.nusystematics.sh
export NUSYST_DATA_DIR=${CAFNUSYST_WORKSPACE}/nusyst_data-src
echo "# NUSYST_DATA_DIR is updated to ${NUSYST_DATA_DIR}"

echo "# source ${CAFNUSYST_WORKSPACE}/cafnusyst-install/bin/setup.cafnusyst.sh"
source ${CAFNUSYST_WORKSPACE}/cafnusyst-install/bin/setup.cafnusyst.sh
