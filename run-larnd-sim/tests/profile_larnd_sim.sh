#!/usr/bin/env bash

# NOTE: Run me from the parent directory (run-larnd-sim)
# $ tests/profile_larnd_sim.sh

module load cudatoolkit/11.7
module load Nsight-Systems/2022.2.1
module load python/3.11

export ND_PRODUCTION_INDEX=124
export ND_PRODUCTION_OUTDIR_BASE=/pscratch/sd/m/mkramer/out.MiniRun5
export ND_PRODUCTION_LOGDIR_BASE=$SCRATCH/logs/MiniRun5
export ND_PRODUCTION_CONVERT2H5_NAME=MiniRun5_1E19_RHC.convert2h5
export ND_PRODUCTION_OUT_NAME=MiniRun5_1E19_RHC.larnd.test123
export ND_PRODUCTION_LARNDSIM_CONFIG=2x2_mod2mod_variation

source ../util/init.inc.sh
source "$ND_PRODUCTION_INSTALL_DIR/larnd.venv/bin/activate"

inDir=${ND_PRODUCTION_OUTDIR_BASE}/run-convert2h5/output/$ND_PRODUCTION_CONVERT2H5_NAME
inName=$ND_PRODUCTION_CONVERT2H5_NAME.$globalIdx
inFile=$(realpath $inDir/EDEPSIM_H5/${inName}.EDEPSIM.hdf5)

outFile=$tmpOutDir/${outName}.LARNDSIM.hdf5
rm -f "$outFile"

tmpDir=$(mktemp -d)
cd "$tmpDir"

set +o errexit                  # in case it crashes

# run nsys profile --cuda-memory-usage=true simulate_pixels.py "$ND_PRODUCTION_LARNDSIM_CONFIG" \
run nsys profile -t nvtx,cuda --cuda-memory-usage=true simulate_pixels.py "$ND_PRODUCTION_LARNDSIM_CONFIG" \
    --input_filename "$inFile" \
    --output_filename "$outFile" \
    --rand_seed "$seed"

mkdir -p "$logBase/PROFILE"
mv report1.nsys-rep "$logBase/PROFILE/$outName.PROFILE.nsys-rep"

echo "Output to $logBase/PROFILE/$outName.PROFILE.nsys-rep"

rmdir "$tmpDir"
