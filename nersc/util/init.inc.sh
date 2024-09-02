#!/usr/bin/env bash

set -o errexit
set -o pipefail

# NOTE: We assume that this script is "sourced" from e.g.
# run-tms-reco/run_tms_reco.sh and that the current working directory is e.g.
# run-tms-reco. Parent dir should be root of ND_Production/nersc.

# The root of ND_Production/nersc:
baseDir=$(realpath "$PWD"/..)

# Start seeds at 1 instead of 0, just in case GENIE does something
# weird when given zero (e.g. use the current time)
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

# Default to the root of the ND_Production/nersc directoy (but ideally this should be set to
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
# Default to run-tms-reco etc.
export ND_PRODUCTION_INSTALL_DIR=${ND_PRODUCTION_INSTALL_DIR:-$PWD}

stepname=$(basename "$PWD")

outDir=$ND_PRODUCTION_OUTDIR_BASE/${stepname}/$ND_PRODUCTION_OUT_NAME
echo "outDir is $outDir"
outName=$ND_PRODUCTION_OUT_NAME.$globalIdx
echo "outName is $outName"
mkdir -p "$outDir"

tmpOutDir=$ND_PRODUCTION_OUTDIR_BASE/tmp/$stepname/$ND_PRODUCTION_OUT_NAME
mkdir -p "$tmpOutDir"

subDir=$(printf "%07d" $((ND_PRODUCTION_INDEX / 1000 * 1000)))

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
