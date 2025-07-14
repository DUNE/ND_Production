#!/usr/bin/env bash

export ND_PRODUCTION_DIR='/nfs/data41/dune/cuddandr/2x2_sim/'
export ND_PRODUCTION_RUNTIME='SINGULARITY'
export ND_PRODUCTION_CONTAINER_DIR='/nfs/data41/dune/cuddandr/2x2_sim/admin/containers'
export ND_PRODUCTION_CONTAINER='sim2x2_genie_edep.LFG_testing.20230228.v2.sif'
export ND_PRODUCTION_CHERRYPICK='0'
export ND_PRODUCTION_DET_LOCATION='ProtoDUNE-ND'
export ND_PRODUCTION_DK2NU_DIR='/nfs/data41/dune/cuddandr/2x2_inputs/dk2nu'
export ND_PRODUCTION_EDEP_MAC='macros/2x2_beam.mac'
export ND_PRODUCTION_EXPOSURE='1E15'
export ND_PRODUCTION_GEOM='geometry/Merged2x2MINERvA_v2/Merged2x2MINERvA_v2_noRock.gdml'
export ND_PRODUCTION_GEOM_EDEP='geometry/Merged2x2MINERvA_v2/Merged2x2MINERvA_v2_withRock.gdml'
export ND_PRODUCTION_TUNE='D22_22a_02_11b'
export ND_PRODUCTION_XSEC_FILE='/nfs/data41/dune/cuddandr/2x2_inputs/D22_22a_02_11b.all.LFG_testing.20230228.spline.xml'
export ND_PRODUCTION_OUT_NAME='test_Singularity.nu'

for i in $(seq 10); do
    ND_PRODUCTION_INDEX=$i ./run_edep_sim.sh &
done

wait
