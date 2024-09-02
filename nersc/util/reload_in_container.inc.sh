#!/usr/bin/env bash

# Not currently used in ND_Production, will need it when 
# things are fully ported from 2x2_sim.
setup_cuda() {
    module unload cudatoolkit 2>/dev/null
    module load cudatoolkit/12.2
}

# Assume Shifter if ND_PRODUCTION_RUNTIME is unset.
# (Individual scripts can override this; e.g. larnd-sim by default runs on the
# host, not in Shifter)
export ND_PRODUCTION_RUNTIME=${ND_PRODUCTION_RUNTIME:-SHIFTER}

if [[ "$ND_PRODUCTION_RUNTIME" == "SHIFTER" ]]; then
    # Reload in Shifter
    if [[ "$SHIFTER_IMAGEREQUEST" != "$ND_PRODUCTION_CONTAINER" ]]; then
        setup_cuda
        shifter --image=$ND_PRODUCTION_CONTAINER --module=cvmfs,gpu -- "$0" "$@"
        exit
    fi

elif [[ "$ND_PRODUCTION_RUNTIME" == "SINGULARITY" ]]; then
    # Or reload in Singularity
    if [[ "$SINGULARITY_NAME" != "$ND_PRODUCTION_CONTAINER" ]]; then
        singularity exec -B $ND_PRODUCTION_DIR $ND_PRODUCTION_CONTAINER_DIR/$ND_PRODUCTION_CONTAINER /bin/bash "$0" "$@"
        exit
    fi

elif [[ "$ND_PRODUCTION_RUNTIME" == "PODMAN-HPC" ]]; then
    # The ND_Production/nersc directory:
    nd_production_dir=$(realpath $(dirname "$BASH_SOURCE")/..)
    # HACK: Check if we're "in podman" by seeing whether our UID is 0 (root)
    # This will break if you run ND_Production as the true superuser, but why would
    # you do that?
    if [[ "$(id -u)" != "0" ]]; then
        setup_cuda
        podman-hpc run --rm --env-file <(env | grep ND_PRODUCTION) --gpu -w "$(realpath $(dirname "$0"))" \
            -v "$nd_production_dir:$nd_production_dir" -v "$SCRATCH:$SCRATCH" -v /dvs_ro/cfs:/dvs_ro/cfs \
            -v /opt/nvidia/hpc_sdk/Linux_x86_64/23.9:/opt/cuda \
            "$ND_PRODUCTION_CONTAINER" "$(realpath "$0")" "$@"
        exit
    fi

elif [[ "$ND_PRODUCTION_RUNTIME" == "NONE" ]]; then
    echo "\$ND_PRODUCTION_RUNTIME is NONE; running in host environment"
    return

else
    echo "Unsupported \$ND_PRODUCTION_RUNTIME"
    exit 1
fi

# The below runs in the "reloaded" process

if [[ "$ND_PRODUCTION_RUNTIME" == "SHIFTER" ]]; then
    if [[ -e /environment ]]; then
        source /environment # apptainer-built containters
        # Our podman-built containers automagically load the env via $BASH_ENV
        # In their case the file of interest is /opt/environment
    fi
    # See comments below re podman-hpc and cuda
    cudadir=/global/common/software/dune/cuda-23.9
    # TODO: Extend this until larnd-sim actually runs
    export LD_LIBRARY_PATH="$cudadir"/math_libs/12.2/targets/x86_64-linux/lib:"$cudadir"/cuda/12.2/lib64:$LD_LIBRARY_PATH
elif [[ "$ND_PRODUCTION_RUNTIME" == "PODMAN-HPC" ]]; then
    # Ideally, we'd just tell podman-hpc to overlay the host's libcudart and
    # libcudablas into the container's /usr/lib64, but that currently produces a
    # useless error. So for now we just bind mount /opt/cuda (above) and set
    # LD_LIBRARY_PATH here.
    export LD_LIBRARY_PATH=/opt/cuda/math_libs/12.2/targets/x86_64-linux/lib:/opt/cuda/cuda/12.2/lib64:$LD_LIBRARY_PATH
fi
