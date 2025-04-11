#!/usr/bin/env bash

# Run me from the root directory of 2x2_sim

# Currently larnd-sim and ndlar_flow are the only things we're installing
# locally. Everything else comes either from a container or CVMFS. If using
# the ND_PRODUCTION_USE_GHEP_POT option, need to install a single executable via
# install_hadd.sh.

set -o errexit

# This is the "default" container. It can be overridden by exporting
# ND_PRODUCTION_CONTAINER before running e.g. run_edep_sim.sh
# export ND_PRODUCTION_RUNTIME="SHIFTER"
# export ND_PRODUCTION_CONTAINER=mjkramer/sim2x2:genie_edep.3_04_00.20230620

# export ND_PRODUCTION_RUNTIME="SINGULARITY"
# export ND_PRODUCTION_CONTAINER=sim2x2_genie_edep.LFG_testing.20230228.v2.sif

# export ND_PRODUCTION_DIR=$PWD
# export ND_PRODUCTION_CONTAINER_DIR=$ND_PRODUCTION_DIR/admin/containers

pushd run-hadd
./install_hadd.sh
popd

# pushd run-spill-build
# ./install_spill_build.sh
# popd

# pushd run-convert2h5
# ./install_convert2h5.sh
# popd

pushd run-larnd-sim
./install_larnd_sim.sh
popd

pushd run-ndlar-flow
./install_ndlar_flow.sh
popd

pushd run-pandora
./install_pandora.sh
popd

pushd run-mlreco
./install_mlreco.sh
popd

pushd run-cafmaker
./install_cafmaker.sh
popd

# pushd validation
# ./install_validation.sh
# popd

# HACK because we forgot to include GNU time in some of the containers
# Hope you have it on your host system!
mkdir -p tmp_bin
cp /usr/bin/time tmp_bin/
