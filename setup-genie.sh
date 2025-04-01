#!/bin/bash

export BASE_DIR="/storage/gpfs_data/neutrino/users/gsantoni"
export WORKING_DIR="$BASE_DIR/ND_Production"

export PWD="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-genie"

# comment if you run on cluster (even though I think is not necessary). 
# is necessary if I run on bash, since otherwise it doesn't see run_genie.sh
# cd $PWD

# set the variables for reload_in_container.inc.sh
export ND_PRODUCTION_CONTAINER="sim2x2_genie_edep.3_04_00.20230912.sif"
export ND_PRODUCTION_RUNTIME=${ND_PRODUCTION_RUNTIME:-APPTAINER}
export ND_PRODUCTION_CONTAINER_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/containers"
export ND_PRODUCTION_DIR=$WORKING_DIR

# set the variables for init.inc.sh
export ND_PRODUCTION_OUTDIR_BASE=$WORKING_DIR/productions-check-maxpath
export ND_PRODUCTION_LOGDIR_BASE=$WORKING_DIR/log-check-maxpath
export ND_PRODUCTION_OUT_NAME="sand-events"

# set the variables for run-genie.sh
export ND_PRODUCTION_DK2NU_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/dk2nu_files_Sept21/neutrino"
# export ND_PRODUCTION_GEOM="geometry/Merged2x2MINERvA_v4/Merged2x2MINERvA_v4_noRock.gdml"
export ND_PRODUCTION_GEOM="geometry-sand/new-geometries/SAND_opt3_DRIFT1.gdml" #SAND
# important to set official DUNE tune
export ND_PRODUCTION_TUNE="AR23_20i_00_000"
# export ND_PRODUCTION_DET_LOCATION="MiniRun5-Nu"
export ND_PRODUCTION_DET_LOCATION="DUNEND"
export ND_PRODUCTION_TOP_VOLUME="volSAND"
export ND_PRODUCTION_EXPOSURE=1E16
export ND_PRODUCTION_RUN_OFFSET=0
export ND_PRODUCTION_XSEC_FILE=/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-genie/XSEC/genie_xsec/v3_04_00/NULL/AR2320i00000-k250-e1000/data/gxspl-NUsmall.xml
# export ND_PRODUCTION_INDEX=0

# for i in $(seq 0 1); do
#     echo $i
#     ND_PRODUCTION_INDEX=$i ./run_genie.sh &
# done

# wait

# ./run_genie.sh
