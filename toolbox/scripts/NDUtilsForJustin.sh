#!/bin/bash

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# 	This script for contain common functions deployed in the justin job scripts
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


#++++++++++++++++++++++++++++++++++++++++
# setup environment variables 
#++++++++++++++++++++++++++++++++++++++++
export EXTERNAL_RELEASE="v25.3.0-3"

export CVMFS_TWOBYTWO_DIR="/cvmfs/dune.opensciencegrid.org/dunend/2x2/"
export CVMFS_WORKING_DIR="${CVMFS_TWOBYTWO_DIR}/releases/${TWOBYTWO_RELEASE}"

export HDF5_USE_FILE_LOCKING=FALSE
export OMP_NUM_THREADS=1

export EDEPSIM_VERSION="v3_2_0c"
export EDEPSIM_QUALIFIER="e20:prof"

export PYTHON_VERSION="v3_9_15"
export H5PY_VERSION="v3_1_0d"
export H5PY_QUALIFIER="e20:p392:prof"

export GCC_VERSION="v9_3_0"
export TBB_VERSION="v2021_7_0"
export TBB_QUALIFIER="e20"

export ROOT_VERSION="v6_26_06b"
export ROOT_QUALIFIER="e20:p3913:prof"

export METACAT_SERVER_URL=https://metacat.fnal.gov:9443/dune_meta_prod/app
export METACAT_AUTH_SERVER_URL=https://metacat.fnal.gov:8143/auth/dune

