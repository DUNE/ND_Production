#!/bin/bash

export BASE_DIR="/storage/gpfs_data/neutrino/users/gsantoni"
export ND_PRODUCTION="$BASE_DIR/ND_Production"

export PWD="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-spill-build"

cd $PWD

# new for setup-spill
export ND_PRODUCTION_CONTAINER=sim2x2_ndlar011.sif
export ND_PRODUCTION_NU_NAME=hadd-sand-events
export ND_PRODUCTION_NU_POT=1E16
export ND_PRODUCTION_ROCK_NAME=hadd-sand-rock-events
export ND_PRODUCTION_ROCK_POT=0
export ND_PRODUCTION_OUT_NAME=spill-sand-events

# same
export ND_PRODUCTION_RUNTIME=APPTAINER
export ND_PRODUCTION_CONTAINER_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/containers"
export ND_PRODUCTION_DIR=$ND_PRODUCTION
export ND_PRODUCTION_OUTDIR_BASE=$ND_PRODUCTION/productions-multiple-3
export ND_PRODUCTION_LOGDIR_BASE=$ND_PRODUCTION/log-multiple-3
# export ND_PRODUCTION_INDEX=0

# ./run_spill_build.sh

for i in $(seq 0 4); do
    echo $i
    ND_PRODUCTION_INDEX=$i ./run_spill_build.sh &
done

cd $ND_PRODUCTION