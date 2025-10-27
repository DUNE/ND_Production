#!/usr/bin/env bash

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-mjkramer/sim2x2:ndlar011}

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

nuName=$ND_PRODUCTION_NU_NAME.$globalIdx
rockName=$ND_PRODUCTION_ROCK_NAME.$globalIdx
ghepNuName=$ND_PRODUCTION_GHEP_NU_NAME.$globalIdx # even if I think it's not necessary because ND_PRODUCTION_GHEP_NU_NAME would be the same of ND_PRODUCTION_NU_NAME
echo "outName is $outName"

inBaseDir=$ND_PRODUCTION_OUTDIR_BASE/run-hadd
if [[ "$ND_PRODUCTION_NO_HADD" == "1" ]]; then
  inBaseDir=$ND_PRODUCTION_OUTDIR_BASE/run-edep-sim
fi
nuInDir=$inBaseDir/$ND_PRODUCTION_NU_NAME
rockInDir=$inBaseDir/$ND_PRODUCTION_ROCK_NAME

[ -z "${ND_PRODUCTION_INDEX_OFFSET}" ] && export ND_PRODUCTION_INDEX_OFFSET=0

if [[ "$ND_PRODUCTION_REUSE_ROCK" == "1" ]]; then
  nNuFiles=$(find $nuInDir/EDEPSIM -type f | wc -l)
  nRockFiles=$(find $rockInDir/EDEPSIM -type f | wc -l)
  reuseRate=$((nNuFiles / nRockFiles))
  echo "There are $nNuFiles fiducial files and $nRockFiles rock files"
  echo "The rock file reuse rate is $reuseRate"

  rockIdx=$((ND_PRODUCTION_INDEX % nRockFiles))
  rockIdx=$((rockIdx + ND_PRODUCTION_INDEX_OFFSET))
  rockGlobalIdx=$(printf "%07d" "$rockIdx")

  rockName=$ND_PRODUCTION_ROCK_NAME.$rockGlobalIdx
  rockSubDir=$(printf "%07d" $((rockIdx / 1000 * 1000)))
else
  rockSubDir=$subDir
fi

[ -z "${ND_PRODUCTION_INDEX_OFFSET}" ] && export ND_PRODUCTION_INDEX_OFFSET=0

if [[ "$ND_PRODUCTION_REUSE_ROCK" == "1" ]]; then
  nNuFiles=$(find $nuInDir/EDEPSIM -type f | wc -l)
  nRockFiles=$(find $rockInDir/EDEPSIM -type f | wc -l)
  reuseRate=$((nNuFiles / nRockFiles))
  echo "There are $nNuFiles fiducial files and $nRockFiles rock files"
  echo "The rock file reuse rate is $reuseRate"

  rockIdx=$((ND_PRODUCTION_INDEX % nRockFiles))
  rockIdx=$((rockIdx + ND_PRODUCTION_INDEX_OFFSET))
  rockGlobalIdx=$(printf "%07d" "$rockIdx")

  rockName=$ND_PRODUCTION_ROCK_NAME.$rockGlobalIdx
  rockSubDir=$(printf "%07d" $((rockIdx / 1000 * 1000)))
else
  rockSubDir=$subDir
fi

ghepDir=$ND_PRODUCTION_OUTDIR_BASE/run-genie/
# ghepFile=$ghepDir/$ND_PRODUCTION_NU_NAME/GHEP/$subDir/${ghepNuName}.GHEP.root
ghepFile=$ND_PRODUCTION_NU_NAME
nuInFile=$nuInDir/EDEPSIM/$subDir/${nuName}.EDEPSIM.root
rockInFile=$rockInDir/EDEPSIM/$rockSubDir/${rockName}.EDEPSIM.root

export GXMLPATH=$ND_PRODUCTION_DIR/run-genie/flux

echo "gxml path is $GXMLPATH"
echo "genie dir is $GENIE"
echo "LD LIB PATH is $LD_LIBRARY_PATH"

spillFile=$tmpOutDir/${outName}.EDEPSIM_SPILLS.root
rm -f "$spillFile"

# run root -l -b -q \
#     -e "gInterpreter->AddIncludePath(\"/opt/generators/edep-sim/install/include/EDepSim\")" \
#     "overlaySinglesIntoSpills.C(\"$nuInFile\", \"$rockInFile\", \"$spillFile\", $ND_PRODUCTION_NU_POT, $ND_PRODUCTION_ROCK_POT)"

# HACK: We need to "unload" edep-sim; if it's in our LD_LIBRARY_PATH, we have to
# use the "official" edepsim-io headers, which force us to use the getters, at
# least when using cling(?). overlaySinglesIntoSpills.C directly accesses the
# fields. So we apparently must use headers produced by MakeProject, but that
# would lead to a conflict with the ones from the edep-sim installation. Hence
# we unload the latter. Fun. See makeLibTG4Event.sh

libpath_remove /opt/generators/edep-sim/install/lib

[ -z "${ND_PRODUCTION_SPILL_POT}" ] && export ND_PRODUCTION_SPILL_POT=5e13
[ -z "${ND_PRODUCTION_SPILL_PERIOD}" ] && export ND_PRODUCTION_SPILL_PERIOD=1.2
[ -z "${ND_PRODUCTION_REUSE_ROCK}" ] && export ND_PRODUCTION_REUSE_ROCK=0

