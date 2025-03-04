#!/usr/bin/env bash

export ARCUBE_CONTAINER=${ARCUBE_CONTAINER:-mjkramer/sim2x2:ndlar011}

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

printf -v CORSIKA_OUTPUT "DAT%.6d" ${runNo}

./corsikaConverter.exe ${CORSIKA_OUTPUT}

mkdir -p "$outDir/CORSIKA/$subDir"
mv ${CORSIKA_OUTPUT}.root ${outDir}/CORSIKA/${subDir}/${outName}.CORSIKA.root
mv ${CORSIKA_OUTPUT} ${outDir}/CORSIKA/${subDir}/${outName}.CORSIKA.dat
