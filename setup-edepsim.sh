export BASE_DIR="/storage/gpfs_data/neutrino/users/gsantoni"
export ND_PRODUCTION="$BASE_DIR/ND_Production"

export PWD="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-edep-sim"

cd $PWD

# nuove di edepsim
export ARCUBE_CONTAINER=sim2x2_ndlar011.sif
export ARCUBE_GENIE_NAME=genie-arcube-events
export ARCUBE_EDEP_MAC=macros/2x2_beam.mac
export ARCUBE_GEOM_EDEP=geometry/Merged2x2MINERvA_v4/Merged2x2MINERvA_v4_noRock.gdml
export ARCUBE_RUN_OFFSET=0
export ARCUBE_OUT_NAME=edep-arcube-events

# stesse di genie da reimportare (o comunque capire come sistemarle)
export ARCUBE_RUNTIME=APPTAINER
export ARCUBE_CONTAINER_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/containers"
export ARCUBE_DIR=$ND_PRODUCTION
export ARCUBE_OUTDIR_BASE=$ND_PRODUCTION/productions
export ARCUBE_LOGDIR_BASE=$ND_PRODUCTION/log

# for i in $(seq 0 9); do
#     ARCUBE_INDEX=$i ./run_edep_sim.sh &
# done

# wait

./run_edep_sim.sh