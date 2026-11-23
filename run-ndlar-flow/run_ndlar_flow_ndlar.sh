#!/usr/bin/env bash

export ND_PRODUCTION_SPACK_ENVIRONMENT=${ND_PRODUCTION_SPACK_ENVIRONMENT:-/exp/dune/app/users/abooth/Postdoc/nd-sim-reco/abooth-nd-run-ndlar-flow-lock}
export ND_PRODUCTION_SPACK_VERSION=${ND_PRODUCTION_SPACK_VERSION:-v1.2.2}

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
    # TODO: Not sure what the right logic here re. the if below and the if above.
    if [[ "$ND_PRODUCTION_CONTAINER" == *"fnal-wn-el9"* ]]; then
        #source /cvmfs/dune.opensciencegrid.org/spack/"${ND_PRODUCTION_SPACK_VERSION}"/share/spack/setup-env.sh
        source /exp/dune/app/users/abooth/Postdoc/nd-sim-reco/spack_build_instance_261106/share/spack/setup-env.sh
    
        if [[ -n "$ND_PRODUCTION_SPACK_USER_CACHE_PATH" ]]; then
            export SPACK_USER_CACHE_PATH="$ND_PRODUCTION_SPACK_USER_CACHE_PATH"
        fi
    
        #spack env activate "${ND_PRODUCTION_SPACK_ENVIRONMENT}"
        spack env activate -d "${ND_PRODUCTION_SPACK_ENVIRONMENT}"
        
        export ND_PRODUCTION_INSTALL_DIR=${NDLAR_FLOW_DIR}/..
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

yamldir=${ND_PRODUCTION_YAML_DIR:-ndlar_flow}

# charge workflows
workflow1="yamls/$yamldir/workflows/charge/charge_event_building_mc.yaml"
workflow2="yamls/$yamldir/workflows/charge/charge_event_reconstruction_mc.yaml"
workflow3="yamls/$yamldir/workflows/combined/combined_reconstruction_mc.yaml"
workflow4="yamls/$yamldir/workflows/charge/prompt_calibration_mc.yaml"
workflow5="yamls/$yamldir/workflows/charge/merged_calibration_mc.yaml"
workflow6="yamls/$yamldir/workflows/charge/final_calibration_mc.yaml"

# light workflows
workflow7="yamls/$yamldir/workflows/light/light_event_building_mc.yaml"
workflow8="yamls/$yamldir/workflows/light/light_event_reconstruction_mc.yaml"

# charge-light trigger matching
workflow9="yamls/$yamldir/workflows/charge/charge_light_assoc_mc.yaml"

cd "$ND_PRODUCTION_INSTALL_DIR"/ndlar_flow

# Ensure that the second h5flow doesn't run if the first one crashes. This also
# ensures that we properly report the failure to the production system.
set -o errexit

run h5flow -c $workflow1 $workflow2 $workflow3 $workflow4 $workflow5 $workflow6\
    -i "$inFile" -o "$outFile" $compression

if [[ -z "$ND_PRODUCTION_CHARGE_ONLY" || "$ND_PRODUCTION_CHARGE_ONLY" == "0" ]]; then
    run h5flow -c $workflow7 $workflow8\
        -i "$inFile" -o "$outFile" $compression
    run h5flow -c $workflow9\
        -i "$outFile" -o "$outFile" $compression
fi

mkdir -p "$outDir/FLOW/$subDir"
mv "$outFile" "$outDir/FLOW/$subDir"
