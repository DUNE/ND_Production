#!/bin/sh

# configure environment for running sandreco-experimental

export BASE_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production_main"
export ND_PRODUCTION_DIR="${BASE_DIR}/ND_Production"
export ND_PRODUCTION_RUNTIME="SINGULARITY"
export ND_PRODUCTION_CONTAINER_DIR="${BASE_DIR}/workspace/containers"
export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-sand-dev-cpu_latest.sif}

# load container
# N.B. actually, if we run in batch mode (on the cluster), we don't need to run manually the image, 
# since the image is loaded directly in the submit file. To avoid the loading of the image we need
# to set $SINGULARITY_NAME = $ND_PRODUCTION_CONTAINER.
# However, this step can be useful for users who run it with other container managers
source ../util/reload_in_container.inc.sh

pushd $BASE_DIR/run-sandreco
# clone the repo
# N.B. the repo is protected, it works for me since I have a baltig account
# (also ssh-keys, but with https clone it would have asked me username and password).
# The solution is to make the repo public
if [ ! -d "sandreco-experimental/.git" ]; then
    echo "Cloning the repository..."
    # git_url='https://baltig.infn.it/dune/sandreco-experimental.git'
    git_url_ssh='git@baltig.infn.it:dune/sandreco-experimental.git'
    git clone -b 24-write-skeleton-implementation $git_url_ssh
else 
    echo "Repository already exists"
fi
popd

# compile the project (in debug mode?)
# the image is mounted with ND_Production/run-sandreco folder
# N.B. Singularity doesn't give root privilege, 
# so we can't write in /usr/local, we need to install it in a different folder (i.e. install folder)
pushd sandreco-experimental
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=install -DBUILD_DOCUMENTATION=OFF
cmake --build build --target install --parallel
popd