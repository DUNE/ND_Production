#!/usr/bin/env bash

export ND_PRODUCTION_CHERRYPICK=1
export ND_PRODUCTION_DET_LOCATION=ProtoDUNE-ND
export ND_PRODUCTION_DK2NU_DIR=/global/cfs/cdirs/dune/users/2x2EventGeneration/NuMI_dk2nu/newtarget-200kA_20220409
export ND_PRODUCTION_EDEP_MAC=macros/2x2_beam.mac
export ND_PRODUCTION_EXPOSURE=1.5E16
export ND_PRODUCTION_GEOM=geometry/Merged2x2MINERvA_noRock.gdml
# export ND_PRODUCTION_OUT_NAME=NuMI_RHC_CHERRY
export ND_PRODUCTION_TUNE=G18_10a_02_11a
export ND_PRODUCTION_XSEC_FILE=/global/cfs/cdirs/dune/users/2x2EventGeneration/inputs/NuMI/${ND_PRODUCTION_TUNE}_FNALsmall.xml

for ntasks in 64 128 192 256; do
    export ND_PRODUCTION_OUT_NAME=NuMI_RHC_CHERRY_${ntasks}tasks
    ./do_submit.sh --ntasks-per-node $ntasks -q debug -t 30
done
