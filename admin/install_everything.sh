#!/usr/bin/env bash

# Run me from the root directory of ND_Production

if [ -z "$1" ]; then
  echo "Installation is detector specific, you must pass either '2x2' or 'ndlar' as"
  echo "the first positional argument of this script."
  exit 1
fi

detector=$1

pushd run-corsika
./install_corsika.sh
popd

# If using the ND_PRODUCTION_USE_GHEP_POT option, need to install a single
# executable via install_hadd.sh.
pushd run-hadd
./install_hadd.sh
popd

pushd run-larnd-sim
./install_larnd_sim.sh
popd

pushd run-ndlar-flow
./install_ndlar_flow.sh
popd

pushd run-pandora
./install_pandora.sh "$detector"
popd

pushd run-mlreco
./install_mlreco.sh
popd

pushd run-cafmaker
./install_cafmaker.sh
popd

# HACK because we forgot to include GNU time in some of the containers
TMP_BIN="tmp_bin"
mkdir -p $TMP_BIN

# If you have it on your host system (/usr/bin/time), copy it into tmp_bin directory
# otherwise, download it from the link provided by Matt
if [ -f /usr/bin/time ]; then
  cp /usr/bin/time $TMP_BIN/
else
  # download the container-compatible version of GNU time into the right path
  TIME_LINK="https://portal.nersc.gov/project/dune/data/2x2/people/mkramer/bin/time"
  wget -q -O "$TMP_BIN/time" ${TIME_LINK} || {
    echo "Download failed"
    exit 1
    } 
    timeProg=$TMP_BIN/time
    # check if "time" is executable
    if [ ! -x $timeProg ]; then
      chmod +x "$timeProg"
    fi
fi