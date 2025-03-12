# run_edep_sim.sh TUTORIAL

## Container
sim2x2:ndlar011

With these versions:

• GENIE 3.04.00 

• ROOT 6.28.06

## Configuration
Configure all the variables needed during the execution modifying the script `setup-edepsim.sh`. It will be very similar to `setup-genie.sh`
1. Set up your working directory, initializing `BASE_DIR` and `ND_PRODUCTION` (or the name of the folder of this repo)
2. Set up container info:
   - `ARCUBE_CONTAINER` with container name
   - `ARCUBE_RUNTIME` with container run time (Apptainer for CNAF users)
   - `ARCUBE_CONTAINER_DIR` with the directory where you pulled the container (pulled using the script in `/admin` called `pull_singularity_container.sh`)
   - `ARCUBE_DIR` with the path of the directory that you bind with your container
3. Set up output folders:
   - `ARCUBE_OUTDIR_BASE` with the name of the folder where your productions will be stored
   - `ARCUBE_LOGDIR_BASE` with the name of the folder where your logs will be stored
   - `ARCUBE_OUT_NAME` with the name of the produced files
   - `ARCUBE_GENIE_NAME` with the name of the files produced by genie
4. Set up variables for EDEPSIM (`edep-sim` command):
   - `ARCUBE_GEOM_EDEP` with .gdml file (for SAND geometry, `EC_yoke_corrected_1212_dev_SAND_complete_opt3_DRIFT1.gdml` is the most recent one)
   - `ARCUBE_EDEP_MAC` with the path of the macro file (.mac) (use `macro-sand.mac` which is substantially a copy of `2x2_beam.mac` of the tutorial)
   - `ARCUBE_INDEX`, if you run on the cluster this should be initialized with the first argument passed to the executable, if you run in bash this index can be updated each loop
5. Execute `run_edep_sim.sh`, inside a loop to produce more files

N. B. Make sure that all the files are inside `ARCUBE_DIR`, which is the directory bounded with container

## Production from bash
You just need to do `source setup-edepsim.sh` and everything should work. You should see: 
- in `ARCUBE_OUTDIR_BASE`: `run-edep-sim\ARCUBE_OUT_NAME\` with `EDEPSIM` folders, which contain `000...` folders with the productions
- in `ARCUBE_LOGDIR_BASE`: `run-edep-sim\ARCUBE_OUT_NAME\` with `LOGS` and `TIMING` folders, which contain `000...` folders with some infos about the productions

## Production on HTC cluster
Inside `submit.sub` file

The executable is `run_edep_sim.sh`, so you need to add inside this script `source /$PATH/setup-edepsim.sh` to have all the needed variables available during the execution.

Then you need to add the option for running a job inside an Apptainer image: 
```
+SingularityImage = "docker://mjkramer/sim2x2:ndlar011"
+SingularityBind = "/storage/gpfs_data/neutrino/users/gsantoni/ND_Production"

Requirements = HasSingularity
```
where SingularityBind must have the path of the directory bounded with the container.

Now you can comment this line inside the executable: 
```
source ../utile/reload_in_container.sh
```
since you with the above lines in the `submit.sub`, you are already running inside the container. 

To execute more than one job, you can pass to the executable ${Item} as argument and in the script you have to set `ARCUBE_INDEX = ${1}`. In this way the files produced are consistent with this index. 

When the jobs are completed you should see the same output as described above. Useful info about the production process can be found in the `.err, .log, .out` files, produced during the job execution. If you don't see them, you can fetch them with the command: `condor_transfer_data <JOB_ID>`.