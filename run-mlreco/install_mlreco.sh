#!/usr/bin/env bash

export ND_PRODUCTION_RUNTIME=SHIFTER
export ND_PRODUCTION_CONTAINER=deeplearnphysics/larcv2:ub2204-cu124-torch251-larndsim

source ../util/reload_in_container.inc.sh

set -o errexit

# recommended by Jeremy
unset which

mkdir -p weights
cd weights
wget https://portal.nersc.gov/project/dune/data/2x2/simulation/mlreco_weights/2x2_240819_snapshot.ckpt
cd ..

mkdir -p install
cd install

# The Ubuntu container doesn't support Python's built-in "venv" module unless we
# globally "apt install python3.8-venv". To avoid the pain of modifying the
# container, instead let's use virtualenv.
wget https://bootstrap.pypa.io/virtualenv/3.8/virtualenv.pyz
python virtualenv.pyz --system-site-packages mlreco.venv
rm virtualenv.pyz

source mlreco.venv/bin/activate
# SuperaAtomic uses the deprecated bdist_wheel so pip >= 25.3 won't work
pip install --upgrade pip==25.2 setuptools==69 wheel

git clone -b v2.4.1 https://github.com/DeepLearnPhysics/larcv2.git
cd larcv2
source configure.sh
make -j16
cd ..

git clone -b v1.9.3 https://github.com/DeepLearnPhysics/SuperaAtomic.git

cd SuperaAtomic
git submodule update --init     # pybind11
pip install .
cd ..

git clone https://github.com/YifanC/larpix_readout_parser.git
cd larpix_readout_parser
pip install .
cd ..

git clone -b main https://github.com/DUNE/h5flow.git
cd h5flow
pip install .
cd ..

git clone https://github.com/larpix/larpix-control.git
cd larpix-control
pip install .
cd ..

## Don't pip install because e.g. config files are expected to live in-tree
git clone -b v5.0.1 https://github.com/DeepLearnPhysics/flow2supera.git

git clone -b v1.4.3 https://github.com/DeepLearnPhysics/spine.git

git clone -b main https://github.com/DeepLearnPhysics/spine-prod.git

# for backward-compatibility with run_mlreco.spine.sh
ln -s spine-prod spine_prod
