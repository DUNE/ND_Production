#!/usr/bin/env bash

################################################################################
#
# A wrapper script that can be passed to sbatch (with an example configuration)
# to execute the run_*.sh style scripts in ND_Production. The user should
# change ND_PRODUCTION_PATH_TO_EXECUTABLE, ND_PRODUCTION_START_INDEX,
# ND_PRODUCTION_END_INDEX and the sbatch directives. They should also explicitly 
# export the env vars, usually defined in a stage's specs, at the top of 
# ND_PRODUCTION_PATH_TO_EXECUTABLE. An example of that can be found at:
#
# https://github.com/DUNE/ND_Production/blob/feature/abooth-pandora_hit_merging/run-ndlar-flow/run_ndlar_flow_ndlar_withmerging_sbatch_manual.sh
#
################################################################################


#SBATCH --account=m3249
#SBATCH --constraint=gpu&hbm80g
#SBATCH --qos=regular

#SBATCH --cpus-per-task=32
#SBATCH --gpus-per-task=1
#SBATCH --ntasks-per-node=4
#SBATCH --nodes=1
#SBATCH --time=04:00:00

#SBATCH --job-name=MiniProdN5p1_NDComplex_FHC.larnd.full.sanddrift


logdir=${SCRATCH}/logs_slurm/${SLURM_JOB_NAME}/${SLURM_JOBID}
mkdir -p "$logdir"


export ND_PRODUCTION_PATH_TO_EXECUTABLE=/pscratch/sd/d/dunepro/esabater/install/ND_Production/run-larnd-sim/run_larnd_sim_sbatch_manual.sh
export ND_PRODUCTION_START_INDEX=1
export ND_PRODUCTION_END_INDEX=200


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
