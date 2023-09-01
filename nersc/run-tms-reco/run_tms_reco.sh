#!/usr/bin/env bash


###################################################################################
## Define some useful functions.

# Recording job metics using time.
run() {
    echo RUNNING "$@"
    time "$timeProg" --append -f "$1 %P %M %E" -o "$timeFile" "$@"
}

# Setup environment.
setup() {
  source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh 

  setup edepsim v3_2_0 -f Linux64bit+3.10-2.17 -q e20:prof 

  export TMS_DIR=${PWD}/dune-tms

  export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${TMS_DIR}/lib
  export PATH=${PATH}:${TMS_DIR}/bin
}

###################################################################################


# Reload Shifter if necessary.
if [[ "$SHIFTER_IMAGEREQUEST" != "$ND_PRODUCTION_CONTAINER" ]]; then
  shifter --image=$ND_PRODUCTION_CONTAINER --module=cvmfs -- "$0" "$@"
  exit
fi


setup


globalIdx=$ND_PRODUCTION_INDEX
echo "globalIdx is $globalIdx"


outDir=$PWD/output/$ND_PRODUCTION_OUT_NAME
[ ! -z "${ND_PRODUCTION_OUTDIR_BASE}" ] && outDir=$ND_PRODUCTION_OUTDIR_BASE/run-tms-reco/output/$ND_PRODUCTION_OUT_NAME
tmsRecoOutDir=$outDir/TMSRECO
mkdir -p $tmsRecoOutDir

inName=$ND_PRODUCTION_SPILL_NAME.$(printf "%05d" "$globalIdx")
inFile=$PWD/../../../2x2_sim/run-spill-build/output/${ND_PRODUCTION_SPILL_NAME}/EDEPSIM_SPILLS/${inName}.EDEPSIM_SPILLS.root
[ ! -z "${ND_PRODUCTION_OUTDIR_BASE}" ] && inFile=$ND_PRODUCTION_OUTDIR_BASE/run-spill-build/output/${ND_PRODUCTION_SPILL_NAME}/EDEPSIM_SPILLS/${inName}.EDEPSIM_SPILLS.root
echo "inFile is ${inFile}"

outName=$ND_PRODUCTION_OUT_NAME.$(printf "%05d" "$globalIdx")
outFile=$tmsRecoOutDir/${outName}.TMSRECO.root
rm -f "$outFile"
echo "outFile is ${outFile}"


timeFile=$outDir/TIMING/$outName.time
mkdir -p "$(dirname "$timeFile")"
timeProg=/usr/bin/time


run ConvertToTMSTree.exe $inFile

# TODO: some management of outfile naming here probably. Pending testing.

