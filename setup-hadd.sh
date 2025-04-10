#!/bin/bash

export BASE_DIR="/storage/gpfs_data/neutrino/users/gsantoni"
export WORKING_DIR="$BASE_DIR/ND_Production"

export PWD="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-hadd"

cd $PWD

# new
export ND_PRODUCTION_CONTAINER=sim2x2_ndlar011.sif
export ND_PRODUCTION_HADD_FACTOR=10
export ND_PRODUCTION_IN_NAME=sand-events
export ND_PRODUCTION_OUT_NAME=sand-events

# same
export ND_PRODUCTION_RUNTIME=APPTAINER
export ND_PRODUCTION_CONTAINER_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/containers"
export ND_PRODUCTION_DIR=$WORKING_DIR
export ND_PRODUCTION_OUTDIR_BASE=$WORKING_DIR/productions-SAND_opt3_DRIFT1
export ND_PRODUCTION_LOGDIR_BASE=$WORKING_DIR/log-SAND_opt3_DRIFT1
export ND_PRODUCTION_INDEX=0

./run_hadd.sh

# for i in $(seq 0 1); do
#     echo $i
#     ND_PRODUCTION_INDEX=$i ./run_hadd.sh &
# done

cd $WORKING_DIR