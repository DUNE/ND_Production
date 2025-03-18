#!/bin/bash

export BASE_DIR="/storage/gpfs_data/neutrino/users/gsantoni"
export ND_PRODUCTION="$BASE_DIR/ND_Production"

export PWD="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-hadd"

cd $PWD

# new
export ARCUBE_CONTAINER=sim2x2_ndlar011.sif
export ARCUBE_HADD_FACTOR=10
export ARCUBE_IN_NAME=edep-sand-events
export ARCUBE_OUT_NAME=hadd-sand-events

# same
export ARCUBE_RUNTIME=APPTAINER
export ARCUBE_CONTAINER_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/containers"
export ARCUBE_DIR=$ND_PRODUCTION
export ARCUBE_OUTDIR_BASE=$ND_PRODUCTION/productions-multiple-3
export ARCUBE_LOGDIR_BASE=$ND_PRODUCTION/log-multiple-3
# export ARCUBE_INDEX=0

# ./run_hadd.sh

for i in $(seq 0 4); do
    echo $i
    ARCUBE_INDEX=$i ./run_hadd.sh &
done

cd $ND_PRODUCTION