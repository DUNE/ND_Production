#!/bin/bash

export BASE_DIR="/storage/gpfs_data/neutrino/users/gsantoni"
export ND_PRODUCTION_DIR="$BASE_DIR/ND_Production"

export PWD="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-edep-sim"

# cd $PWD

# new edep-sim settings
export ND_PRODUCTION_CONTAINER=sim2x2_ndlar011.sif
export ND_PRODUCTION_GENIE_NAME=sand-events
export ND_PRODUCTION_EDEP_MAC=macros/macro-sand.mac
# export ND_PRODUCTION_GEOM_EDEP="geometry/Merged2x2MINERvA_v4/Merged2x2MINERvA_v4_noRock.gdml"
export ND_PRODUCTION_GEOM_EDEP=geometry-sand/new-geometries/SAND_opt3_DRIFT1.gdml
export ND_PRODUCTION_RUN_OFFSET=0
export ND_PRODUCTION_OUT_NAME=sand-events

# same of genie
export ND_PRODUCTION_RUNTIME=SINGULARITY
export ND_PRODUCTION_CONTAINER_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/containers"
# export ND_PRODUCTION_DIR=$WORKING_DIR
export ND_PRODUCTION_OUTDIR_BASE=$ND_PRODUCTION_DIR/productions-check2
export ND_PRODUCTION_LOGDIR_BASE=$ND_PRODUCTION_DIR/log-check2
# export ND_PRODUCTION_INDEX=0

# for i in $(seq 0 9); do
#     ND_PRODUCTION_INDEX=$i ./run_edep_sim.sh &
# done

# wait

# ./run_edep_sim.sh
