# run_genie.sh TUTORIAL on ND_Production/main

## Container
sim2x2:genie_edep.3_04_00.20230912

With these versions:

• GENIE 3.04.00 

• ROOT 6.18.06

## Before the first run 
Execute the script `/admin/install_everything.sh`. There are some settings for ND-LAr productions, but you can ignore them. At the moment we need to run it just to install GNU time compiler, which is needed to run each subsequent command. You need to do it only the first time you run these scripts. 

N.B. Run it from `ND_Production` folder!

## Production on HTCondor

# Configuration file

Create a script to configure all the variables needed during the execution (i.e. `launch_genie.sh`). In this script you have to `export` all the following variables.

1. Set up your working directory:
   - `ND_PRODUCTION_DIR` with the name of the folder
2. Set up container info:
   - `ND_PRODUCTION_RUNTIME` with container run time (Singularity for CNAF users)
   - `ND_PRODUCTION_CONTAINER` with container name
   - `SINGULARITY_NAME`="${ND_PRODUCTION_CONTAINER}"
3. Set up output folders:
   - `ND_PRODUCTION_OUTDIR_BASE` with the name of the folder where your productions will be stored
   - `ND_PRODUCTION_LOGDIR_BASE` with the name of the folder where your logs will be stored
   - `ND_PRODUCTION_OUT_NAME` with the name of the produced files
4. Set up variables for GENIE production (`gevgen_fnal` command):
   - `ND_PRODUCTION_DK2NU_DIR` with folder where you have .dk2nu flux files, which can be downloaded from https://www.dropbox.com/scl/fi/2jb14vfz0q2vaot0g178f/OptEngNov2017_150cmTargetCone_NoMod2_Neutrino.tar.gz?rlkey=rtn6jvkdg5n4q0vznfb3wurqk&e=2&dl=0
   - `ND_PRODUCTION_GEOM` with .gdml file (for SAND geometry, `SAND_opt3_DRIFT1.gdml` is the most recent one)
   - `ND_PRODUCTION_TUNE`, which must be the DUNE official tune (AR23_20i_00_000)
   - `ND_PRODUCTION_DET_LOCATION`, which must be `DUNEND` (taken from GNuMIFlux.xml)
   - `ND_PRODUCTION_TOP_VOLUME`, name of the volume where you want interactions (volSAND if you want the entire SAND volume)
   - `ND_PRODUCTION_EXPOSURE`, with number of POT
   - `ND_PRODUCTION_XSEC_FILE`, with the .xml file with all the cross sections. It's ok a precomputed file downloaded from https://scisoft.fnal.gov/scisoft/packages/genie_xsec/
   - `ND_PRODUCTION_INDEX`, if you run on the cluster this should be initialized with the first argument passed to the executable, if you run in bash this index can be updated each loop
4. `cd` into `run-genie` folder
5. Add a line to execute `run-genie.sh` with the option `"$@"`

![Screenshot 2025-06-06 alle 10 15 26](https://github.com/user-attachments/assets/f05347eb-d8be-4c69-9361-85a5df14c418)

# N.B. 

At the moment of writing (June '25), we have no default geometry for SAND, hence there is no default maxpath file. GENIE works even without maxpath file, but if you want to use it, you have to generate it during the execution. You can do this by adding the following few lines in `run.sh` (changing properly the paths):

```
if [ ! -f "$maxPathFile" ]; then
    # Since I have no maxpath file already present, I need to convert gdml in root and then produce maxpath from the root file
    echo "TGeoManager::SetVerboseLevel(0); TGeoManager::Import(\"/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/$ND_PRODUCTION_GEOM\"); TFile f(\"/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/$(basename $ND_PRODUCTION_GEOM .gdml).root\",\"RECREATE\"); gGeoManager->Write(\"geo\"); f.Close();" | root -l -b
    
    # Evaluate max path lengths from ROOT geometry file
    echo "/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/$(basename $ND_PRODUCTION_GEOM .gdml).root"
    gmxpl -f /storage/gpfs_data/neutrino/users/gsantoni/ND_Production/$(basename $ND_PRODUCTION_GEOM .gdml).root -L cm -D g_cm3 --tune $ND_PRODUCTION_TUNE -t $ND_PRODUCTION_TOP_VOLUME -o /storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-genie/maxpath/$(basename $ND_PRODUCTION_GEOM .gdml).maxpath.xml -seed 21304 --message-thresholds /storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-genie/Messenger.xml  &> ${ND_PRODUCTION_LOGDIR_BASE}/gmxpl.log
fi
```

# Submit file

Prepare `submit.sub` file: 

You need to add the option for running a job inside a Singularity image: 
```
+SingularityImage = "docker://mjkramer/sim2x2:genie_edep.3_04_00.20230912"

Requirements = HasSingularity
```
The executable is `launch_genie.sh`.

To execute more than one job, you can pass to the executable ${Item} as argument and in the script you have to set `ND_PRODUCTION_INDEX = ${1}`. In this way the files produced are consistent with this index. 

![Screenshot 2025-06-06 alle 10 49 09](https://github.com/user-attachments/assets/ffa15bf2-a7aa-4fd2-bc95-35cbcf5cfff5)

When the jobs are completed you should see:
- in `ND_PRODUCTION_OUTDIR_BASE`: `run-genie\ND_PRODUCTION_OUT_NAME\` with `GTRAC` and `GHEP` folders, which contain `000...` folders with the productions
- in `ND_PRODUCTION_LOGDIR_BASE`: `run-genie\ND_PRODUCTION_OUT_NAME\` with `LOGS`, `STATUS` and `TIMING` folders, which contain `000...` folders with some infos about the productions

Useful info about the production process can be found in the `.err, .log, .out` files, produced during the job execution. If you don't see them, you can fetch them with the command: `condor_transfer_data <JOB_ID>`.

## Production from bash 

Pull the container using the script in `/admin` called `pull_singularity_container.sh`.

1. Set up your working directory, `ND_PRODUCTION` (or the name of the folder of this repo)
2. Set up container info: same as above, but add
   - `ND_PRODUCTION_CONTAINER_DIR` with the directory where you pulled the container (pulled using the script in `/admin` called `pull_singularity_container.sh`)
   - `ND_PRODUCTION_DIR` with the path of the directory that you bind with your container
3. Set up output folders: same as above
4. Set up variables for GENIE production (`gevgen_fnal` command): same as above
5. Execute `run-genie.sh`, inside a loop to produce more files

N. B. Make sure that all the files are inside `ND_PRODUCTION_DIR`, which is the directory bounded with container

After you set your variables, you just need to do `source launch_genie.sh` and everything should work. You should see an output as described above.
