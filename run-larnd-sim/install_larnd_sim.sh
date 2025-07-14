#!/usr/bin/env bash

source ../util/prelude.inc.sh

setup_cuda

installDir=${1:-.}
venvName=larnd.venv

if [[ -e "$installDir/$venvName" ]]; then
  echo "$installDir/$venvName already exists; delete it then run me again"
  exit 1
fi

if [[ -e "$installDir/larnd-sim" ]]; then
  echo "$installDir/larnd-sim already exists; delete it then run me again"
  exit 1
fi

mkdir -p "$installDir"
cd "$installDir"

python -m venv "$venvName"
source "$venvName"/bin/activate
pip install --upgrade pip setuptools wheel

# Might need to remove larnd-sim from this requirements file. DONE.
# pip install -r requirements.txt
# exit

# If installation via requirements.txt doesn't work, the below should rebuild
# the venv. Ideally, install everything *except* larnd-sim using the
# requirements.txt, then just use the block at the bottom to install larnd-sim.

# pip install -U pip wheel setuptools
# pip install cupy-cuda11x

pip install cupy-cuda12x

# https://docs.nersc.gov/development/languages/python/using-python-perlmutter/#installing-with-pip
( git clone -b develop https://github.com/DUNE/larnd-sim.git
  cd larnd-sim
  pip install -e . )
