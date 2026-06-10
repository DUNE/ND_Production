#!/usr/bin/env bash

# By default (i.e. if ND_PRODUCTION_RUNTIME isn't set), run on the host
if [[ -z "$ND_PRODUCTION_RUNTIME" || "$ND_PRODUCTION_RUNTIME" == "NONE" ]]; then
    if [[ "$LMOD_SYSTEM_NAME" == "perlmutter" ]]; then
        module unload python 2>/dev/null
        module load python/3.11
        echo 1
    fi
    echo 2
    source ../util/init.inc.sh
    source "$ND_PRODUCTION_INSTALL_DIR/flow.venv/bin/activate"
else
    echo 3
    source ../util/reload_in_container.inc.sh
    source ../util/init.inc.sh
    if [[ -n "$ND_PRODUCTION_USE_LOCAL_PRODUCT" && "$ND_PRODUCTION_USE_LOCAL_PRODUCT" != "0" ]]; then
        # Allow overriding the container's version
        source "$ND_PRODUCTION_INSTALL_DIR/flow.venv/bin/activate"
        echo 4
    fi
fi

# inDir=${ND_PRODUCTION_OUTDIR_BASE}/run-larnd-sim/$ND_PRODUCTION_IN_NAME
# inName=$ND_PRODUCTION_IN_NAME.$globalIdx
# inFile=$(realpath $inDir/LARNDSIM/$subDir/${inName}.LARNDSIM.hdf5)

# outFile=$tmpOutDir/${outName}.FLOW.hdf5
# rm -f "$outFile"

if [[ "$ND_PRODUCTION_COMPRESS" != "" ]]; then
    echo "Enabling compression of HDF5 datasets with $ND_PRODUCTION_COMPRESS"
    compression="-z $ND_PRODUCTION_COMPRESS"
fi

# charge workflows
workflow1='yamls/proto_nd_flow/workflows/charge/charge_event_building_mc.yaml'
workflow2='yamls/proto_nd_flow/workflows/charge/charge_event_reconstruction_mc.yaml'
workflow3='yamls/proto_nd_flow/workflows/combined/combined_reconstruction_mc.yaml'
workflow4='yamls/proto_nd_flow/workflows/charge/prompt_calibration_mc.yaml'
workflow5='yamls/proto_nd_flow/workflows/charge/final_calibration_mc.yaml'

# light workflows
workflow6='yamls/proto_nd_flow/workflows/light/light_event_building_mc.yaml'
workflow7='yamls/proto_nd_flow/workflows/light/light_event_reconstruction_mc.yaml'

# charge-light trigger matching
workflow8='yamls/proto_nd_flow/workflows/charge/charge_light_assoc_mc.yaml'

if [[ "$ND_PRODUCTION_MC" == "0" ]]; then

    workflow1='yamls/proto_nd_flow/workflows/charge/charge_event_building_data.yaml'
    workflow2='yamls/proto_nd_flow/workflows/charge/charge_event_reconstruction_data.yaml'
    workflow3='yamls/proto_nd_flow/workflows/combined/combined_reconstruction_data.yaml'
    workflow4='yamls/proto_nd_flow/workflows/charge/prompt_calibration_data.yaml'
    workflow5='yamls/proto_nd_flow/workflows/charge/final_calibration_data.yaml'
    workflow6='yamls/proto_nd_flow/workflows/light/light_event_building_mpd_Run2.yaml' # help me?
    workflow7='yamls/proto_nd_flow/workflows/light/light_event_reconstruction_data.yaml'
    workflow8='yamls/proto_nd_flow/workflows/charge/charge_light_assoc_data.yaml'

fi

cd "$ND_PRODUCTION_INSTALL_DIR"/ndlar_flow

# Ensure that the second h5flow doesn't run if the first one crashes. This also
# ensures that we properly report the failure to the production system.
set -o errexit

#run h5flow -c $workflow1 $workflow2 $workflow3 $workflow4 $workflow5\
#    -i "$inFile" -o "$outFile" $compression

# Enable LZF compression of output file
inFile='/global/cfs/cdirs/dune/www/data/2x2/nearline_run2/packet/ColdOperations/data/2025_Operations_Cold/source/Rn_1120/packet-0060157-2025_11_24_07_34_59_CST.h5'
# inFile='/global/cfs/cdirs/dune/www/data/2x2/nearline_run2/flowed_light/source_rn_bin1/injection/mpd_run_data_rctl_776_p0.FLOW.hdf5'
inFile='/global/cfs/cdirs/dune/users/seschwar/rad_analysis/output/Bi212_test/Bi212_test_2.LARNDSIM.hdf5'
outFile='/global/cfs/cdirs/dune/users/seschwar/rad_analysis/mpd_run_data_rctl_776_p0_TEST.FLOW.hdf5'
outFile='/global/cfs/cdirs/dune/users/seschwar/rad_analysis/output/Bi212_test/Bi212_test_2.FLOW.hdf5'
opts="-z lzf"

run h5flow $opts -c $workflow1 $workflow2 $workflow3 $workflow4 $workflow5 \
    -i "$inFile" -o "$outFile" $compression

run h5flow $opts -c $workflow6 $workflow7\
# h5flow -c $workflow7\
#     -i "$inFile" -o "$outFile"

run h5flow $opts -c $workflow8\
    -i "$outFile" -o "$outFile" $compression

mkdir -p "$outDir/FLOW/$subDir"
mv "$outFile" "$outDir/FLOW/$subDir"