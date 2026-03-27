#!/usr/bin/env bash

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

source flow.venv/bin/activate
cd ndlar_flow

chargef=$ND_PRODUCTION_CHARGE_FILE
# split $ND_PRODUCTION_LIGHT_FILES into an array $lightfs
read -r -a lightfs <<< "$ND_PRODUCTION_LIGHT_FILES"

outf=$tmpOutDir/$subDir/$outName.FLOW.hdf5
mkdir -p "$tmpOutDir/$subDir"
rm -f "$outf"

if [[ -n "$ND_PRODUCTION_RUN_BINARY2PACKET" ]]; then
    input_chargef=$tmpOutDir/$subDir/$outName.PACKET.hdf5
    rm -f "$input_chargef"
    convert_rawhdf5_to_hdf5.py --direct --input_filename  "$chargef" --output_filename "$input_chargef"
else
    input_chargef=$chargef
fi

h5flow="h5flow"

if [[ "$ND_PRODUCTION_COMPRESS" != "" ]]; then
    echo "Enabling compression of HDF5 datasets with $ND_PRODUCTION_COMPRESS"
    h5flow="$h5flow -z $ND_PRODUCTION_COMPRESS"
fi

get_range() {
    ../../scripts/get_light_event_range.py \
        --workflow "$workflow_light_event_build" \
        --chargef "$input_chargef" \
        --first-lightf "$(realpath "${lightfs[0]}")" \
        --last-lightf "$(realpath "${lightfs[-1]}")" \
        --tmpdir "$tmpOutDir"
}

if [[ -n "${lightfs[*]}" ]]; then
    read -r -a evt_range <<< "$(get_range)"

    for lightf in "${lightfs[@]}"; do
       extra_args=()
       if [[ "$lightf" == "${lightfs[0]}" ]]; then
           extra_args+=("--start_position" "${evt_range[0]}")
       fi
       if [[ "$lightf" == "${lightfs[-1]}" ]]; then
           extra_args+=("--end_position" "${evt_range[1]}")
       fi

       workflows=$ND_PRODUCTION_LIGHT_EVTBUILD_WORKFLOWS
       # DO NOT QUOTE THE workflows ARRAY; we want it to be split
       $h5flow -i "$(realpath "$lightf")" -o "$outf" -c ${workflows[@]} "${extra_args[@]}"
    done

    if [[ -n "$ND_PRODUCTION_LIGHT_RECO_WORKFLOWS" ]]; then
        workflows=$ND_PRODUCTION_LIGHT_RECO_WORKFLOWS
        # DO NOT QUOTE THE workflows ARRAY; we want it to be split
        $h5flow -i "$outf" -o "$outf" -c ${workflows[@]}
    fi
fi

workflows="$ND_PRODUCTION_CHARGE_EVTBUILD_WORKFLOWS $ND_PRODUCTION_CHARGE_RECO_WORKFLOWS"
# DO NOT QUOTE THE workflows ARRAY; we want it to be split
$h5flow -i "$input_chargef" -o "$outf" -c ${workflows[@]}

if [[ -n "$ND_PRODUCTION_RUN_BINARY2PACKET" ]]; then
    rm "$input_chargef"
fi

if [[ -n "${lightfs[*]}" ]]; then
    workflows=$ND_PRODUCTION_CLMATCH_WORKFLOWS
    # DO NOT QUOTE THE workflows ARRAY; we want it to be split
    $h5flow -i "$outf" -o "$outf" -c ${workflows[@]}
fi

mkdir -p "$outDir/FLOW/$subDir"
mv "$outf" "$outDir/FLOW/$subDir"
