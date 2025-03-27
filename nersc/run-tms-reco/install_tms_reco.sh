#!/usr/bin/env bash


rm -rf dune-tms

TAG="0.3.0"

( git clone https://github.com/DUNE/dune-tms.git
  cd dune-tms || exit
  # This tag lines up with 2x2_sim tag nd-production-v02.01.
  git checkout tags/$TAG
  source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
  setup edepsim v3_2_0 -f Linux64bit+3.10-2.17 -q e20:prof
  make
  echo "Installed 'dune-tms' with git tag: $TAG" )


exit

