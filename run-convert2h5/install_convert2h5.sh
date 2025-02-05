#!/usr/bin/env bash

# assume Shifter if ND_PRODUCTION_RUNTIME is unset
export ND_PRODUCTION_RUNTIME=${ND_PRODUCTION_RUNTIME:-SHIFTER}

if [[ -z "$ND_PRODUCTION_CONTAINER" ]]; then
    echo "Set \$ND_PRODUCTION_CONTAINER to the GENIE+edep-sim container"
    exit 1
fi

if [[ "$ND_PRODUCTION_RUNTIME" == "SHIFTER" ]]; then
    # Reload in Shifter
    if [[ "$SHIFTER_IMAGEREQUEST" != "$ND_PRODUCTION_CONTAINER" ]]; then
        shifter --image=$ND_PRODUCTION_CONTAINER --module=none -- "$0" "$@"
        exit
    fi

elif [[ "$ND_PRODUCTION_RUNTIME" == "SINGULARITY" ]]; then
    # Or reload in Singularity
    if [[ "$SINGULARITY_NAME" != "$ND_PRODUCTION_CONTAINER" ]]; then
        singularity exec -B $ND_PRODUCTION_DIR $ND_PRODUCTION_CONTAINER_DIR/$ND_PRODUCTION_CONTAINER /bin/bash "$0" "$@"
        exit
    fi

else
    echo "Unsupported \$ND_PRODUCTION_RUNTIME"
    exit
fi

if [[ "$ND_PRODUCTION_RUNTIME" == "SHIFTER" ]]; then
    source /environment         # provided by the container
elif [[ "$ND_PRODUCTION_RUNTIME" == "SINGULARITY" ]]; then
    # "singularity pull" overwrites /environment
    source "$ND_PRODUCTION_DIR"/admin/container_env."$ND_PRODUCTION_CONTAINER".sh
else
    echo "Unsupported \$ND_PRODUCTION_RUNTIME"
    exit
fi

rm -rf convert.venv
python3 -m venv convert.venv
source convert.venv/bin/activate

pip3 install -r requirements.txt
