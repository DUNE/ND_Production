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


#SBATCH --account=dune
#SBATCH --constraint=cpu
#SBATCH --qos=regular

#SBATCH --cpus-per-task=8
#SBATCH --ntasks-per-node=32
#SBATCH --nodes=7
#SBATCH --time=01:00:00

#SBATCH --job-name=MicroProdN3p4_NDLAr_2E18_FHC.flow.geomfix.singles.nu.v251016


logdir=${SCRATCH}/logs_slurm/${SLURM_JOB_NAME}/${SLURM_JOBID}
mkdir -p "$logdir"


export ND_PRODUCTION_PATH_TO_EXECUTABLE=/global/homes/a/abooth/dune/Production/development_repos/ND_Production/run-ndlar-flow/run_ndlar_flow_ndlar_withmerging_nolight_sbatch_manual.sh
export ND_PRODUCTION_START_INDEX=1
export ND_PRODUCTION_END_INDEX=1120


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
