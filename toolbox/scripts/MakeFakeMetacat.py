#!/usr/bin/env python3

import argparse
from pathlib import Path
import pickle
import json


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('charge_dir')
    ap.add_argument('light_dir')
    ap.add_argument('output_file')
    args = ap.parse_args()

    result = {}
    result['neardet-2x2-lar-charge'] = {}
    result['neardet-2x2-lar-light'] = {}

    tbl = result['neardet-2x2-lar-charge']
    for p in Path(args.charge_dir).rglob('*.json'):
        with open(p) as f:
            md = json.load(f)
        fname = p.parent / p.stem.with_suffix('.hdf5')
        md['name'] = fname
        tbl[fname] = md

    tbl = result['neardet-2x2-lar-light']
    for p in Path(args.light_dir).rglob('*.json'):
        with open(p) as f:
            md =  json.load(f)
        fname = p.name
        fname = fname.replace('mpd_run_data', 'mpd_run_run2data')
        md['name'] = fname
        tbl[fname] = md

    with open(args.output_file, 'wb') as f:
        pickle.dump(result, f)


if __name__ == '__main__':
    main()
