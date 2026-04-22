#!/usr/bin/env bash

################################################################################
# PREAMBLE
################################################################################

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

source flow.venv/bin/activate
cd ndlar_flow

read -ra chargefs <<< "$ND_PRODUCTION_CHARGE_FILES"
read -ra lightfs <<< "$ND_PRODUCTION_LIGHT_FILES"

basis=$ND_PRODUCTION_FILE_BASIS

outf=$tmpOutDir/$subDir/$outName.FLOW.hdf5
mkdir -p "$tmpOutDir/$subDir"
rm -f "$outf"

flow_extra_args=()
if [[ -n "$ND_PRODUCTION_COMPRESS" ]]; then
    echo "Enabling compression of HDF5 datasets with $ND_PRODUCTION_COMPRESS"
    flow_extra_args+=("-z" "$ND_PRODUCTION_COMPRESS")
fi

run_flow() {
    run h5flow "${flow_extra_args[@]}" "$@"
}

################################################################################
# LARPIX BINARY-TO-PACKET CONVERSION
################################################################################

if [[ -n "$ND_PRODUCTION_RUN_BINARY2PACKET" ]]; then
    packet_chargefs=()
    for chargef in "${chargefs[@]}"; do
        packet_chargef_name=$outName.$(basename "$chargef").PACKET.hdf5
        packet_chargef=$tmpOutDir/$subDir/$packet_chargef_name
        rm -f "$packet_chargef"
        read -ra args <<< "$ND_PRODUCTION_BINARY2PACKET_ARGS"
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        run convert_rawhdf5_to_hdf5.py "${args[@]}" \
            --input_filename  "$chargef" --output_filename "$packet_chargef"
        packet_chargefs+=("$packet_chargef")
    done
else
    packet_chargefs=("${chargefs[@]}")
fi

################################################################################
# LIGHT EVENT BUILDING
################################################################################

get_light_event_range() {       # requires charge packet file
    run ../helpers/get_light_event_range.py \
        --workflow "$ND_PRODUCTION_LIGHT_EVB_WORKFLOWS" \
        --chargef "${packet_chargefs[0]}" \
        --first-lightf "$(realpath "${lightfs[0]}")" \
        --last-lightf "$(realpath "${lightfs[-1]}")" \
        --tmpdir "$tmpOutDir" \
        --output "$1"
}

if [[ ("$basis" == "charge") && (${#lightfs[@]} -gt 0) ]]; then
    rangefile=$(mktemp)
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    get_light_event_range "$rangefile"
    read -ra event_range < "$rangefile"
    rm "$rangefile"
fi

for lightf in "${lightfs[@]}"; do
    extra_args=()
    if [[ "$basis" == "charge" ]]; then
        if [[ "$lightf" == "${lightfs[0]}" ]]; then
           extra_args+=("--start_position" "${event_range[0]}")
        fi
        if [[ "$lightf" == "${lightfs[-1]}" ]]; then
           extra_args+=("--end_position" "${event_range[1]}")
        fi
    fi
    read -ra workflows <<< "$ND_PRODUCTION_LIGHT_EVB_WORKFLOWS"
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    run_flow "${extra_args[@]}" -i "$lightf" -o "$outf" -c "${workflows[@]}"
done

################################################################################
# LIGHT RECONSTRUCTION
################################################################################

if [[ "${#lightfs[@]}" -gt 0 ]]; then
    read -ra workflows <<< "$ND_PRODUCTION_LIGHT_RECO_WORKFLOWS"
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    run_flow -i "$outf" -o "$outf" -c "${workflows[@]}"
fi

################################################################################
# CHARGE EVENT BUILDING
################################################################################

get_charge_packet_range() {     # requires minimal light flow file
    run ../helpers/get_charge_packet_range.py \
        --lightf "$outf" \
        --first-chargef "$(realpath "${packet_chargefs[0]}")" \
        --last-chargef "$(realpath "${packet_chargefs[-1]}")" \
        --output "$1"
}

if [[ ("$basis" == "light") && (${#chargefs[@]} -gt 0) ]]; then
    rangefile=$(mktemp)
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    get_charge_packet_range "$rangefile"
    read -ra packet_range < "$rangefile"
    rm "$rangefile"
fi

for chargef in "${packet_chargefs[@]}"; do
    extra_args=()
    if [[ "$basis" == "light" ]]; then
        if [[ "$chargef" == "${packet_chargefs[0]}" ]]; then
            extra_args+=("--start_position" "${packet_range[0]}")
        fi
        if [[ "$chargef" == "${packet_chargefs[-1]}" ]]; then
            extra_args+=("--end_position" "${packet_range[1]}")
        fi
    fi
    # FIXME: flow's charge event builder can't append to an existing file
    read -ra workflows <<< "$ND_PRODUCTION_CHARGE_EVB_WORKFLOWS"
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    run_flow "${extra_args[@]}" -i "$chargef" -o "$outf" -c "${workflows[@]}"
done

################################################################################
# CHARGE RECONSTRUCTION
################################################################################

if [[ "${#chargefs[@]}" -gt 0 ]]; then
    read -ra workflows <<< "$ND_PRODUCTION_CHARGE_RECO_WORKFLOWS"
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    run_flow -i "$outf" -o "$outf" -c "${workflows[@]}"
fi

################################################################################
# CHARGE/LIGHT MATCHING
################################################################################

read -ra workflows <<< "$ND_PRODUCTION_CLMATCH_WORKFLOWS"
if [[ (${#workflows[@]} -gt 0)
            && (${#chargefs[@]} -gt 0) && (${#lightfs[@]} -gt 0) ]]; then
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    run_flow -i "$outf" -o "$outf" -c "${workflows[@]}"
fi

################################################################################
# WRAP-UP
################################################################################

if [[ -n "$ND_PRODUCTION_RUN_BINARY2PACKET" ]]; then
    rm -f "${packet_chargefs[@]}"
fi

mkdir -p "$outDir/FLOW/$subDir"
mv "$outf" "$outDir/FLOW/$subDir"
