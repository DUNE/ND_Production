#!/usr/bin/env bash

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

source flow.venv/bin/activate
cd ndlar_flow

lightf=$ND_PRODUCTION_LIGHT_FILE
# split $ND_PRODUCTION_CHARGE_FILES into an array $chargefs
read -r -a chargefs <<< "$ND_PRODUCTION_CHARGE_FILES"

outf=$tmpOutDir/$subDir/$outName.FLOW.hdf5
mkdir -p "$tmpOutDir/$subDir"
rm -f "$outf"

h5flow="h5flow"

if [[ "$ND_PRODUCTION_COMPRESS" != "" ]]; then
    echo "Enabling compression of HDF5 datasets with $ND_PRODUCTION_COMPRESS"
    h5flow="$h5flow -z $ND_PRODUCTION_COMPRESS"
fi

get_range() {
    run ../helpers/get_charge_packet_range.py \
        --lightf "$outf" \
        --first-chargef "$(realpath "${chargefs[0]}")" \
        --last-chargef "$(realpath "${chargefs[-1]}")"
}

if [[ -n "$ND_PRODUCTION_RUN_BINARY2PACKET" ]]; then
    input_chargefs=()
    for chargef in "${chargefs[@]}"; do
        packet_chargef=$tmpOutDir/$subDir/$outName.$(basename "$chargef").PACKET.hdf5
        rm -f "$packet_chargef"
        read -ra args <<< "$ND_PRODUCTION_BINARY2PACKET_ARGS"
        run convert_rawhdf5_to_hdf5.py "${args[@]}" \
            --input_filename  "$chargef" --output_filename "$packet_chargef"
        input_chargefs+=("$packet_chargef")
    done
else
    input_chargefs=("${chargefs[@]}")
fi

read -ra workflows_evb <<< "$ND_PRODUCTION_LIGHT_EVTBUILD_WORKFLOWS"
read -ra workflows_reco <<< "$ND_PRODUCTION_LIGHT_EVTBUILD_WORKFLOWS"
workflows=("${workflows_evb[@]}" "${workflows_reco[@]}")
run $h5flow -i "$lightf" -o "$outf" -c "${workflows[@]}"

if [[ -n "${input_chargefs[*]}" ]]; then
    read -r -a pkt_range <<< "$(get_range)"

    for chargef in "${input_chargefs[@]}"; do
        if [[ "$chargef" == "${chargefs[0]}" ]]; then
            extra_args+=("--start_position" "${pkt_range[0]}")
        fi
        if [[ "$chargef" == "${chargefs[-1]}" ]]; then
            extra_args+=("--end_position" "${pkt_range[1]}")
        fi

        read -ra workflows <<< "$ND_PRODUCTION_CHARGE_EVTBUILD_WORKFLOWS"
        run $h5flow -i "$chargef" -o "$outf" -c "${workflows[@]}" "${extra_args[@]}"
    done

    read -ra workflows_reco <<< "$ND_PRODUCTION_CHARGE_RECO_WORKFLOWS"
    read -ra workflows_match <<< "$ND_PRODUCTION_CHARGE_CLMATCH_WORKFLOWS"
    workflows=("${workflows_reco[@]}" "${workflows_match[@]}")
    run $h5flow -i "$outf" -o "$outf" -c "${workflows[@]}"
fi

if [[ -n "$ND_PRODUCTION_RUN_BINARY2PACKET" ]]; then
    rm -f "${input_chargefs[@]}"
fi

mkdir -p "$outDir/FLOW/$subDir"
mv "$outf" "$outDir/FLOW/$subDir"
