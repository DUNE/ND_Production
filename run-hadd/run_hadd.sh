#!/usr/bin/env bash

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-mjkramer/sim2x2:ndlar011}

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

# e.g. hadd'ed file 123 comes from genie files 1230 -> 1239
# so the input (GENIE) subdir is 0001200, an ND_PRODUCTION_HADD_FACTOR of 10 is assumed.
if [ "$ND_PRODUCTION_HADD_FACTOR" != "10" ]; then  
  echo "For now, ND_PRODUCTION_HADD_FACTOR must be 10."
  exit
fi
inSubDir=$(printf "%07d" $((ND_PRODUCTION_INDEX / 100 * 1000)))
inDir=${ND_PRODUCTION_OUTDIR_BASE}/run-edep-sim/$ND_PRODUCTION_IN_NAME/EDEPSIM/$inSubDir
tmpfile=$(mktemp)
tmpfileghep=$(mktemp)

for i in $(seq 0 $((ND_PRODUCTION_HADD_FACTOR - 1))); do
    inIdx=$((ND_PRODUCTION_INDEX*ND_PRODUCTION_HADD_FACTOR + i))
    inName=$ND_PRODUCTION_IN_NAME.$(printf "%07d" "$inIdx")
    inFile="$inDir"/"$inName".EDEPSIM.root
    if [[ "$ND_PRODUCTION_USE_GHEP_POT" == "1" ]]; then
        if [ -f "$inFile" ]; then
            ghepFile=${inFile//.edep./.genie.}
            ghepFile=${ghepFile//run-edep-sim/run-genie}
            ghepFile=${ghepFile//EDEPSIM/GHEP}
            echo "$ghepFile" >> "$tmpfileghep"
        else
            continue
        fi
    fi
    echo "$inFile" >> "$tmpfile"
done


if [[ "$ND_PRODUCTION_USE_GHEP_POT" == "1" ]]; then
    libpath_remove /opt/generators/GENIE/R-3_04_00/lib

    potFile=$tmpOutDir/${outName}.pot
    rm -f "$potFile"

    run ./getGhepPOT.exe "$tmpfileghep" "$potFile"
    rm "$tmpfileghep"
fi


outFile=$tmpOutDir/${outName}.EDEPSIM.root
rm -f "$outFile"

run hadd "$outFile" "@$tmpfile"

rm "$tmpfile"

mkdir -p "$outDir/EDEPSIM/$subDir"
mv "$outFile" "$outDir/EDEPSIM/$subDir"

if [[ "$ND_PRODUCTION_USE_GHEP_POT" == "1" ]]; then
    mkdir -p "$outDir/POT/$subDir"
    mv "$potFile" "$outDir/POT/$subDir"
fi
