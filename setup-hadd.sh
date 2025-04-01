#!/bin/bash

export BASE_DIR="/storage/gpfs_data/neutrino/users/gsantoni"
export ND_PRODUCTION="$BASE_DIR/ND_Production"

export PWD="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-hadd"

cd $PWD

# new
export ND_PRODUCTION_CONTAINER=sim2x2_ndlar011.sif
export ND_PRODUCTION_HADD_FACTOR=10
export ND_PRODUCTION_IN_NAME=edep-sand-events
export ND_PRODUCTION_OUT_NAME=hadd-sand-events

# same
export ND_PRODUCTION_RUNTIME=APPTAINER
export ND_PRODUCTION_CONTAINER_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/containers"
export ND_PRODUCTION_DIR=$ND_PRODUCTION
export ND_PRODUCTION_OUTDIR_BASE=$ND_PRODUCTION/productions-multiple-3
export ND_PRODUCTION_LOGDIR_BASE=$ND_PRODUCTION/log-multiple-3
# export ND_PRODUCTION_INDEX=0

# ./run_hadd.sh

for i in $(seq 0 4); do
    echo $i
    ND_PRODUCTION_INDEX=$i ./run_hadd.sh &
done

cd $ND_PRODUCTION