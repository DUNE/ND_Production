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
TAR_PATH=${ND_PRODUCTION_CAFNUSYST_TARBALL:-/cvmfs/fifeuser3.opensciencegrid.org/sw/dune/229a4b6b331c1f923d4a56478c5760c51c3e2c02/my_grid_env.tar.gz}
tar -xzf "$TAR_PATH"

echo "# Cloning nusyst_data"
git clone https://github.com/NuSystematics/nusyst_data.git nusyst_data-src
cd nusyst_data-src
scripts/download_data.sh
cd ..

cd ../..
