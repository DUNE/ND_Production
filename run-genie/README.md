# run-genie.sh TUTORIAL

# Software versions
• GENIE 3.04.00
• ROOT 6.18.06

# setup-genie.sh
Configure all the variables needed during the execution. 
1. Set up your working directory, initializing BASE_DIR and ND_PRODUCTION (or the name of the folder of this repo)
2. Set up container info:
   - ARCUBE_CONTAINER with container name
   - ARCUBE_RUNTIME with container run time (Apptainer for CNAF users)
   - ARCUBE_CONTAINER_DIR with the directory where you pulled the container (pulled using the script in \texttt{/admin} called \texttt{pull_singularity_container.sh})
   - ARCUBE_DIR with the path of the directory that you bind with your container
3. Set up output folders:
   - ARCUBE_OUTDIR_BASE with the name of the folder where your productions will be stored
   - ARCUBE_LOGDIR_BASE with the name of the folder where your logs will be stored
   - ARCUBE_OUT_NAME with the name of the produced files
4. Set up variables for GENIE production (gevgen_fnal command):
   - ARCUBE_DK2NU_DIR with folder where you have .dk2nu flux files, which can be downloaded from https://www.dropbox.com/scl/fi/2jb14vfz0q2vaot0g178f/OptEngNov2017_150cmTargetCone_NoMod2_Neutrino.tar.gz?rlkey=rtn6jvkdg5n4q0vznfb3wurqk&e=2&dl=0
   - ARCUBE_GEOM with .gdml file (for SAND geometry, ´´EC_yoke_corrected_1212_dev_SAND_complete_opt3_DRIFT1.gdml`` is the most recent one)
   - ARCUBE_TUNE, which must be the DUNE official tune (AR23_20i_00_000)
   - ARCUBE_DET_LOCATION,
   - ARCUBE_TOP_VOLUME, name of the volume where you want interactions (volSAND if you want the entire SAND volume)
   - ARCUBE_EXPOSURE, with number of pot
   - ARCUBE_RUN_OFFSET ??
   - ARCUBE_XSEC_FILE, with the .xml file with all the cross sections. It's ok a precomputed file downloaded from https://scisoft.fnal.gov/scisoft/packages/genie_xsec/

N. B. Make sure that all the files are inside ARCUBE_DIR, which is the directory bounded with container


