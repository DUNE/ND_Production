#!/usr/bin/env bash

source ../util/init.inc.sh

echo "Running CORSIKA..."
run ./run_corsika.sh

echo "Running conversion..."
run ./run_convert.sh
