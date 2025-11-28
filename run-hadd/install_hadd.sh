#!/usr/bin/env bash

# assume Shifter if ND_PRODUCTION_RUNTIME is unset
export ND_PRODUCTION_RUNTIME=${ND_PRODUCTION_RUNTIME:-SHIFTER}


# Keep track of what container was set before.
# export ORG_ND_PRODUCTION_CONTAINER=$ND_PRODUCTION_CONTAINER
export ND_PRODUCTION_CONTAINER=$ND_PRODUCTION_CONTAINER_HADD


if [[ "$ND_PRODUCTION_RUNTIME" == "SHIFTER" ]]; then
    # Reload in Shifter
    if [[ "$SHIFTER_IMAGEREQUEST" != "$ND_PRODUCTION_CONTAINER" ]]; then
        shifter --image=$ND_PRODUCTION_CONTAINER --module=none -- "$0" "$@"
        exit
    fi
elif [[ "$ND_PRODUCTION_RUNTIME" == "SINGULARITY" ]]; then
    # Reload in Singularity
    if [[ "$SINGULARITY_NAME" != "$ND_PRODUCTION_CONTAINER" ]]; then
        singularity exec -B $ND_PRODUCTION_DIR,$ND_PRODUCTION_OUTDIR_BASE,$ND_PRODUCTION_LOGDIR_BASE $ND_PRODUCTION_CONTAINER_DIR/$ND_PRODUCTION_CONTAINER /bin/bash "$0" "$@"
        exit
    fi
else
    echo "Unsupported \$ND_PRODUCTION_RUNTIME"
    exit
fi


rm -f getGhepPOT.exe


g++ -o getGhepPOT.exe getGhepPOT.C `root-config --cflags --glibs`


# Put back the original container
# export ND_PRODUCTION_CONTAINER=$ORG_ND_PRODUCTION_CONTAINER


exit
