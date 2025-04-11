#!/usr/bin/env bash

# Spawn a shell in the mlreco environment. Useful for interactive testing.

export ND_PRODUCTION_RUNTIME=SHIFTER
export ND_PRODUCTION_CONTAINER=deeplearnphysics/larcv2:ub20.04-cuda11.6-pytorch1.13-larndsim

if [[ "$SHIFTER_IMAGEREQUEST" != "$ND_PRODUCTION_CONTAINER" ]]; then
    shifter --image=$ND_PRODUCTION_CONTAINER --module=cvmfs,gpu -- /bin/bash --init-file "$0"
    exit
fi

source load_mlreco.inc.sh

alias ls='ls --color=auto'
PS1='\W $ '