if [[ "$ND_PRODUCTION_USE_GHEP_POT" == "1" ]]; then
  # Covering the case that we want to use the GHEP POT but build only
  # fiducial or only rock spills. For example, to build fiducial 
  # only spills, ND_PRODUCTION_ROCK_POT is set to zero.
  if [[ "$ND_PRODUCTION_NU_POT" != "0" && -n "$ND_PRODUCTION_NU_POT" ]]; then
    echo "Setting ND_PRODUCTION_NU_POT to a non-zero value while also using GHEP POT via"
    echo "ND_PRODUCTION_USE_GHEP_POT is inconsistent. Please refactor..."
    exit
  elif [[ "$ND_PRODUCTION_NU_POT" == "0" ]]; then
    echo "ND_PRODUCTION_NU_POT is set to zero - spills will be rock only."
  else
    read -r ND_PRODUCTION_NU_POT < "$nuInDir"/POT/$subDir/"$nuName".pot
  fi
  if [[ "$ND_PRODUCTION_ROCK_POT" != "0" && -n "$ND_PRODUCTION_ROCK_POT" ]]; then
    echo "Setting ND_PRODUCTION_ROCK_POT to a non-zero value while also using GHEP POT via"
    echo "ND_PRODUCTION_USE_GHEP_POT is inconsistent. Please refactor..."
    exit
  elif [[ "$ND_PRODUCTION_ROCK_POT" == "0" ]]; then
    echo "ND_PRODUCTION_NU_ROCK is set to zero - spills will be fiducial only."
  else
    read -r ND_PRODUCTION_ROCK_POT < "$rockInDir"/POT/$rockSubDir/"$rockName".pot
  fi
fi

# run root -l -b -q \
#     -e "gInterpreter->AddIncludePath(\"libTG4Event\")" \
#     "overlaySinglesIntoSpills.C(\"$nuInFile\", \"$rockInFile\", \"$spillFile\", $ND_PRODUCTION_NU_POT, $ND_PRODUCTION_ROCK_POT, $ND_PRODUCTION_SPILL_POT)"

# run root -l -b -q \
#     -e "gSystem->Load(\"libTG4Event/libTG4Event.so\")" \
#     "overlaySinglesIntoSpills.C(\"$nuInFile\", \"$rockInFile\", \"$spillFile\", $ND_PRODUCTION_NU_POT, $ND_PRODUCTION_ROCK_POT, $ND_PRODUCTION_SPILL_POT)"

# LIBTG4EVENT_DIR is provided by the podman-built containers
# If unset, fall back to the local build provided by install_spill_build.sh
LIBTG4EVENT_DIR=${LIBTG4EVENT_DIR:-libTG4Event}

run root -l -b -q \
     -e  "gSystem->Load(\"libPhysics.so\"); \
          gSystem->Load(\"libEG.so\"); \
          gSystem->Load(\"/opt/generators/genie/lib/libGFwMsg-3.04.00.so\"); \
          gSystem->Load(\"/opt/generators/genie/lib/libGFwReg-3.04.00.so\"); \
          gSystem->Load(\"/opt/generators/genie/lib/libGFwParDat-3.04.00.so\"); \
          gSystem->Load(\"/opt/generators/genie/lib/libGFwAlg-3.04.00.so\"); \
          gSystem->Load(\"/opt/generators/genie/lib/libGFwUtl-3.04.00.so\"); \
          gSystem->Load(\"$LIBTG4EVENT_DIR/libTG4Event.so\"); " \
    "/opt/generators/dk2nu/scripts/load_dk2nu.C(true,true)" \
    "overlayWithNuIntTime.cpp(\"$nuInFile\", \"$rockInFile\", \"$spillFile\", \"$ghepFile\", $ND_PRODUCTION_INDEX, $ND_PRODUCTION_NU_POT, $ND_PRODUCTION_ROCK_POT, $ND_PRODUCTION_SPILL_POT, $ND_PRODUCTION_SPILL_PERIOD, $ND_PRODUCTION_HADD_FACTOR)"
    # "overlaySinglesIntoSpillsSorted.C(\"$nuInFile\", \"$rockInFile\", \"$spillFile\", $ND_PRODUCTION_INDEX, $ND_PRODUCTION_NU_POT, $ND_PRODUCTION_ROCK_POT, $ND_PRODUCTION_SPILL_POT, $ND_PRODUCTION_SPILL_PERIOD)"

# run root -l -b -q \
#      -e  "gSystem->Load(\"$LIBTG4EVENT_DIR/libTG4Event.so\")" \
#     "overlaySinglesIntoSpillsSorted.C(\"$nuInFile\", \"$rockInFile\", \"$spillFile\", $ND_PRODUCTION_INDEX, $ND_PRODUCTION_NU_POT, $ND_PRODUCTION_ROCK_POT, $ND_PRODUCTION_SPILL_POT, $ND_PRODUCTION_SPILL_PERIOD, $ND_PRODUCTION_REUSE_ROCK)"
    
mkdir -p "$outDir/EDEPSIM_SPILLS/$subDir"
mv "$spillFile" "$outDir/EDEPSIM_SPILLS/$subDir"


