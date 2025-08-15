#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/prelude.inc.sh"

# NOTE: We assume that this script is "sourced" from e.g.
# run-edep-sim/run_edep_sim.sh and that the current working directory is e.g.
# run-edep-sim. Parent dir should be root of 2x2_sim.

# Default to the root of the 2x2_sim repo (but ideally this should be set to
# somewhere on $SCRATCH)
ND_PRODUCTION_OUTDIR_BASE="${ND_PRODUCTION_OUTDIR_BASE:-$PWD/..}"
mkdir -p "$ND_PRODUCTION_OUTDIR_BASE"
ND_PRODUCTION_OUTDIR_BASE=$(realpath "$ND_PRODUCTION_OUTDIR_BASE")
export ND_PRODUCTION_OUTDIR_BASE

ND_PRODUCTION_LOGDIR_BASE="${ND_PRODUCTION_LOGDIR_BASE:-$PWD/..}"
mkdir -p "$ND_PRODUCTION_LOGDIR_BASE"
ND_PRODUCTION_LOGDIR_BASE=$(realpath "$ND_PRODUCTION_LOGDIR_BASE")
export ND_PRODUCTION_LOGDIR_BASE

# For "local" (i.e. non-container, non-CVMFS) installs of larnd-sim etc.
# Default to run-larnd-sim etc.
export ND_PRODUCTION_INSTALL_DIR=${ND_PRODUCTION_INSTALL_DIR:-$PWD}

inName=$(basename "$ND_PRODUCTION_CHARGE_FILE")
relDir=$(dirname ${ND_PRODUCTION_CHARGE_FILE#"$ND_PRODUCTION_INDIR_BASE"})

outDir=$ND_PRODUCTION_OUTDIR_BASE/$relDir
mkdir -p "$outDir"

tmpOutDir=$ND_PRODUCTION_OUTDIR_BASE/tmp/$relDir
mkdir -p "$tmpOutDir"

logBase=$ND_PRODUCTION_LOGDIR_BASE
echo "logBase is $logBase"
logDir=$logBase/LOGS/$relDir
timeDir=$logBase/TIMING/$relDir
mkdir -p "$logDir" "$timeDir"
logFile=$logDir/$inName.log
timeFile=$timeDir/$inName.time

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
