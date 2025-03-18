#!/bin/bash

export BASE_DIR="/storage/gpfs_data/neutrino/users/gsantoni"
export ND_PRODUCTION="$BASE_DIR/ND_Production"

export PWD="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-edep-sim"

# cd $PWD

# new edep-sim settings
export ARCUBE_CONTAINER=sim2x2_ndlar011.sif
export ARCUBE_GENIE_NAME=sand-events
export ARCUBE_EDEP_MAC=macros/macro-sand.mac
# export ARCUBE_GEOM_EDEP="geometry/Merged2x2MINERvA_v4/Merged2x2MINERvA_v4_noRock.gdml"
export ARCUBE_GEOM_EDEP=geometry-sand/new-geometries/SAND_opt3_DRIFT1.gdml
export ARCUBE_RUN_OFFSET=0
export ARCUBE_OUT_NAME=sand-events

# same of genie
export ARCUBE_RUNTIME=APPTAINER
export ARCUBE_CONTAINER_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/containers"
export ARCUBE_DIR=$ND_PRODUCTION
export ARCUBE_OUTDIR_BASE=$ND_PRODUCTION/productions-SAND_opt3_DRIFT1
export ARCUBE_LOGDIR_BASE=$ND_PRODUCTION/log-SAND_opt3_DRIFT1
# export ARCUBE_INDEX=0

# for i in $(seq 0 9); do
#     ARCUBE_INDEX=$i ./run_edep_sim.sh &
# done

# wait

# ./run_edep_sim.sh
