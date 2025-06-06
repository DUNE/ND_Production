# run_edep_sim.sh TUTORIAL on ND_Production/main

## Container
sim2x2:ndlar011

With these versions:

• GENIE 3.04.00 

• ROOT 6.28.06

## Production on HTCondor
Create a script to configure all the variables needed during the execution (i.e. `launch_edep_sim.sh`). In this script you have to `export` all the following variables. It will be very similar to genie one.

1. Set up your working directory:
   - `ND_PRODUCTION_DIR` with the name of the folder
2. Set up container info:
   - `ND_PRODUCTION_RUNTIME` with container run time (Singularity for CNAF users)
   - `ND_PRODUCTION_CONTAINER` with container name
   - `SINGULARITY_NAME`="${ND_PRODUCTION_CONTAINER}"
3. Set up output folders:
   - `ND_PRODUCTION_OUTDIR_BASE` with the name of the folder where your productions will be stored
   - `ND_PRODUCTION_LOGDIR_BASE` with the name of the folder where your logs will be stored
   - `ND_PRODUCTION_GENIE_NAME` with the name of the files produced by GENIE
   - `ND_PRODUCTION_OUT_NAME` with the name of the produced files
4. Set up variables for EDEPSIM (`edep-sim` command):
   - `ND_PRODUCTION_GEOM_EDEP` with .gdml file (for SAND geometry, `SAND_opt3_DRIFT1.gdml` is the most recent one)
   - `ND_PRODUCTION_EDEP_MAC` with the path of the macro file (dune-nd.mac)
   - `ND_PRODUCTION_INDEX`, if you run on the cluster this should be initialized with the first argument passed to the executable, if you run in bash this index can be updated each loop
5. `cd` into `run-edep-sim` folder
6. Add a line to execute `run_edep_sim.sh` with the option `"$@"`

![Screenshot 2025-06-06 alle 10 52 20](https://github.com/user-attachments/assets/cbb2aeec-18b1-4400-bc6e-36ce6ba56c13)

Prepare `submit.sub` file: 

You need to add the option for running a job inside a Singularity image: 
```
+SingularityImage = "docker://mjkramer/sim2x2:genie_edep.3_04_00.20230912"

Requirements = HasSingularity
```

The executable is `launch_edep_sim.sh`.

To execute more than one job, you can pass to the executable ${Item} as argument and in the script you have to set `ND_PRODUCTION_INDEX = ${1}`. In this way the files produced are consistent with this index. 

![Screenshot 2025-06-06 alle 10 49 00](https://github.com/user-attachments/assets/ef4a4c76-77ba-4acb-b5a0-7990a328f1a2)

When the jobs are completed you should see:
- in `ND_PRODUCTION_OUTDIR_BASE`: `run-edep-sim\ND_PRODUCTION_OUT_NAME\` with `EDEPSIM` folders, which contain `000...` folders with the productions
- in `ND_PRODUCTION_LOGDIR_BASE`: `run-edep-sim\ND_PRODUCTION_OUT_NAME\` with `LOGS` and `TIMING` folders, which contain `000...` folders with some infos about the productions

Useful info about the production process can be found in the `.err, .log, .out` files, produced during the job execution. If you don't see them, you can fetch them with the command: `condor_transfer_data <JOB_ID>`.

## Production from bash 

Pull the container using the script in `/admin` called `pull_singularity_container.sh`.

1. Set up your working directory, `ND_PRODUCTION` (or the name of the folder of this repo)
2. Set up container info: same as above, but add
   - `ND_PRODUCTION_CONTAINER_DIR` with the directory where you pulled the container (pulled using the script in `/admin` called `pull_singularity_container.sh`)
   - `ND_PRODUCTION_DIR` with the path of the directory that you bind with your container
3. Set up output folders: same as above
4. Set up variables for GENIE production (`edep-sim` command): same as above
5. Execute `run_edep_sim.sh`, inside a loop to produce more files

N. B. Make sure that all the files are inside `ND_PRODUCTION_DIR`, which is the directory bounded with container

After you set your variables, you just need to do `source launch_edep_sim.sh` and everything should work. You should see an output as described above.
