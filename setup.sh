export BASE_DIR="/storage/gpfs_data/neutrino/users/gsantoni"
export TWOBYTWO_SIM="$BASE_DIR/2x2_sim"

cd $TWOBYTWO_SIM/run-genie

# set the variables for reload_in_container.inc.sh
export ARCUBE_CONTAINER="sim2x2_genie_edep.3_04_00.20230912.sif"
export ARCUBE_RUNTIME=${ARCUBE_RUNTIME:-APPTAINER}
export ARCUBE_CONTAINER_DIR="/storage/gpfs_data/neutrino/users/gsantoni/2x2_sim/containers"
export ARCUBE_DIR=$TWOBYTWO_SIM

# set the variables for init.inc.sh
export ARCUBE_OUTDIR_BASE="./genie-productions"
export ARCUBE_OUT_NAME="tutorial.genie.nu"

# set the variables for run-genie.sh
export ARCUBE_CONTAINER="sim2x2_genie_edep.3_04_00.20230912.sif"
export ARCUBE_DK2NU_DIR="/storage/gpfs_data/neutrino/users/gsantoni/2x2_sim/dk2nu_files_Sept21/neutrino"
# export ARCUBE_GEOM_GDML="geometry-sand/EC_yoke_corrected_1212_dev_SAND_complete_opt3_DRIFT1.gdml"
export ARCUBE_GEOM_GDML="geometry/Merged2x2MINERvA_v3/Merged2x2MINERvA_v3_noRock.gdml"
# export ARCUBE_GEOM_ROOT="geometry-sand/EC_yoke_corrected_1212_dev_SAND_complete_opt3_DRIFT1.root"
export ARCUBE_TUNE="AR23_20i_00_000"
export ARCUBE_DET_LOCATION="MiniRun5-Nu"
export ARCUBE_EXPOSURE=1E15
export ARCUBE_XSEC_FILE="/storage/gpfs_data/neutrino/users/gsantoni/2x2_sim/run-genie/XSEC/SAND_opt2.xsec.14.xml" # si fermerà qui perchè il container ha genie 3.04.00 e queste sono con 3.04.02

# for i in $(seq 0 1); do
#     echo $i
#     ARCUBE_INDEX=$i ./run_genie.sh &
# done

# wait

./run_genie.sh