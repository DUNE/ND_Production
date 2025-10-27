#!/bin/bash

ND_PRODUCTION_CONTAINER_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/containers"

# module load singularity
if [[ -z "$ND_PRODUCTION_CONTAINER_DIR" ]]; then
    echo "Set \$ND_PRODUCTION_CONTAINER_DIR to a directory to store singularity container file."
    exit 1
fi

if [[ -d "$ND_PRODUCTION_CONTAINER_DIR" ]]
then
    echo "Found $ND_PRODUCTION_CONTAINER_DIR"
else
    echo "Making $ND_PRODUCTION_CONTAINER_DIR"
    mkdir $ND_PRODUCTION_CONTAINER_DIR
fi

export SINGULARITY_CACHEDIR=$ND_PRODUCTION_CONTAINER_DIR/.singularity
export SINGULARITY_TMPDIR=$ND_PRODUCTION_CONTAINER_DIR/.singularity/tmp

# edit to pull a different container
# GENIE
# CONTAINER_NAME='sim2x2:genie_edep.3_04_00.20230912'
# EDEPSIM
CONTAINER_NAME='sim2x2:ndlar011'

mkdir -p $APPTAINER_TMPDIR

echo "Pulling container... this will take O(1 hour)..."
echo "Container name: ${CONTAINER_NAME}"

singularity pull docker://mjkramer/${CONTAINER_NAME}
# apptainer pull docker://mjkramer/${CONTAINER_NAME}

mv ${CONTAINER_NAME//:/_}.sif $ND_PRODUCTION_CONTAINER_DIR
echo "Finished."
