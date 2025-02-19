#!/bin/bash

ARCUBE_CONTAINER_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/containers"

# module load singularity
if [[ -z "$ARCUBE_CONTAINER_DIR" ]]; then
    echo "Set \$ARCUBE_CONTAINER_DIR to a directory to store singularity container file."
    exit 1
fi

if [[ -d "$ARCUBE_CONTAINER_DIR" ]]
then
    echo "Found $ARCUBE_CONTAINER_DIR"
else
    echo "Making $ARCUBE_CONTAINER_DIR"
    mkdir $ARCUBE_CONTAINER_DIR
fi

export APPTAINER_CACHEDIR=$ARCUBE_CONTAINER_DIR/.apptainer 
export APPTAINER_TMPDIR=$ARCUBE_CONTAINER_DIR/.apptainer/tmp

# edit to pull a different container
CONTAINER_NAME='sim2x2:genie_edep.3_04_00.20230912'

mkdir -p $APPTAINER_TMPDIR

echo "Pulling container... this will take O(1 hour)..."
echo "Container name: ${CONTAINER_NAME}"

# singularity pull docker://mjkramer/${CONTAINER_NAME}
apptainer pull docker://mjkramer/${CONTAINER_NAME}

mv ${CONTAINER_NAME//:/_}.sif $ARCUBE_CONTAINER_DIR
echo "Finished."
