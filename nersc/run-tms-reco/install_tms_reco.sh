#!/usr/bin/env bash


rm -rf dune-tms


( git clone https://github.com/DUNE/dune-tms.git
  cd dune-tms || exit
  # Tag from Jeff K.
  git checkout tags/TMS_Reco_v0.2 
  source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh 
  setup edepsim v3_2_0 -f Linux64bit+3.10-2.17 -q e20:prof 
  make )


exit

