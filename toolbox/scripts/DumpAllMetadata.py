#!/usr/bin/env python3

import argparse
from functools import lru_cache
import json
from multiprocessing import Pool
import os
from pathlib import Path


ARGS = None


def flow2raw(flow_path):
    return Path(flow_path).name.replace('packet-', 'binary-') \
                               .replace('.FLOW.hdf5', '.hdf5')


def packet2raw(packet_path):
    return Path(packet_path).name.replace('packet-', 'binary-') \
                                 .replace('.h5', '.hdf5')


def packet2flow(packet_path):
    return Path(packet_path).name.replace('.h5', '.FLOW.hdf5')


@lru_cache
def get_parents_dict():
    result = {}
    groups = json.load(open(ARGS.filelist))
    for group in groups:
        pktfile = group['ND_PRODUCTION_CHARGE_FILE']
        flowfile = packet2flow(pktfile)
        rawfile = packet2raw(pktfile)
        lfiles = [Path(p).name
                  for p in group['ND_PRODUCTION_LIGHT_FILES'].split()]
        parents = [f'neardet-2x2-lar-charge:{rawfile}',
                   *[f'neardet-2x2-lar-light:{lfile}' for lfile in lfiles]]
        result[flowfile] = ','.join(parents)
    return result


def get_parents(path):
    return get_parents_dict()[path.name]


def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dir', type=Path, required=True)
    ap.add_argument('--filelist', type=Path, required=True,
                    help='JSON file with groupings of light/charge/Mx2 files')
    ap.add_argument('--ext', default='hdf5', help='File extension to scan for')
    ap.add_argument('--config', choices=['proto_nd', 'fsd'], required=True)
    ap.add_argument('--period', default='run1')
    ap.add_argument('--tier', choices=['flow', 'reco_pandora', 'reco_spine', 'caf'],
                    default='flow')
    # Need to add spine:
    ap.add_argument('--workflow', choices=['combined', 'pandora', 'cafmaker', 'cafmaker_flat'],
                    default='combined')
    # NB: reco = caf; calibrated = spine/pandora:
    ap.add_argument('--stream', choices=['combined', 'calibrated', 'reco'],
                    default='combined')
    ap.add_argument('--release', help='Software release', required=True)
    ap.add_argument('--namespace', default='neardet-2x2-lar')
    ap.add_argument('--replace', action='store_true',
                    help='Replace existing metadata')
    ap.add_argument('--parallel', type=int, default=1,
                    help='Number of parallel processes')
    global ARGS
    ARGS = ap.parse_args()


def set_environ():
    os.environ.update(
        {'DETECTOR_CONFIG': ARGS.config,
         'RUN_PERIOD': ARGS.period,
         'DATA_TIER': ARGS.tier,
         'DATA_STREAM': ARGS.stream,
         'TWOBYTWO_RELEASE': ARGS.release})


def gen_metadata(path):
    parents = get_parents(path)
    cmd = f'python MetaDataExtract.py --input {path} --parents {parents}'
    cmd += f' --workflow {ARGS.workflow} --tier {ARGS.tier}'
    cmd += f' --namespace {ARGS.namespace}'
    print(cmd)
    os.system(cmd)


def main():
    parse_args()
    set_environ()
    pool = Pool(ARGS.parallel)
    paths = []

    for path in Path(ARGS.dir).rglob(f'*.{ARGS.ext}'):
        jsonpath = path.with_suffix(path.suffix + '.json')
        if jsonpath.exists() and not ARGS.replace:
            continue
        print(f'Queuing: {path}')
        paths.append(path)

    pool.map(gen_metadata, paths)


if __name__ == '__main__':
    main()
