# run-genie.sh TUTORIAL

## Software versions

• GENIE 3.04.00 

• ROOT 6.18.06

## Configuration
Configure all the variables needed during the execution modifying the script `setup-genie.sh`. 
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
4. Set up variables for GENIE production (`gevgen_fnal` command):
   - `ARCUBE_DK2NU_DIR` with folder where you have .dk2nu flux files, which can be downloaded from https://www.dropbox.com/scl/fi/2jb14vfz0q2vaot0g178f/OptEngNov2017_150cmTargetCone_NoMod2_Neutrino.tar.gz?rlkey=rtn6jvkdg5n4q0vznfb3wurqk&e=2&dl=0
   - `ARCUBE_GEOM` with .gdml file (for SAND geometry, `EC_yoke_corrected_1212_dev_SAND_complete_opt3_DRIFT1.gdml` is the most recent one)
   - `ARCUBE_TUNE`, which must be the DUNE official tune (AR23_20i_00_000)
   - `ARCUBE_DET_LOCATION`, which must be `DUNEND` (taken from GNuMIFlux.xml)
   - `ARCUBE_TOP_VOLUME`, name of the volume where you want interactions (volSAND if you want the entire SAND volume)
   - `ARCUBE_EXPOSURE`, with number of POT
   - `ARCUBE_XSEC_FILE`, with the .xml file with all the cross sections. It's ok a precomputed file downloaded from https://scisoft.fnal.gov/scisoft/packages/genie_xsec/
   - `ARCUBE_INDEX`, if you run on the cluster this should be initialized with the first argument passed to the executable, if you run in bash this index can be updated each loop
5. Execute run-genie.sh, inside a loop to produce more files

N. B. Make sure that all the files are inside ARCUBE_DIR, which is the directory bounded with container

## Production from bash
You just need to do `source setup-genie.sh` and everything should work. You should see: 
- in `ARCUBE_OUTDIR_BASE`: `run-genie\ARCUBE_OUT_NAME\` with `GTRAC` and `GHEP` folders, which contain `000...` folders with the productions
- in `ARCUBE_LOGDIR_BASE`: `run-genie\ARCUBE_OUT_NAME\` with `LOGS`, `STATUS` and `TIMING` folders, which contain `000...` folders with some infos about the productions

## Production on HTC cluster
In `submit.sub` file

The executable is `run_genie.sh`, so you need to add inside this script `source /$PATH/setup-genie.sh` to have all the needed variables available during the execution.

Then you need to add the option for running a job inside an Apptainer image: 
```
+SingularityImage = "docker://mjkramer/sim2x2:genie_edep.3_04_00.20230912"
+SingularityBind = "/storage/gpfs_data/neutrino/users/gsantoni/ND_Production"

Requirements = HasSingularity
```
where SingularityBind must have the path of the directory bounded with the container.

Now you can comment this line inside the executable: 
```
source ../utile/reload_in_container.sh
```
since you with the above lines in the `submit.sub`, you are already running inside the container. However, in this case, since this Apptainer image has been built with a convoluted process and the environment file at some point has been overwritten, you need to source this file which is a copy of the original environment file: 
```
source ../admin/container_env.sim2x2_genie_edep.3_04_00.20230912.sif.sh
../admin/container_env.sim2x2_genie_edep.3_04_00.20230912.sif.sh
```

To execute more than one job, you can pass to the executable ${Item} as argument and in the script you have to set `ARCUBE_INDEX = ${1}`. In this way the files produced are consistent with this index.

