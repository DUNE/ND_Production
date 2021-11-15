#! /usr/bin/env bash

export IFDH_CP_UNLINK_ON_ERROR=1
export IFDH_CP_MAXRETRIES=1
export IFDH_DEBUG=0

# mkdir -p workalike for ifdh cp
ifdh_mkdir_p() {
  local dir=$1
  local force=$2
  if [ `ifdh ls $dir 0 $force | wc -l` -gt 0 ] 
  then
      : # we're done
  else
      ifdh_mkdir_p `dirname $dir` $force
      ifdh mkdir $dir $force
  fi
}

generate_sam_json() {

  FILENAME=$1
  NEVENTS=$3
  JSONFILE=${FILENAME}.json
  SIZE=$(stat --printf="%s" ${FILENAME})
  DATE=$(date +%Y-%m-%dT%H:%M:%S)


  LASTEVENT=0
  if [[ ${NEVENTS} -gt 0 ]]; then
    LASTEVENT=$((${NEVENTS}-1))
  fi

  cat << EOF > ${JSONFILE}
{
  "file_name": "${FILENAME}",
  "file_type": "mc",
  "data_tier": "$4",
  "event_count": ${NEVENTS},
  "file_size": ${SIZE},
  "start_time": "${DATE}",
  "end_time": "${DATE}",
  "first_event": 0,
  "last_event": ${LASTEVENT},
  "runs": [
    [ $2, 1, "neardet" ]
  ],
  "DUNE.generators": "genie",
  "DUNE_MC.name": "$5",
  "NearDetector_MC.OffAxisPosition": $6,
  "DUNE_MC.TopVolume": "$7",
  "DUNE_MC.geometry_version": "$8",
  "LBNF_MC.HornCurrent": $9,
  "DUNE_MC.beam_flux_ID": ${10},
  "data_stream": "${11}",
  "file_format": "${12}",
  "application": [
    "${13}", "${14}", "${15}"
  ],
  "DUNE.campaign": "${16}",
  "DUNE.requestid": "${17}"
}
EOF

  samweb validate-metadata ${JSONFILE}
}

dropbox_copy() {
  FILENAME=$1
  EXT=$2
  TIER=$3

  # Normalize names
  FILENAME_TS=${HORN}.${RNDSEED}_${TIMESTAMP}${EXT}
  mv ${FILENAME} ${FILENAME_TS}

  generate_sam_json ${FILENAME_TS} ${TIER}
  ${CP} ${FILENAME_TS} ${DROPBOX_ND}/${FILENAME_TS}
  ${CP} ${FILENAME_TS}.json ${DROPBOX_ND}/${FILENAME_TS}.json
}





