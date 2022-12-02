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





source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
setup ifdhc
setup dk2nugenie   v01_06_01f -q e17:prof
setup genie_xsec   v2_12_10   -q DefaultPlusValenciaMEC
setup genie_phyopt v2_12_10   -q dkcharmtau
setup geant4 v4_10_3_p03e -q e17:prof
setup ND_Production v01_05_00 -q e17:prof
setup jobsub_client
setup cigetcert
setup sam_web_client v2_2
G4_cmake_file=`find ${GEANT4_FQ_DIR}/lib64 -name 'Geant4Config.cmake'`
export Geant4_DIR=`dirname $G4_cmake_file`
export PATH=$PATH:$GEANT4_FQ_DIR/bin
RUN=$((${PROCESS}+0))
SEED=$((1000000*0+${RUN}))
RDIR=$((${RUN} / 1000))
if [ ${RUN} -lt 10000 ]; then
RDIR=0$((${RUN} / 1000))
fi
TIMESTAMP=`date +%s`
${ND_PRODUCTION_DIR}/bin/copy_dune_flux --top /cvmfs/dune.osgstorage.org/pnfs/fnal.gov/usr/dune/persistent/stash/Flux/g4lbne/v3r5p4/QGSP_BERT/OptimizedEngineeredNov2017 --flavor neutrino --maxmb=100 --dk2nu
ls flux_files/ -alh
ifdh cp /pnfs/dune/scratch/users/pkroy/GNuMIFlux.xml GNuMIFlux.xml
ls -lrt
more GNuMIFlux.xml
#sed "s/<beampos> ( 0.0, 0.05387, 6.66 )/<beampos> ( 0.00, 0.05387, 6.66 )/g" ${ND_PRODUCTION_CONFIG}/GNuMIFlux.xml > GNuMIFlux.xml
export GXMLPATH=${PWD}:${GXMLPATH}
export GNUMIXML="GNuMIFlux.xml"
gevgen_fnal \
    -f flux_files/dk2nu*,DUNENDROCK\
    -g ${ND_PRODUCTION_GDML}/nd_hall_with_lar_tms_nosand.gdml \
    -t volWorld \
    -L cm -D g_cm3 \
    -e 1e+14 \
    --seed ${SEED} \
    -r ${RUN} \
    -o neutrino \
    -F "rockbox:(-621.1,-662.5,0)(621.1,402.5,1900),1,500,0.00425,1.05,1"  \
    -z -500 \
    --message-thresholds ${ND_PRODUCTION_CONFIG}/Messenger_production.xml \
    --event-record-print-level 0 \
    --cross-sections ${GENIEXSECPATH}/gxspl-FNALsmall.xml \
    --event-generator-list Default+CCMEC
cp neutrino.${RUN}.ghep.root input_file.ghep.root
gntpc -i input_file.ghep.root -f rootracker --event-record-print-level 0 --message-thresholds ${ND_PRODUCTION_CONFIG}/Messenger_production.xml
NSPILL=$(echo "std::cout << gtree->GetEntries() << std::endl;" | genie -l -b input_file.ghep.root 2>/dev/null  | tail -1)
cat ${ND_PRODUCTION_CONFIG}/dune-nd.mac > dune-nd.mac
setup edepsim v3_0_1b -q e17:prof
EDEP_OUTPUT_FILE=neutrino.${RUN}.edep.root
edep-sim -C \
  -g ${ND_PRODUCTION_GDML}/nd_hall_with_lar_tms_nosand.gdml \
  -o ${EDEP_OUTPUT_FILE} \
  -e ${NSPILL} \
  dune-nd.mac
GHEP_FILE=neutrino.${RUN}_${TIMESTAMP}.ghep.root
mv neutrino.${RUN}.ghep.root ${GHEP_FILE}
generate_sam_json ${GHEP_FILE} ${RUN} ${NSPILL} "generated" dune_nd_miniproduction_2021_v1 0.00 volWorld nd_hall_with_lar_tms_nosand 300.0 1 physics root neardet nd_production,genie,edep-sim v01_04_00,v2_12_10,v3_0_1b dune_nd_miniproduction_2021_v1 RITM1254894
ifdh cp ${GHEP_FILE}.json /pnfs/dune/scratch/dunepro/dropbox/neardet/${GHEP_FILE}.json
ifdh_mkdir_p /pnfs/dune/scratch/users/pkroy/test3/genie/FHC/00m/${RDIR}
ifdh cp ${GHEP_FILE} /pnfs/dune/scratch/users/pkroy/test3/genie/FHC/00m/${RDIR}/${GHEP_FILE}
EDEP_FILE=neutrino.${RUN}_${TIMESTAMP}.edep.root
mv ${EDEP_OUTPUT_FILE} ${EDEP_FILE}
generate_sam_json ${EDEP_FILE} ${RUN} ${NSPILL} "simulated" dune_nd_miniproduction_2021_v1 0.00 volWorld nd_hall_with_lar_tms_nosand 300.0 1 physics root neardet nd_production,genie,edep-sim v01_04_00,v2_12_10,v3_0_1b dune_nd_miniproduction_2021_v1 RITM1254894
ifdh cp ${EDEP_FILE}.json /pnfs/dune/scratch/dunepro/dropbox/neardet/${EDEP_FILE}.json
ifdh_mkdir_p /pnfs/dune/scratch/users/pkroy/test3/edep/FHC/00m/${RDIR}
ifdh cp ${EDEP_FILE} /pnfs/dune/scratch/users/pkroy/test3/edep/FHC/00m/${RDIR}/${EDEP_FILE}
