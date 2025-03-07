#!/bin/bash

export BASE_DIR="/storage/gpfs_data/neutrino/users/gsantoni"
export ND_PRODUCTION="$BASE_DIR/ND_Production"

export PWD="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-edep-sim"

# cd $PWD

# nuove di edepsim
export ARCUBE_CONTAINER=sim2x2_ndlar011.sif
export ARCUBE_GENIE_NAME=genie-sand-events
export ARCUBE_EDEP_MAC=macros/macro.mac
export ARCUBE_GEOM_EDEP=geometry-sand/EC_yoke_corrected_1212_dev_SAND_complete_opt3_DRIFT1.gdml
export ARCUBE_RUN_OFFSET=0
export ARCUBE_OUT_NAME=edep-sand-events

# stesse di genie da reimportare (o comunque capire come sistemarle)
export ARCUBE_RUNTIME=APPTAINER
export ARCUBE_CONTAINER_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/containers"
export ARCUBE_DIR=$ND_PRODUCTION
export ARCUBE_OUTDIR_BASE=$ND_PRODUCTION/productions-volSAND-HPC2
export ARCUBE_LOGDIR_BASE=$ND_PRODUCTION/log-volSAND-HPC2

# for i in $(seq 0 9); do
#     ARCUBE_INDEX=$i ./run_edep_sim.sh &
# done

# wait

# ./run_edep_sim.sh
