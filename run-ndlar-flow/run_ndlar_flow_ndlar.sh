#!/usr/bin/env bash

# By default (i.e. if ND_PRODUCTION_RUNTIME isn't set), run on the host
if [[ -z "$ND_PRODUCTION_RUNTIME" || "$ND_PRODUCTION_RUNTIME" == "NONE" ]]; then
    if [[ "$LMOD_SYSTEM_NAME" == "perlmutter" ]]; then
        module unload python 2>/dev/null
        module load python/3.11
    fi
    source ../util/init.inc.sh
    source "$ND_PRODUCTION_INSTALL_DIR/flow.venv/bin/activate"
else
    source ../util/reload_in_container.inc.sh
    source ../util/init.inc.sh
    if [[ -n "$ND_PRODUCTION_USE_LOCAL_PRODUCT" && "$ND_PRODUCTION_USE_LOCAL_PRODUCT" != "0" ]]; then
        # Allow overriding the container's version
        source "$ND_PRODUCTION_INSTALL_DIR/flow.venv/bin/activate"
    fi
fi

inDir=${ND_PRODUCTION_OUTDIR_BASE}/run-larnd-sim/$ND_PRODUCTION_IN_NAME
inName=$ND_PRODUCTION_IN_NAME.$globalIdx
inFile=$(realpath $inDir/LARNDSIM/$subDir/${inName}.LARNDSIM.hdf5)

outFile=$tmpOutDir/${outName}.FLOW.hdf5
rm -f "$outFile"

if [[ "$ND_PRODUCTION_COMPRESS" != "" ]]; then
    echo "Enabling compression of HDF5 datasets with $ND_PRODUCTION_COMPRESS"
    compression="-z $ND_PRODUCTION_COMPRESS"
fi

# charge workflows
workflow1='yamls/ndlar_flow/workflows/charge/charge_event_building_mc.yaml'
workflow2='yamls/ndlar_flow/workflows/charge/charge_event_reconstruction_mc.yaml'
workflow3='yamls/ndlar_flow/workflows/combined/combined_reconstruction_mc.yaml'
workflow4='yamls/ndlar_flow/workflows/charge/prompt_calibration_mc.yaml'
workflow5='yamls/ndlar_flow/workflows/charge/final_calibration_mc.yaml'

# light workflows
workflow6='yamls/ndlar_flow/workflows/light/light_event_building_mc.yaml'
workflow7='yamls/ndlar_flow/workflows/light/light_event_reconstruction_mc.yaml'

# charge-light trigger matching
workflow8='yamls/ndlar_flow/workflows/charge/charge_light_assoc_mc.yaml'

cd "$ND_PRODUCTION_INSTALL_DIR"/ndlar_flow

# Ensure that the second h5flow doesn't run if the first one crashes. This also
# ensures that we properly report the failure to the production system.
set -o errexit

# AB August 6th 2024: Like 2x2, not currently running the final calibration.
#run h5flow -c $workflow1 $workflow2 $workflow3 $workflow4 $workflow5\
run h5flow -c $workflow1 $workflow2 $workflow3 $workflow4\
    -i "$inFile" -o "$outFile" $compression

if [[ "$ND_PRODUCTION_CHARGE_ONLY" != "1" ]]; then
    run h5flow -c $workflow6 $workflow7\
        -i "$inFile" -o "$outFile" $compression

    run h5flow -c $workflow8\
        -i "$outFile" -o "$outFile" $compression
fi

mkdir -p "$outDir/FLOW/$subDir"
mv "$outFile" "$outDir/FLOW/$subDir"
