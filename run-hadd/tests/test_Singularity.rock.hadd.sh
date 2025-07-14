#!/usr/bin/env bash

export ND_PRODUCTION_DIR='/nfs/data41/dune/cuddandr/2x2_sim/'
export ND_PRODUCTION_RUNTIME='SINGULARITY'
export ND_PRODUCTION_CONTAINER_DIR='/nfs/data41/dune/cuddandr/2x2_sim/admin/containers'
export ND_PRODUCTION_CONTAINER='sim2x2_genie_edep.LFG_testing.20230228.v2.sif'
export ND_PRODUCTION_HADD_FACTOR='2'
export ND_PRODUCTION_IN_NAME='test_Singularity.rock'
export ND_PRODUCTION_OUT_NAME='test_Singularity.rock.hadd'
export ND_PRODUCTION_INDEX='0'

./run_hadd.sh
