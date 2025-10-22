#!/usr/bin/env bash


#SBATCH --account=dune
#SBATCH --constraint=cpu
#SBATCH --qos=regular

#SBATCH --cpus-per-task=8
#SBATCH --ntasks-per-node=32
#SBATCH --nodes=28
#SBATCH --time=01:00:00

#SBATCH --job-name=MicroProdN3p4_NDLAr_2E18_FHC.flow.geomfix.singles.nu.v251016


logdir=${SCRATCH}/logs_slurm/${SLURM_JOB_NAME}/${SLURM_JOBID}
mkdir -p "$logdir"


export ND_PRODUCTION_PATH_TO_EXECUTABLE=/global/homes/a/abooth/dune/Production/development_repos/ND_Production/run-ndlar-flow/run_ndlar_flow_ndlar_withmerging_nolight_sbatch_manual.sh
export ND_PRODUCTION_START_INDEX=1
export ND_PRODUCTION_END_INDEX=4480


srun -o "$logdir"/output-%j.%t.txt --kill-on-bad-exit=0 bash -lc '
  cd `dirname $ND_PRODUCTION_PATH_TO_EXECUTABLE`

  # Global identifiers for this task
  rank=${SLURM_PROCID:?}
  ntasks=${SLURM_NTASKS:?}

  for ((idx=ND_PRODUCTION_START_INDEX+rank; idx<=ND_PRODUCTION_END_INDEX; idx+=ntasks)); do
    export ND_PRODUCTION_INDEX=$idx
    $ND_PRODUCTION_PATH_TO_EXECUTABLE
  done
'
