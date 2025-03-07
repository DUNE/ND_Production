#!/bin/bash

export BASE_DIR="/storage/gpfs_data/neutrino/users/gsantoni"
export ND_PRODUCTION="$BASE_DIR/ND_Production"

export PWD="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-genie"

# commentare se mandato sul cluster (anche se non credo sia necessario). 
# è necessario invece se lo mando da bash, altrimenti non riesce a eseguire run_genie.sh
# cd $PWD

# set the variables for reload_in_container.inc.sh
export ARCUBE_CONTAINER="sim2x2_genie_edep.3_04_00.20230912.sif"
export ARCUBE_RUNTIME=${ARCUBE_RUNTIME:-APPTAINER}
export ARCUBE_CONTAINER_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/containers"
export ARCUBE_DIR=$ND_PRODUCTION

# set the variables for init.inc.sh
export ARCUBE_OUTDIR_BASE=$ND_PRODUCTION/productions-volSAND-HPC2
export ARCUBE_LOGDIR_BASE=$ND_PRODUCTION/log-volSAND-HPC2
export ARCUBE_OUT_NAME="genie-sand-events"

# set the variables for run-genie.sh
export ARCUBE_CONTAINER="sim2x2_genie_edep.3_04_00.20230912.sif"
export ARCUBE_DK2NU_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/dk2nu_files_Sept21/neutrino"
# export ARCUBE_GEOM="geometry/Merged2x2MINERvA_v4/Merged2x2MINERvA_v4_noRock.gdml"
export ARCUBE_GEOM="geometry-sand/EC_yoke_corrected_1212_dev_SAND_complete_opt3_DRIFT1.gdml" #SAND
# importante mettere il TUNE ufficiale di DUNE
export ARCUBE_TUNE="AR23_20i_00_000"
# export ARCUBE_DET_LOCATION="MiniRun5-Nu"
export ARCUBE_DET_LOCATION="DUNEND"
export ARCUBE_TOP_VOLUME="volSAND"
export ARCUBE_EXPOSURE=1E15
export ARCUBE_RUN_OFFSET=0
export ARCUBE_XSEC_FILE=/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-genie/XSEC/genie_xsec/v3_04_00/NULL/AR2320i00000-k250-e1000/data/gxspl-NUsmall.xml
# non servono le xsec prodotte da noi
# export ARCUBE_XSEC_FILE=/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-genie/XSEC/EC_yoke_corrected_1212_dev_SAND_complete_opt3_DRIFT1.xsec.xml


# for i in $(seq 0 1); do
#     echo $i
#     ARCUBE_INDEX=$i ./run_genie.sh &
# done

# wait

# ./run_genie.sh
