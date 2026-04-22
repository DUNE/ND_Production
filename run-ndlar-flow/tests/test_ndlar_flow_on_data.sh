#!/usr/bin/env bash

# Test "charge basis" with 2x2 Run 1 data

export ND_PRODUCTION_FILE_BASIS="charge"
export ND_PRODUCTION_CHARGE_EVB_WORKFLOWS="yamls/proto_nd_flow/workflows/charge/charge_event_building_data.yaml"
export ND_PRODUCTION_CHARGE_RECO_WORKFLOWS="yamls/proto_nd_flow/workflows/charge/charge_event_reconstruction_data.yaml yamls/proto_nd_flow/workflows/combined/combined_reconstruction_data.yaml yamls/proto_nd_flow/workflows/charge/prompt_calibration_data.yaml yamls/proto_nd_flow/workflows/charge/final_calibration_data.yaml"
export ND_PRODUCTION_LIGHT_EVB_WORKFLOWS="yamls/proto_nd_flow/workflows/light/light_event_building_mpd.yaml"
export ND_PRODUCTION_LIGHT_RECO_WORKFLOWS="yamls/proto_nd_flow/workflows/light/light_event_reconstruction_data.yaml"
export ND_PRODUCTION_CLMATCH_WORKFLOWS="yamls/proto_nd_flow/workflows/charge/charge_light_assoc_data.yaml"
export ND_PRODUCTION_CHARGE_FILES="/dvs_ro/cfs/cdirs/dune/www/data/2x2/nearline/packet/beam/july8_2024/nominal_hv/packet-0050017-2024_07_09_01_04_39_CDT.h5"
export ND_PRODUCTION_LIGHT_FILES="/dvs_ro/cfs/cdirs/dune/www/data/2x2/LRS/data_bin003/mpd_run_hvramp_rctl_104_p136.data /dvs_ro/cfs/cdirs/dune/www/data/2x2/LRS/data_bin003/mpd_run_hvramp_rctl_104_p137.data"

./run_ndlar_flow.data.sh


# Test "light basis" with 2x2 Run 2 data

export ND_PRODUCTION_FILE_BASIS="light"
export ND_PRODUCTION_CHARGE_EVB_WORKFLOWS="yamls/proto_nd_flow/workflows/charge/charge_event_building_data_Run2.yaml"
export ND_PRODUCTION_CHARGE_RECO_WORKFLOWS="yamls/proto_nd_flow/workflows/charge/charge_event_reconstruction_data_Run2.yaml yamls/proto_nd_flow/workflows/combined/combined_reconstruction_data.yaml yamls/proto_nd_flow/workflows/charge/prompt_calibration_data_Run2.yaml yamls/proto_nd_flow/workflows/charge/final_calibration_data_Run2.yaml"
export ND_PRODUCTION_LIGHT_EVB_WORKFLOWS="yamls/proto_nd_flow/workflows/light/light_event_building_mpd_Run2.yaml"
export ND_PRODUCTION_LIGHT_RECO_WORKFLOWS="yamls/proto_nd_flow/workflows/light/light_event_reconstruction_data.yaml"
export ND_PRODUCTION_CLMATCH_WORKFLOWS="yamls/proto_nd_flow/workflows/charge/charge_light_assoc_data.yaml"
export ND_PRODUCTION_CHARGE_FILES="/dvs_ro/cfs/cdirs/dune/www/data/2x2/nearline_run2/packet/ColdOperations/data/2025_Operations_Cold/Commission/Cosmics_1209/packet-0060170-2025_12_11_09_26_51_CST.h5 /dvs_ro/cfs/cdirs/dune/www/data/2x2/nearline_run2/packet/ColdOperations/data/2025_Operations_Cold/Commission/Cosmics_1209/packet-0060170-2025_12_11_09_41_52_CST.h5"
export ND_PRODUCTION_LIGHT_FILES="/dvs_ro/cfs/cdirs/dune/www/data/2x2/LRS_run2/cosmics_bin14/mpd_run_data_rctl_950_p521.data"

./run_ndlar_flow.data.sh
