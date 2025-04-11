#!/usr/bin/env bash

export ND_PRODUCTION_DIR='/nfs/data41/dune/cuddandr/2x2_sim/'
export ND_PRODUCTION_RUNTIME='SINGULARITY'
export ND_PRODUCTION_CONTAINER_DIR='/nfs/data41/dune/cuddandr/2x2_sim/admin/containers'
export ND_PRODUCTION_CONTAINER='sim2x2_genie_edep.LFG_testing.20230228.v2.sif'
export ND_PRODUCTION_NU_NAME='test_Singularity.nu.hadd'
export ND_PRODUCTION_NU_POT='1E15'
export ND_PRODUCTION_ROCK_NAME='test_Singularity.rock.hadd'
export ND_PRODUCTION_ROCK_POT='1E15'
export ND_PRODUCTION_OUT_NAME='test_Singularity.spill'
export ND_PRODUCTION_INDEX='0'

./run_spill_build.sh
