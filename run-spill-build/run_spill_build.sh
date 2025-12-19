#!/usr/bin/env bash

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-mjkramer/sim2x2:ndlar011}

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

sampleAName=$ND_PRODUCTION_SAMPLE_A_NAME.$globalIdx
sampleBName=$ND_PRODUCTION_SAMPLE_B_NAME.$globalIdx
echo "outName is $outName"

inBaseDir=$ND_PRODUCTION_OUTDIR_BASE/run-hadd
if [[ "$ND_PRODUCTION_NO_HADD" == "1" ]]; then
  inBaseDir=$ND_PRODUCTION_OUTDIR_BASE/run-edep-sim
fi
sampleAInDir=$inBaseDir/$ND_PRODUCTION_SAMPLE_A_NAME
sampleBInDir=$inBaseDir/$ND_PRODUCTION_SAMPLE_B_NAME

[ -z "${ND_PRODUCTION_INDEX_OFFSET}" ] && export ND_PRODUCTION_INDEX_OFFSET=0

if [[ "$ND_PRODUCTION_REUSE_SAMPLE_B" == "1" ]]; then
  nSampleAFiles=$(find $sampleAInDir/EDEPSIM -type f | wc -l)
  nSampleBFiles=$(find $sampleBInDir/EDEPSIM -type f | wc -l)
  reuseRate=$((nSampleAFiles / nSampleBFiles))
  echo "There are $nSampleAFiles sample_A files and $nSampleBFiles sample_B files"
  echo "The sample_B file reuse rate is $reuseRate"

  sampleBIdx=$((ND_PRODUCTION_INDEX % nSampleBFiles))
  sampleBIdx=$((sampleBIdx + ND_PRODUCTION_INDEX_OFFSET))
  sampleBGlobalIdx=$(printf "%07d" "$sampleBIdx")

  sampleBName=$ND_PRODUCTION_SAMPLE_B_NAME.$sampleBGlobalIdx
  sampleBSubDir=$(printf "%07d" $((sampleBIdx / 1000 * 1000)))
else
  sampleBSubDir=$subDir
fi

sampleAInFile=$sampleAInDir/EDEPSIM/$subDir/${sampleAName}.EDEPSIM.root
sampleBInFile=$sampleBInDir/EDEPSIM/$sampleBSubDir/${sampleBName}.EDEPSIM.root

export GXMLPATH=$ND_PRODUCTION_DIR/run-genie/flux

spillFile=$tmpOutDir/${outName}.EDEPSIM_SPILLS.root
rm -f "$spillFile"

# run root -l -b -q \
#     -e "gInterpreter->AddIncludePath(\"/opt/generators/edep-sim/install/include/EDepSim\")" \
#     "overlaySinglesIntoSpills.C(\"$sampleAInFile\", \"$sampleBInFile\", \"$spillFile\", $ND_PRODUCTION_SAMPLE_A_POT, $ND_PRODUCTION_SAMPLE_B_POT)"

# HACK: We need to "unload" edep-sim; if it's in our LD_LIBRARY_PATH, we have to
# use the "official" edepsim-io headers, which force us to use the getters, at
# least when using cling(?). overlaySinglesIntoSpills.C directly accesses the
# fields. So we apparently must use headers produced by MakeProject, but that
# would lead to a conflict with the ones from the edep-sim installation. Hence
# we unload the latter. Fun. See makeLibTG4Event.sh

libpath_remove /opt/generators/edep-sim/install/lib

[ -z "${ND_PRODUCTION_SPILL_POT}" ] && export ND_PRODUCTION_SPILL_POT=5e13
[ -z "${ND_PRODUCTION_SPILL_PERIOD}" ] && export ND_PRODUCTION_SPILL_PERIOD=1.2
[ -z "${ND_PRODUCTION_REUSE_SAMPLE_B}" ] && export ND_PRODUCTION_REUSE_SAMPLE_B=0

if [[ "$ND_PRODUCTION_USE_GHEP_POT" == "1" ]]; then
  # Covering the case that we want to use the GHEP POT but build only
  # fiducial or only sample_B spills. For example, to build fiducial 
  # only spills, ND_PRODUCTION_SAMPLE_B_POT is set to zero.
  if [[ "$ND_PRODUCTION_SAMPLE_A_POT" != "0" && -n "$ND_PRODUCTION_SAMPLE_A_POT" ]]; then
    echo "Setting ND_PRODUCTION_SAMPLE_A_POT to a non-zero value while also using GHEP POT via"
    echo "ND_PRODUCTION_USE_GHEP_POT is inconsistent. Please refactor..."
    exit
  elif [[ "$ND_PRODUCTION_SAMPLE_A_POT" == "0" ]]; then
    echo "ND_PRODUCTION_SAMPLE_A_POT is set to zero - spills will be sample_B only."
  else
    read -r ND_PRODUCTION_SAMPLE_A_POT < "$sampleAInDir"/POT/$subDir/"$sampleAName".pot
  fi
  if [[ "$ND_PRODUCTION_SAMPLE_B_POT" != "0" && -n "$ND_PRODUCTION_SAMPLE_B_POT" ]]; then
    echo "Setting ND_PRODUCTION_SAMPLE_B_POT to a non-zero value while also using GHEP POT via"
    echo "ND_PRODUCTION_USE_GHEP_POT is inconsistent. Please refactor..."
    exit
  elif [[ "$ND_PRODUCTION_SAMPLE_B_POT" == "0" ]]; then
    echo "ND_PRODUCTION_NU_SAMPLE_B is set to zero - spills will be sample_A only."
  else
    read -r ND_PRODUCTION_SAMPLE_B_POT < "$sampleBInDir"/POT/$sampleBSubDir/"$sampleBName".pot
  fi
