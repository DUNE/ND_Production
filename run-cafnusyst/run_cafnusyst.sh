#!/usr/bin/env bash

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-fermilab/fnal-wn-el9:latest}

export ND_PRODUCTION_DIR=${ND_PRODUCTION_DIR:-$(realpath "$PWD"/..)}
export SHIFTER_BIND_DIR="${ND_PRODUCTION_DIR}/run-cafnusyst/install:/home"
source ../util/reload_in_container.inc.sh

source setup_cafnusyst.sh

source ../util/init.inc.sh

# ND_PRODUCTION_NUSYST_CONFIG: the cafnusyst/nusystematics config (yaml)
# naming which knobs to reweight, resolved relative to this directory unless
# given as an absolute path.
# TODO: no config has been finalized for production use yet; the default
# below is a placeholder and must be replaced once one is agreed on.
export ND_PRODUCTION_NUSYST_CONFIG=${ND_PRODUCTION_NUSYST_CONFIG:-default_nusyst_config.yaml}
configFile=$ND_PRODUCTION_NUSYST_CONFIG
[[ "$configFile" != /* ]] && configFile=$PWD/$configFile

if [[ ! -f "$configFile" ]]; then
    echo "FATAL: nusyst config file $configFile does not exist." >&2
    exit 1
fi

inDir=${ND_PRODUCTION_OUTDIR_BASE}/${ND_PRODUCTION_IN_STAGE}/${ND_PRODUCTION_IN_NAME}
inName=$ND_PRODUCTION_IN_NAME.$globalIdx
inputCafFile=${inDir}/CAF/${subDir}/${inName}.CAF.root

outFile=${tmpOutDir}/${outName} # cafnusyst adds the .root itself
rm -f $outFile
echo "outFile is $outFile"

# UpdateReweight takes a text file listing its input file(s), not the CAF
# file directly.
inputList=$(mktemp)
echo "$inputCafFile" > "$inputList"

run UpdateReweight -c "$configFile" -i "$inputList" -o "$outFile" --make_nested

rm -f "$inputList"

cafOutDir=$outDir/CAF/$subDir
flatOutDir=$outDir/CAF.flat/$subDir
mkdir -p $cafOutDir $flatOutDir
mv "$outFile".cafnusyst.nested.root "$cafOutDir"
mv "$outFile".cafnusyst.flat.root "$flatOutDir"

echo "run_cafnusyst.sh finished: $outFile"

