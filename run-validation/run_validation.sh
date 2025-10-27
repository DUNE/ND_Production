#!/usr/bin/env bash

set -o errexit

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-mjkramer/sim2x2:ndlar011}

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

if [[ "$ND_PRODUCTION_RUNTIME" == "NONE" ]]; then
    module load python/3.11
    source validation.venv/bin/activate
fi

edepDir=${ND_PRODUCTION_OUTDIR_BASE}/run-convert2h5/${ND_PRODUCTION_EDEP_NAME}/EDEPSIM_H5/$subDir
larndDir=${ND_PRODUCTION_OUTDIR_BASE}/run-larnd-sim/${ND_PRODUCTION_LARND_NAME}/LARNDSIM/$subDir
flowDir=${ND_PRODUCTION_OUTDIR_BASE}/run-ndlar-flow/${ND_PRODUCTION_FLOW_NAME}/FLOW/$subDir

edepFile=$edepDir/${ND_PRODUCTION_EDEP_NAME}.${globalIdx}.EDEPSIM.hdf5
larndFile=$larndDir/${ND_PRODUCTION_LARND_NAME}.${globalIdx}.LARNDSIM.hdf5
flowFile=$flowDir/${ND_PRODUCTION_FLOW_NAME}.${globalIdx}.FLOW.hdf5

codeDir=$PWD

plotOutDir=$outDir/PLOTS
mkdir -p "$plotOutDir"
cd "$plotOutDir"

run_in() {
    direc=$1/$subDir; shift
    mkdir -p "$direc"
    pushd "$direc"
    run "$@"
    popd
}

# If ND_PRODUCTION_PLOT_TYPE isn't set, run everything.

if [[ -z "$ND_PRODUCTION_PLOT_TYPE" || "$ND_PRODUCTION_PLOT_TYPE" == "EDEPSIM_DUMPTREE" ]]; then
    run_in EDEPSIM_DUMPTREE "$codeDir"/edepsim_validation.py --sim_file "$edepFile" --input_type edep
fi
if [[ -z "$ND_PRODUCTION_PLOT_TYPE" || "$ND_PRODUCTION_PLOT_TYPE" == "LARNDSIM_EDEPTRUTH" ]]; then
    run_in LARNDSIM_EDEPTRUTH "$codeDir"/edepsim_validation.py --sim_file "$larndFile" --input_type larnd
fi
if [[ -z "$ND_PRODUCTION_PLOT_TYPE" || "$ND_PRODUCTION_PLOT_TYPE" == "LARNDSIM" ]]; then
    run_in LARNDSIM "$codeDir"/larndsim_validation.py --sim_file "$larndFile"
fi
if [[ -z "$ND_PRODUCTION_PLOT_TYPE" || "$ND_PRODUCTION_PLOT_TYPE" == "FLOW" ]]; then
    run_in FLOW "$codeDir"/flow_validation.py --flow_file "$flowFile"
fi
if [[ -z "$ND_PRODUCTION_PLOT_TYPE" || "$ND_PRODUCTION_PLOT_TYPE" == "FLOW_CPM" ]]; then
    run_in FLOW_CPM "$codeDir"/CPM_validation.py --flow_file "$flowFile"
fi
