#!/usr/bin/env bash

export ND_PRODUCTION_RUNTIME='SHIFTER'
export ND_PRODUCTION_CONTAINER='mjkramer/sim2x2:genie_edep.LFG_testing.20230228.v2'
export ND_PRODUCTION_CHERRYPICK='0'
export ND_PRODUCTION_DET_LOCATION='ProtoDUNE-ND'
export ND_PRODUCTION_DK2NU_DIR='/global/cfs/cdirs/dune/users/2x2EventGeneration/NuMI_dk2nu/newtarget-200kA_20220409'
export ND_PRODUCTION_EDEP_MAC='macros/2x2_beam.mac'
export ND_PRODUCTION_EXPOSURE='1E15'
export ND_PRODUCTION_GEOM='geometry/Merged2x2MINERvA_v2/Merged2x2MINERvA_v2_noRock.gdml'
export ND_PRODUCTION_GEOM_EDEP='geometry/Merged2x2MINERvA_v2/Merged2x2MINERvA_v2_withRock.gdml'
export ND_PRODUCTION_TUNE='D22_22a_02_11b'
export ND_PRODUCTION_XSEC_FILE='/global/cfs/cdirs/dune/users/2x2EventGeneration/inputs/NuMI/D22_22a_02_11b.all.LFG_testing.20230228.spline.xml'
export ND_PRODUCTION_OUT_NAME='test_MiniRun3.nu'

for i in $(seq 0 9); do
    ND_PRODUCTION_INDEX=$i ./run_edep_sim.sh &
done

wait
