#!/bin/bash

export BASE_DIR="/storage/gpfs_data/neutrino/users/gsantoni"
export ND_PRODUCTION="$BASE_DIR/ND_Production"

export PWD="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-spill-build"

cd $PWD

# new for setup-spill
export ARCUBE_CONTAINER=sim2x2_ndlar011.sif
export ARCUBE_NU_NAME=hadd-sand-events
export ARCUBE_NU_POT=1E16
export ARCUBE_ROCK_NAME=hadd-sand-rock-events
export ARCUBE_ROCK_POT=0
export ARCUBE_OUT_NAME=spill-sand-events

# same
export ARCUBE_RUNTIME=APPTAINER
export ARCUBE_CONTAINER_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/containers"
export ARCUBE_DIR=$ND_PRODUCTION
export ARCUBE_OUTDIR_BASE=$ND_PRODUCTION/productions-multiple-3
export ARCUBE_LOGDIR_BASE=$ND_PRODUCTION/log-multiple-3
# export ARCUBE_INDEX=0

# ./run_spill_build.sh

for i in $(seq 0 4); do
    echo $i
    ARCUBE_INDEX=$i ./run_spill_build.sh &
done

cd $ND_PRODUCTION