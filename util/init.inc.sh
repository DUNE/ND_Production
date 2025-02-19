#!/usr/bin/env bash

set -o errexit
set -o pipefail

# NOTE: We assume that this script is "sourced" from e.g.
# run-edep-sim/run_edep_sim.sh and that the current working directory is e.g.
# run-edep-sim. Parent dir should be root of 2x2_sim.

# The root of 2x2_sim:
baseDir=$(realpath "$PWD"/..)

# Start seeds at 1 instead of 0, just in case GENIE does something
# weird when given zero (e.g. use the current time)
# NOTE: We just use the fixed Edep default seed of ???.
seed=$((1 + ARCUBE_INDEX))
echo "Seed is $seed"

# NOTE: ARCUBE_INDEX is a "number" while globalIdx is the zero-padded string
# representation of that number. Don't do math with globalIdx! Bash may parse it
# as an octal number.

globalIdx=$(printf "%07d" "$ARCUBE_INDEX")
echo "globalIdx is $globalIdx"

runOffset=${ARCUBE_RUN_OFFSET:-0}
runNo=$((ARCUBE_INDEX + runOffset))
echo "runNo is $runNo"

# Default to the root of the 2x2_sim repo (but ideally this should be set to
# somewhere on $SCRATCH)
ARCUBE_OUTDIR_BASE="${ARCUBE_OUTDIR_BASE:-$PWD/..}"
mkdir -p "$ARCUBE_OUTDIR_BASE"
ARCUBE_OUTDIR_BASE=$(realpath "$ARCUBE_OUTDIR_BASE")
export ARCUBE_OUTDIR_BASE

ARCUBE_LOGDIR_BASE="${ARCUBE_LOGDIR_BASE:-$PWD/..}"
mkdir -p "$ARCUBE_LOGDIR_BASE"
ARCUBE_LOGDIR_BASE=$(realpath "$ARCUBE_LOGDIR_BASE")
export ARCUBE_LOGDIR_BASE

# For "local" (i.e. non-container, non-CVMFS) installs of larnd-sim etc.
# Default to run-larnd-sim etc.
export ARCUBE_INSTALL_DIR=${ARCUBE_INSTALL_DIR:-$PWD}

stepname=$(basename "$PWD")

outDir=$ARCUBE_OUTDIR_BASE/${stepname}/$ARCUBE_OUT_NAME
echo "outDir is $outDir"
outName=$ARCUBE_OUT_NAME.$globalIdx
echo "outName is $outName"
mkdir -p "$outDir"

tmpOutDir=$ARCUBE_OUTDIR_BASE/tmp/$stepname/$ARCUBE_OUT_NAME
mkdir -p "$tmpOutDir"

subDir=$(printf "%07d" $((ARCUBE_INDEX / 1000 * 1000)))

logBase=$ARCUBE_LOGDIR_BASE/$stepname/$ARCUBE_OUT_NAME
echo "logBase is $logBase"
logDir=$logBase/LOGS/$subDir
timeDir=$logBase/TIMING/$subDir
mkdir -p "$logDir" "$timeDir"
logFile=$logDir/$outName.log
timeFile=$timeDir/$outName.time

# to download time I need to download wget, if not already present,
if [ ! $(command -v wget) ]; then
  yum install -y wget
fi

# if GNU time is already present in /usr/tmp
timeProg=time
# if not present there, we include the one present in /PWD/tmp_bin
# HACK in case we forget to include GNU time in a container
[[ ! -e "$timeProg" ]] && timeProg=$ND_PRODUCTION/tmp_bin/time

# if time is not installed, then install in this way
if [ ! -e "$timeProg" ]; then
  TMP_BIN="$ND_PRODUCTION/tmp_bin"

  if [ ! -d "$TMP_BIN" ]; then
      mkdir - p "$TMP_BIN" || { echo "Failed to create $TMP_BIN"; exit 1; }
  fi

  echo "pwd is $PWD"
  echo "ND_Production is $ND_PRODUCTION"

  # if [ -z "$TWOBYTWO_SIM" ]; then
  #   echo "Error: TWOBYTWO_SIM is not set" 
  #   exit 1
  # fi
  
  cd "$ND_PRODUCTION/tmp_bin" # || { echo "Failed to cd into $ND_PRODUCTION/tmp_bin"; exit 1; }

  wget -q https://portal.nersc.gov/project/dune/data/2x2/people/mkramer/bin/time || {
    echo "Download failed"
    exit 1
    } 
    timeProg=$ND_PRODUCTION/tmp_bin/time

    if [ ! -x $timeProg ]; then
      chmod +x "$timeProg"
    fi
fi

echo "pwd after tmp_bin is $PWD"
cd $PWD
echo "************pwd after second cd is $PWD"

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