#+++++++++++++++++++++++++++++++++++++++
# Begin of justin job running
#+++++++++++++++++++++++++++++++++++++++
justin_begin_of_job_commands()
{
    # enter the software setup script
    export JUSTIN_SUBID=`echo "${JUSTIN_JOBSUB_ID}" | sed 's/@/./g'`
    echo -e "Creating the file $PWD/env_${JUSTIN_WORKFLOW_ID}.${JUSTIN_STAGE_ID}.${JUSTIN_SUBID}.log" > $PWD/env_${JUSTIN_WORKFLOW_ID}.${JUSTIN_STAGE_ID}.${JUSTIN_SUBID}.log
    export envlog="$PWD/env_${JUSTIN_WORKFLOW_ID}.${JUSTIN_STAGE_ID}.${JUSTIN_SUBID}.log"

    # get the site information
    echo -e "The node working directory $PWD" 2>&1 | tee -a $envlog
    echo -e "\t\thost is `/bin/hostname`" 2>&1 | tee -a $envlog
    echo -e "\t\tjustin site is $JUSTIN_SITE_NAME" 2>&1 | tee -a $envlog
    echo -e "\t\tthe current directory is $PWD" 2>&1 | tee -a $envlog

    # setup workspace
    export WORKSPACE=${PWD}
    echo -e "The workspace directory is ${WORKSPACE}" 2>&1 | tee -a $envlog

    # Ask justin to retrieve the file
    echo -e "\n\nRetrieving the file from the path [$JUSTIN_PATH]." | tee -a $envlog

    did_pfn_rse=`$JUSTIN_PATH/justin-get-file`
    did=`echo $did_pfn_rse | cut -f1 -d' '`
    pfn=`echo $did_pfn_rse | cut -f2 -d' '`
    rse=`echo $did_pfn_rse | cut -f3 -d' '`

    if [ "${did_pfn_rse}" == "" ] ; then
        echo -e "justIN does not get a file. Exiting the jobscript." 2>&1 | tee -a $envlog
        if [ ${JOBSCRIPT_TEST} -eq 0 ]; then
           echo -e "Updating jobscript name jobscript_${JUSTIN_WORKFLOW_ID}.${JUSTIN_STAGE_ID}.${JUSTIN_SUBID}.log\n" 2>&1 | tee -a $envlog
           mv jobscript.log jobscript_${JUSTIN_WORKFLOW_ID}.${JUSTIN_STAGE_ID}.${JUSTIN_SUBID}.log
        fi
        exit 0
    fi

    echo -e "\tThe file data identifier (DID) is [$did]" | tee -a $envlog
    echo -e "\tThe file physical file name (PFN) is [$pfn]" | tee -a $envlog
    echo -e "\tThe file Rucio storage element (RSE) is [$rse]\n" | tee -a $envlog


    # Get the input filename
    IFS='/' read -r -a array <<< "$pfn"
    export INPUT_FILE="${array[-1]}"
    echo -e "The input file is ${INPUT_FILE}" 2>&1 | tee -a $envlog

    # Copy file to local disk
    echo -e "Using rucio to download file [$did]" 2>&1 | tee -a $envlog
    (
         source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
         source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh

         setup python ${PYTHON_VERSION}
         setup rucio

      	 export RUCIO_ACCOUNT=justinreadonly

         rucio download ${did} --dir ${WORKSPACE}

         subdir=`echo $did | cut -f1 -d':'`
         mv ${WORKSPACE}/${subdir}/* ${WORKSPACE}/
    ) 
}


#++++++++++++++++++++++++++++++++++++++++
# create metadata json file
#++++++++++++++++++++++++++++++++++++++++
create_metadata_file()  
{
    echo -e "Creating the metadata json file(s) for the output data file(s) [${CREATED_FILES}]" 2>&1 | tee -a $envlog

    export METADATA_EXTRACT=${CVMFS_WORKING_DIR}/ndlar_prod_scripts/ND_Production/toolbox/scripts/MetadataExtract.py 

    CREATED_FILES_ARRAY=$( IFS=$','; echo "${CREATED_FILES[*]}" )
    PARENT_FILES_ARRAY=$( IFS=$','; echo "${PARENT_FILES[*]}" ) 
    WORKFLOW_ARRAY=$( IFS=$','; echo "${WORKFLOW[*]}" )

    echo -e "\tRunning the command [python3 ${METADATA_EXTRACT} --input=\"${CREATED_FILES_ARRAY[@]}\" --parents=\"${PARENT_FILES_ARRAY[@]}\" --workflow=\"${WORKFLOW_ARRAY[@]}\" --tier=\"${APPLICATION_DATA_TIER}\" --namespace=\"${NAMESPACE}\"]" 2>&1 | tee -a $envlog
    (
       source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
       source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh

       setup metacat
       setup python v3_8_3b
       setup h5py v3_1_0d -q e20:p383b:prof
       setup root v6_22_08b -q e20:p383b:prof

       python ${METADATA_EXTRACT} --input="${CREATED_FILES_ARRAY[@]}" --parents="${PARENT_FILES_ARRAY[@]}" --workflow="${WORKFLOW_ARRAY[@]}" --tier="${APPLICATION_DATA_TIER}" --namespace="${NAMESPACE}"
    )
}


#+++++++++++++++++++++++++++++++++++++++
# End of justin job running
#+++++++++++++++++++++++++++++++++++++++
justin_end_of_job_commands()
{
    if [  -f "$INPUT_FILE" ]; then
       echo -e "\nRemoving the local copy of the input file ${WORKSPACE}/${INPUT_FILE}." 2>&1 | tee -a $envlog
       rm -f ${WORKSPACE}/${INPUT_FILE}
    fi

    if [ ${JOBSCRIPT_TEST} -eq 0 ]; then
       echo -e "Marking the input file(s) [${pfn}] as processed.\n" 2>&1 | tee -a $envlog
       echo -e "${pfn}" > justin-processed-pfns.txt
    fi

    echo -e "\n\nThe contents in the ${WORKSPACE} directory:" 2>&1 | tee -a $envlog
    ls -lha * 2>&1 | tee -a $envlog
    echo -e "" | tee -a $envlog

    date +"%n%a %b %d %T %Z %Y%n" | tee -a $envlog
    echo -e "Exit the jobscript.\n\n" 2>&1 | tee -a $envlog

    if [ ${JOBSCRIPT_TEST} -eq 0 ]; then
       echo -e "Updating jobscript name jobscript_${JUSTIN_WORKFLOW_ID}.${JUSTIN_STAGE_ID}.${JUSTIN_SUBID}.log\n" 2>&1 | tee -a $envlog
       mv jobscript.log jobscript_${JUSTIN_WORKFLOW_ID}.${JUSTIN_STAGE_ID}.${JUSTIN_SUBID}.log
    fi
}

