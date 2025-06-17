#!/bin/sh

export ND_PRODUCTION_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production"
export ND_PRODUCTION_RUNTIME="SINGULARITY"
export ND_PRODUCTION_CONTAINER_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/containers"
export ND_PRODUCTION_CONTAINER="sim2x2_ndlar011.sif"

export ND_PRODUCTION_NU_NAME=sand-events
export ND_PRODUCTION_OUT_NAME=sand-events-1706-2
export ND_PRODUCTION_OUTDIR_BASE=$ND_PRODUCTION_DIR/productions-SAND_opt3_DRIFT1
export ND_PRODUCTION_LOGDIR_BASE=$ND_PRODUCTION_DIR/log-SAND_opt3_DRIFT1
export ND_PRODUCTION_INDEX=0

./run_convert4sandreco.sh "$@"