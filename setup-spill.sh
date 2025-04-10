#!/bin/bash

export BASE_DIR="/storage/gpfs_data/neutrino/users/gsantoni"
export WORKING_DIR="$BASE_DIR/ND_Production"

export PWD="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-spill-build"

cd $PWD

# new for setup-spill
export ND_PRODUCTION_CONTAINER=sim2x2_ndlar011.sif
export ND_PRODUCTION_NU_NAME=sand-events
export ND_PRODUCTION_NU_POT=1E16
export ND_PRODUCTION_ROCK_NAME=rock-events
export ND_PRODUCTION_ROCK_POT=0
export ND_PRODUCTION_OUT_NAME=sand-events

# same
export ND_PRODUCTION_RUNTIME=APPTAINER
export ND_PRODUCTION_CONTAINER_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/containers"
export ND_PRODUCTION_DIR=$WORKING_DIR
export ND_PRODUCTION_OUTDIR_BASE=$WORKING_DIR/productions-SAND_opt3_DRIFT1
export ND_PRODUCTION_LOGDIR_BASE=$WORKING_DIR/log-SAND_opt3_DRIFT1
export ND_PRODUCTION_INDEX=0

./run_spill_build.sh

# for i in $(seq 0 4); do
#     echo $i
#     ND_PRODUCTION_INDEX=$i ./run_spill_build.sh &
# done

# wait

cd $WORKING_DIR