fi

# run root -l -b -q \
#     -e "gInterpreter->AddIncludePath(\"libTG4Event\")" \
#     "overlaySinglesIntoSpills.C(\"$sampleAInFile\", \"$sampleBInFile\", \"$spillFile\", $ND_PRODUCTION_SAMPLE_A_POT, $ND_PRODUCTION_SAMPLE_B_POT, $ND_PRODUCTION_SPILL_POT)"

# run root -l -b -q \
#     -e "gSystem->Load(\"libTG4Event/libTG4Event.so\")" \
#     "overlaySinglesIntoSpills.C(\"$sampleAInFile\", \"$sampleBInFile\", \"$spillFile\", $ND_PRODUCTION_SAMPLE_A_POT, $ND_PRODUCTION_SAMPLE_B_POT, $ND_PRODUCTION_SPILL_POT)"

# LIBTG4EVENT_DIR is provided by the podman-built containers
# If unset, fall back to the local build provided by install_spill_build.sh
LIBTG4EVENT_DIR=${LIBTG4EVENT_DIR:-libTG4Event}

LIBGENIE_DIR=$(echo "$LD_LIBRARY_PATH" | tr ':' '\n' | grep -i genie | head -n 1)

# By default, use the script with the time of flight correction. 
# Change the value to 0 if you want to use the previous script
: "${ND_PRODUCTION_USE_NU_TOF:=1}"

if [[ "$ND_PRODUCTION_USE_NU_TOF" == "0" ]]; then
  run root -l -b -q \
      -e "gSystem->AddDynamicPath(\"$LIBTG4EVENT_DIR\"); \
          gSystem->Load(\"libTG4Event.so\")" \
      "overlaySinglesIntoSpillsSorted.C(\"$sampleAInFile\", \"$sampleBInFile\", \"$spillFile\", $ND_PRODUCTION_INDEX, $ND_PRODUCTION_SAMPLE_A_POT, $ND_PRODUCTION_SAMPLE_B_POT, $ND_PRODUCTION_SPILL_POT, $ND_PRODUCTION_SPILL_PERIOD, $ND_PRODUCTION_REUSE_SAMPLE_B)"
elif [[ "$ND_PRODUCTION_USE_NU_TOF" == "1" ]]; then
  run root -l -b -q \
      -e  "gSystem->AddDynamicPath(\"$LIBTG4EVENT_DIR\"); \
            gSystem->AddDynamicPath(\"$LIBGENIE_DIR\"); \
            gSystem->Load(\"libPhysics.so\"); \
            gSystem->Load(\"libEG.so\"); \
            gSystem->Load(\"libTG4Event.so\"); \
            gSystem->Load(\"libGFwMsg.so\"); \
            gSystem->Load(\"libGFwReg.so\"); \
            gSystem->Load(\"libGFwParDat.so\"); \
            gSystem->Load(\"libGFwAlg.so\"); \
            gSystem->Load(\"libGFwUtl.so\"); " \
      "/opt/generators/dk2nu/scripts/load_dk2nu.C(true,true)" \
      "overlaySinglesIntoSpillsSortedWithNuIntTime.cpp(\"$sampleAInFile\", \"$sampleBInFile\", \"$ND_PRODUCTION_SAMPLE_A_NAME\", \"$ND_PRODUCTION_SAMPLE_B_NAME\", \"$ND_PRODUCTION_OUTDIR_BASE\", \"$spillFile\", $ND_PRODUCTION_INDEX, $ND_PRODUCTION_SAMPLE_A_POT, $ND_PRODUCTION_SAMPLE_B_POT, $ND_PRODUCTION_SPILL_POT, $ND_PRODUCTION_SPILL_PERIOD, $ND_PRODUCTION_HADD_FACTOR, $ND_PRODUCTION_REUSE_SAMPLE_B, \"$ND_PRODUCTION_DET_LOCATION\")"
fi

mkdir -p "$outDir/EDEPSIM_SPILLS/$subDir"
mv "$spillFile" "$outDir/EDEPSIM_SPILLS/$subDir"
