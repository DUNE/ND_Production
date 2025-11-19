#!/usr/bin/env python3

import argparse
from pathlib import Path
import pickle
import json


def patch_subrun(md: dict):
    subrun = md['metadata']['core.runs_subruns'][0]
    run = subrun // 10000
    rel_subrun = subrun % 10000
    new_subrun = run * 100000 + rel_subrun
    md['metadata']['core.runs_subruns'][0] = new_subrun


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
        if not (p.parent / p.stem).exists():
            continue
        with open(p) as f:
            try:
                md = json.load(f)
            except:
                print(f'YUCK: {f}')
                continue
        fname = Path(p.stem).with_suffix('.hdf5').as_posix()
        md['name'] = fname
        patch_subrun(md)
        tbl[fname] = md

    tbl = result['neardet-2x2-lar-light']
    for p in Path(args.light_dir).rglob('*.json'):
        if not (p.parent / p.stem).exists():
            continue
        with open(p) as f:
            try:
                md = json.load(f)
            except:
                print(f'YUCK: {f}')
                continue
        fname = p.stem
        fname = fname.replace('mpd_run_data', 'mpd_run_run2data')
        md['name'] = fname
        patch_subrun(md)
        tbl[fname] = md

    with open(args.output_file, 'wb') as f:
        pickle.dump(result, f)


if __name__ == '__main__':
    main()
