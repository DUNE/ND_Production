#!/usr/bin/env bash


#SBATCH --account=dune
#SBATCH --constraint=cpu
#SBATCH --qos=regular

#SBATCH --cpus-per-task=16
#SBATCH --ntasks-per-node=16
#SBATCH --nodes=4
#SBATCH --time=02:00:00

#SBATCH --job-name=MicroProdN4p1_NDComplex_FHC.flow.full.v2


logdir=${SCRATCH}/logs_slurm/${SLURM_JOB_NAME}/${SLURM_JOBID}
mkdir -p "$logdir"


export ND_PRODUCTION_PATH_TO_EXECUTABLE=/global/homes/a/abooth/dune/Production/development_repos/ND_Production/run-ndlar-flow/run_ndlar_flow_ndlar_withmerging_sbatch_manual.sh
export ND_PRODUCTION_START_INDEX=2459
export ND_PRODUCTION_END_INDEX=2559


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
