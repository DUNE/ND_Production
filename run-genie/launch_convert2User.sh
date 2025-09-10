#!/bin/sh

export ND_PRODUCTION_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production"
export ND_PRODUCTION_RUNTIME="SINGULARITY"
export ND_PRODUCTION_CONTAINER_DIR="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/containers"
export ND_PRODUCTION_CONTAINER="sim2x2_ndlar011.sif"

export ND_PRODUCTION_NU_NAME=sand-events
export ND_PRODUCTION_OUTDIR_BASE=$ND_PRODUCTION_DIR/productions-new-flux
export ND_PRODUCTION_LOGDIR_BASE=$ND_PRODUCTION_DIR/log-new-flux
export ND_PRODUCTION_INDEX=2

export LD_LIBRARY_PATH=/opt/generators/genie/lib:$LD_LIBRARY_PATH

# for i in $(seq 0 9); do
#     echo $i
#     ND_PRODUCTION_INDEX=$i ./run_convert2User.sh "$@" &
# done

./run_convert2User.sh "$@"


## NB 02/09/2025
# sand-events.0000000.GHEP.root: tNuUSer filled with rotation -0.101
# sand-events.0000001.GHEP.root: tNuUser filled with rotation +0.101
# sand-events.0000002.GHEP.root: tNuInfo contains also beamNuOrigin
# sand-events.0000004.GHEP.root and #3: tNuInfo contains p4nubeam and p4nuuser and x4nubeam and x4nuuser