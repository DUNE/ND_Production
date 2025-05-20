#!/bin/sh

export ND_PRODUCTION_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production"
export ND_PRODUCTION_RUNTIME="SINGULARITY"
export ND_PRODUCTION_CONTAINER_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/containers"
export ND_PRODUCTION_CONTAINER="sim2x2_ndlar011.sif"

./run-convert2spill.sh "$@"