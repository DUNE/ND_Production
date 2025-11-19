#!/usr/bin/env python3

import argparse
from functools import lru_cache
import json
from multiprocessing import Pool
import os
from pathlib import Path


ARGS = None


def strip_exts(filename, n_exts):
    "Strip `n_exts` extensions from a filename"
    for i in range(n_exts):
        filename = Path(filename).stem
    return filename


def flow2raw(flow_path):
    # Assume our flow file ends in e.g. .v11.FLOW.hdf5
    filename =  Path(flow_path).name.replace('packet-', 'binary-')
    return strip_exts(filename, 3) + '.hdf5'


def packet2raw(packet_path):
    return Path(packet_path).name.replace('packet-', 'binary-') \
                                 .replace('.h5', '.hdf5')


def packet2flow(packet_path):
    return Path(packet_path).name.replace('.h5', '.FLOW_v0.hdf5')


def reco2flow(path: Path):
    assert path.name.endswith('.LAR_RECO_ND.root') \
        or path.name.endswith('.MLRECO_SPINE.hdf5')
    basename = Path(path.stem).stem
    return f'{basename}.FLOW.hdf5'


def caf2basename(path: Path):
    if path.name.endswith('.CAF.root'):
        return Path(path.stem).stem
    elif path.name.endswith('.CAF.flat.root'):
        return Path(Path(path.stem).stem).stem # im(so(sorry.for).my).code


def caf2pandora(path: Path):
    basename = caf2basename(path)
    return f'{basename}.LAR_RECO_ND.root'


def caf2spine(path: Path):
    basename = caf2basename(path)
    return f'{basename}.MLRECO_SPINE.hdf5'


def caf2flow(path: Path):
    basename = caf2basename(path)
    return f'{basename}.FLOW.hdf5'


def caf2raw(path: Path):
    return flow2raw(caf2flow(path))


@lru_cache
def read_filelist():
    "Returns a dict that maps raw charge filenames to the associated light/Mx2 data"
    result = {}
    groups = json.load(open(ARGS.filelist))

    for group in groups:
        pktfile = group['ND_PRODUCTION_CHARGE_FILE']
        if not pktfile:
            continue
        lfiles = [Path(p).name
                  for p in group['ND_PRODUCTION_LIGHT_FILES'].split()]
        rawfile = packet2raw(pktfile)
        result[rawfile] = {'light': lfiles}

        if 'ND_PRODUCTION_MINERVA_FILES' in group:
            mx2files = [Path(p).name
                        for p in group['ND_PRODUCTION_MINERVA_FILES'].split()]
            result[rawfile]['minerva'] = mx2files

    return result


def get_parents(path):
    if ARGS.stage == 'flow':
        rawfile = flow2raw(path)
        rawdata = read_filelist()[rawfile]
        lfiles = rawdata['light']
        parents = [f'neardet-2x2-lar-charge:{rawfile}',
                   *[f'neardet-2x2-lar-light:{lfile}' for lfile in lfiles]]

        if 'minerva' in rawdata:
            parents.extend(f'neardet-2x2-minerva:{mx2file}'
                           for mx2file in rawdata['minerva'])

    elif ARGS.stage in ['pandora', 'spine']:
        flowfile = reco2flow(path)
        parents = [f'neardet-2x2-lar:{flowfile}']

    elif ARGS.stage in ['caf', 'caf_flat']:
        pandora = caf2pandora(path)
        spine = caf2spine(path)
        parents = [f'neardet-2x2-lar:{pandora}', f'neardet-2x2-lar:{spine}']

        rawdata = read_filelist()[caf2raw(path)]
        if 'minerva' in rawdata:
            parents.extend(f'neardet-2x2-minerva:{mx2file}'
                           for mx2file in rawdata['minerva'])

    return ','.join(parents)


def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dir', type=Path, required=True)
    ap.add_argument('--filelist', type=Path, required=True,
                    help=('JSON file with groupings of light/charge/Mx2 files. ' +
                          'See gen_input_list.py from ndlar_reflow.'))
    ap.add_argument('--ext', default='hdf5', help='File extension to scan for')
    ap.add_argument('--config', choices=['proto_nd', 'fsd'], required=True)
    ap.add_argument('--period', default='run1')
    ap.add_argument('--stage', choices=['flow', 'pandora', 'spine', 'caf', 'caf_flat'])
    # Need to add spine:
    # NB: reco = caf; calibrated = spine/pandora:
    ap.add_argument('--release', help='Software release', required=True)
    ap.add_argument('--replace', action='store_true',
                    help='Replace existing metadata')
    ap.add_argument('--parallel', type=int, default=1,
                    help='Number of parallel processes')
    global ARGS
    ARGS = ap.parse_args()


def get_tier():
    m = {'flow': 'flow',
         'pandora': 'reco_pandora',
         'spine': 'reco_spine',
         'caf': 'caf',
         'caf_flat': 'caf'}
    return m[ARGS.stage]


def get_workflow():
    m = {'flow': 'combined',
         'pandora': 'pandora',
         'spine': 'spine',      # TODO: Add support to MetadataExtract.py
         'caf': 'cafmaker',
         'caf_flat': 'cafmaker_flat'}
    return m[ARGS.stage]


def get_stream():
    m = {'flow': 'combined',
         'pandora': 'calibrated',
         'spine': 'calibrated',
         'caf': 'reco',
         'caf_flat': 'reco'}
    return m[ARGS.stage]


def get_namespace():
    if ARGS.stage in ['caf', 'caf_flat']:
        return 'neardet-2x2'
    else:
        return 'neardet-2x2-lar'


def get_ext():
    if ARGS.stage in ['flow', 'spine']:
        return 'hdf5'
    else:
        return 'root'


def set_environ():
    os.environ.update(
        {'DETECTOR_CONFIG': ARGS.config,
         'RUN_PERIOD': ARGS.period,
         'DATA_TIER': get_tier(),
         'DATA_STREAM': get_stream(),
         'TWOBYTWO_RELEASE': ARGS.release})


def gen_metadata(path):
    parents = get_parents(path)
    cmd = f'python MetadataExtract.py --input {path} --parents {parents}'
    cmd += f' --workflow {get_workflow()} --tier {get_tier()}'
    cmd += f' --namespace {get_namespace()}'
    print(cmd)
    os.system(cmd)


def main():
    parse_args()
    set_environ()
    pool = Pool(ARGS.parallel)
    paths = []

    for path in Path(ARGS.dir).rglob(f'*.{get_ext()}'):
        jsonpath = path.with_suffix(path.suffix + '.json')
        if jsonpath.exists() and not ARGS.replace:
            continue
        print(f'Queuing: {path}')
        gen_metadata(path)
        # paths.append(path)

    # pool.map(gen_metadata, paths)


if __name__ == '__main__':
    main()
