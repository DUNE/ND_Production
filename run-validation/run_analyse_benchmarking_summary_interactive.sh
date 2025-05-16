#!/bin/bash


module load python

source validation.venv/bin/activate


BASEDIR=/pscratch/sd/d/dunepro/abooth/logs/MicroProdN4p1/
OUTDIR=`pwd`
mkdir -p $OUTDIR


python analyse_benchmarking_summary.py --base_dir $BASEDIR --out_dir $OUTDIR

