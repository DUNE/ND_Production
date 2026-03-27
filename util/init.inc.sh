#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/prelude.inc.sh"

# NOTE: We assume that this script is "sourced" from e.g.
# run-edep-sim/run_edep_sim.sh and that the current working directory is e.g.
# run-edep-sim. Parent dir should be root of ND_Production
# The root of ND_Production:
baseDir=$(realpath "$PWD"/..)

isMC=$([[ -n $ND_PRODUCTION_INDEX ]] && echo 1)

# Start seeds at 1 instead of 0, just in case GENIE does something
# weird when given zero (e.g. use the current time)
ND_PRODUCTION_INDEX=${ND_PRODUCTION_INDEX:-0}
seed=$((1 + ND_PRODUCTION_INDEX))
echo "Seed is $seed"

# NOTE: ND_PRODUCTION_INDEX is a "number" while globalIdx is the zero-padded string
# representation of that number. Don't do math with globalIdx! Bash may parse it
# as an octal number.

globalIdx=$(printf "%07d" "$ND_PRODUCTION_INDEX")
echo "globalIdx is $globalIdx"

runOffset=${ND_PRODUCTION_RUN_OFFSET:-0}
runNo=$((ND_PRODUCTION_INDEX + runOffset))
echo "runNo is $runNo"

# Default to the root of the ND_Production directory (but ideally this should be set to
# somewhere on $SCRATCH)
ND_PRODUCTION_OUTDIR_BASE="${ND_PRODUCTION_OUTDIR_BASE:-$PWD/..}"
mkdir -p "$ND_PRODUCTION_OUTDIR_BASE"
ND_PRODUCTION_OUTDIR_BASE=$(realpath "$ND_PRODUCTION_OUTDIR_BASE")
export ND_PRODUCTION_OUTDIR_BASE

ND_PRODUCTION_LOGDIR_BASE="${ND_PRODUCTION_LOGDIR_BASE:-$PWD/..}"
mkdir -p "$ND_PRODUCTION_LOGDIR_BASE"
ND_PRODUCTION_LOGDIR_BASE=$(realpath "$ND_PRODUCTION_LOGDIR_BASE")
export ND_PRODUCTION_LOGDIR_BASE

# For "local" (i.e. non-container, non-CVMFS) installs of dune-tms etc.
export ND_PRODUCTION_INSTALL_DIR=${ND_PRODUCTION_INSTALL_DIR:-$PWD}

stepname=$(basename "$PWD")

if [[ -n $isMC ]]; then
    subDir=$(printf "%07d" $((ND_PRODUCTION_INDEX / 1000 * 1000)))
else
    export ND_PRODUCTION_DATA_FILE=$ND_PRODUCTION_CHARGE_FILE
    [[ -z $ND_PRODUCTION_DATA_FILE ]] && export ND_PRODUCTION_DATA_FILE=$ND_PRODUCTION_LIGHT_FILE
    if [[ -z $ND_PRODUCTION_DATA_FILE ]]; then
        echo "Please set either ND_PRODUCTION_INDEX (for MC) or ND_PRODUCTION_CHARGE_FILE or ND_PRODUCTION_LIGHT_FILE (for data)"
        exit 1
    fi
    subDir=${ND_PRODUCTION_DATA_FILE##"$ND_PRODUCTION_INDIR_BASE"}
fi

outDir=$ND_PRODUCTION_OUTDIR_BASE/${stepname}/$ND_PRODUCTION_OUT_NAME
echo "outDir is $outDir"
mkdir -p "$outDir"

if [[ -n $isMC ]]; then
    outName=$ND_PRODUCTION_OUT_NAME.$globalIdx
    inName=$ND_PRODUCTION_IN_NAME.$globalIdx
else
    dataExt=${ND_PRODUCTION_DATA_FILE##*.}
    fileId=$(basename "$ND_PRODUCTION_DATA_FILE" ".$dataExt")
    outName=$ND_PRODUCTION_OUT_NAME.$fileId
    inName=$ND_PRODUCTION_IN_NAME.$fileId
fi

echo "outName is $outName"

tmpOutDir=$ND_PRODUCTION_OUTDIR_BASE/tmp/$stepname/$ND_PRODUCTION_OUT_NAME
mkdir -p "$tmpOutDir"

logBase=$ND_PRODUCTION_LOGDIR_BASE/$stepname/$ND_PRODUCTION_OUT_NAME
echo "logBase is $logBase"
logDir=$logBase/LOGS/$subDir
timeDir=$logBase/TIMING/$subDir
mkdir -p "$logDir" "$timeDir"
logFile=$logDir/$outName.log
timeFile=$timeDir/$outName.time

timeProg=/usr/bin/time
# HACK in case we forget to include GNU time in a container
[[ ! -e "$timeProg" ]] && timeProg=$PWD/../tmp_bin/time

run() {
    echo RUNNING "$@" | tee -a "$logFile"
    time "$timeProg" --append -f "$1 %P %M %E" -o "$timeFile" "$@" 2>&1 | tee -a "$logFile"
}

libpath_remove() {
  LD_LIBRARY_PATH=":$LD_LIBRARY_PATH:"
  LD_LIBRARY_PATH=${LD_LIBRARY_PATH//":"/"::"}
  LD_LIBRARY_PATH=${LD_LIBRARY_PATH//":$1:"/}
  LD_LIBRARY_PATH=${LD_LIBRARY_PATH//"::"/":"}
  LD_LIBRARY_PATH=${LD_LIBRARY_PATH#:}; LD_LIBRARY_PATH=${LD_LIBRARY_PATH%:}
}

# Tell the HDF5 library not to lock files, since that sometimes fails on Perlmutter
export HDF5_USE_FILE_LOCKING=FALSE

# Fail as soon as something bad happens
set -o errexit
set -o pipefail
