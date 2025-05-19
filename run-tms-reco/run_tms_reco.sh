#!/usr/bin/env bash


source ../util/reload_in_container.inc.sh

# Setup environment.
setup() {
  source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh 

  setup edepsim v3_2_0 -f Linux64bit+3.10-2.17 -q e20:prof 

  export TMS_DIR=${PWD}/dune-tms

  export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${TMS_DIR}/lib
  export PATH=${PATH}:${TMS_DIR}/bin
}

###################################################################################

set +o errexit
setup
set -o errexit

# Must go after setup.
source ../util/init.inc.sh


inDir=${ND_PRODUCTION_OUTDIR_BASE}/run-spill-build/$ND_PRODUCTION_SPILL_NAME
inName=$ND_PRODUCTION_SPILL_NAME.$globalIdx
inFile=$(realpath $inDir/EDEPSIM_SPILLS/$subDir/${inName}.EDEPSIM_SPILLS.root)

# TMS_TreeWriter is looking for ND_PRODUCTION_TMSRECO_OUTFILE being
# set. TMS_ReadoutTreeWriter is looking for ND_PRODUCTION_TMSRECOREADOUT_OUTFILE
# being set.
outFileReco=$tmpOutDir/${outName}.TMSRECO.root
outFileRecoReadout=$tmpOutDir/${outName}.TMSRECOREADOUT.root
export ND_PRODUCTION_TMSRECO_OUTFILE="$outFileReco"
export ND_PRODUCTION_TMSRECOREADOUT_OUTFILE="$outFileRecoReadout"
rm -f $ND_PRODUCTION_TMSRECO_OUTFILE $ND_PRODUCTION_TMSRECOREADOUT_OUTFILE
echo "outFiles are:"
echo "  ${ND_PRODUCTION_TMSRECO_OUTFILE}"
echo "and"
echo "  ${ND_PRODUCTION_TMSRECOREADOUT_OUTFILE}"


run ${PWD}/dune-tms/bin/ConvertToTMSTree.exe "$inFile"


tmsRecoOutDir=$outDir/TMSRECO/$subDir
tmsRecoReadoutOutDir=$outDir/TMSRECOREADOUT/$subDir
mkdir -p "$tmsRecoOutDir" "$tmsRecoReadoutOutDir"
mv "$ND_PRODUCTION_TMSRECO_OUTFILE" "$tmsRecoOutDir"
mv "$ND_PRODUCTION_TMSRECOREADOUT_OUTFILE" "$tmsRecoReadoutOutDir"
