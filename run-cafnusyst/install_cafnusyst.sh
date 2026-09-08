#!/bin/bash

set -o errexit
set -o pipefail

if [ -d install ];
then
  echo "install directory already exists. Delete before rerunning install_cafnusyst.sh"
  exit 1
fi

mkdir install
cd install
mkdir workspace
cd workspace

echo "# Extracting Spack environment from CVMFS..."
# TODO: this points at a one-off build in a user's grid scratch area, which
# is not a stable location for production use. This needs to be replaced
# with a properly versioned/published cafnusyst build (e.g. on CVMFS) before
# this jobscript is used for real production running.
TAR_PATH=${ND_PRODUCTION_CAFNUSYST_TARBALL:-/cvmfs/fifeuser2.opensciencegrid.org/sw/dune/a2116fdebdb748ef9329dde4e51c46ae4a89f275/my_grid_env.tar.gz}
tar -xzf "$TAR_PATH"

cd ../..
