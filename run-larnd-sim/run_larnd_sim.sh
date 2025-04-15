#!/usr/bin/env bash

# By default (i.e. if ARCUBE_RUNTIME isn't set), run on the host's venv
source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

if [[ ( (-z "$ND_PRODUCTION_RUNTIME") || ("$ND_PRODUCTION_RUNTIME" == "NONE") )
      || ( (-n "$ND_PRODUCTION_USE_LOCAL_PRODUCT") && ("$ND_PRODUCTION_USE_LOCAL_PRODUCT" != "0") ) ]]; then
    # Allow overriding the container's /opt/venv
    source "$ND_PRODUCTION_INSTALL_DIR/larnd.venv/bin/activate"
fi

inDir=${ND_PRODUCTION_OUTDIR_BASE}/run-convert2h5/$ND_PRODUCTION_CONVERT2H5_NAME
inName=$ND_PRODUCTION_CONVERT2H5_NAME.$globalIdx
inFile=$(realpath $inDir/EDEPSIM_H5/$subDir/${inName}.EDEPSIM.hdf5)

outFile=$tmpOutDir/${outName}.LARNDSIM.hdf5
rm -f "$outFile"

cd "$ND_PRODUCTION_INSTALL_DIR"

if [[ -n "$ND_PRODUCTION_LARNDSIM_CONFIG" ]]; then
    run simulate_pixels.py "$ND_PRODUCTION_LARNDSIM_CONFIG" \
        --input_filename "$inFile" \
        --output_filename "$outFile" \
        --rand_seed "$seed"
else
    [ -z "$ND_PRODUCTION_LARNDSIM_DETECTOR_PROPERTIES" ] && export ND_PRODUCTION_LARNDSIM_DETECTOR_PROPERTIES="larnd-sim/larndsim/detector_properties/2x2.yaml"
    [ -z "$ND_PRODUCTION_LARNDSIM_PIXEL_LAYOUT" ] && export ND_PRODUCTION_LARNDSIM_PIXEL_LAYOUT="larnd-sim/larndsim/pixel_layouts/multi_tile_layout-2.4.16.yaml"
    [ -z "$ND_PRODUCTION_LARNDSIM_RESPONSE_FILE" ] && export ND_PRODUCTION_LARNDSIM_RESPONSE_FILE="larnd-sim/larndsim/bin/response_44.npy"
    [ -z "$ND_PRODUCTION_LARNDSIM_LUT_FILENAME" ] && export ND_PRODUCTION_LARNDSIM_LUT_FILENAME="/global/cfs/cdirs/dune/www/data/2x2/simulation/larndsim_data/light_LUT_M123_v1/lightLUT_M123.npz"
    [ -z "$ND_PRODUCTION_LARNDSIM_LIGHT_DET_NOISE_FILENAME" ] && export ND_PRODUCTION_LARNDSIM_LIGHT_DET_NOISE_FILENAME="larnd-sim/larndsim/bin/light_noise_2x2_4mod_July2023.npy"
    [ -z "$ND_PRODUCTION_LARNDSIM_SIMULATION_PROPERTIES" ] && export ND_PRODUCTION_LARNDSIM_SIMULATION_PROPERTIES="larnd-sim/larndsim/simulation_properties/2x2_NuMI_sim.yaml"

    run simulate_pixels.py --input_filename "$inFile" \
        --output_filename "$outFile" \
        --detector_properties "$ND_PRODUCTION_LARNDSIM_DETECTOR_PROPERTIES" \
        --pixel_layout "$ND_PRODUCTION_LARNDSIM_PIXEL_LAYOUT" \
        --response_file "$ND_PRODUCTION_LARNDSIM_RESPONSE_FILE" \
        --light_lut_filename  "$ND_PRODUCTION_LARNDSIM_LUT_FILENAME" \
        --light_det_noise_filename "$ND_PRODUCTION_LARNDSIM_LIGHT_DET_NOISE_FILENAME" \
        --rand_seed $seed \
        --simulation_properties "$ND_PRODUCTION_LARNDSIM_SIMULATION_PROPERTIES"
fi

mkdir -p "$outDir/LARNDSIM/$subDir"
mv "$outFile" "$outDir/LARNDSIM/$subDir"
