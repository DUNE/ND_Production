#!/usr/bin/env python3

import argparse
from pathlib import Path
from subprocess import DEVNULL, check_call
from tempfile import TemporaryDirectory

import h5py
import numpy as np


def run_light_build(lightf: Path, outdir: Path, workflow: Path) -> Path:
    outf = outdir / (lightf.stem + '.hdf5')
    cmd = ['h5flow', '-i', lightf, '-o', outf, '-c', workflow]
    check_call(cmd, stdout=DEVNULL)
    return outf


def get_limits(cf: h5py.File, first_lf: h5py.File, last_lf: h5py.File) \
        -> tuple[int, int]:
    """Based on the time range of the charge file `cf`, returns --start_position
       for the light file `first_lf` and --end_position for the light file
       `last_lf`. `first_lf` and `last_lf` may be the same file. """
    pkts = cf['packets']
    tstamps_c = pkts[pkts['packet_type'] == 4]['timestamp']
    tmin_c, tmax_c = np.min(tstamps_c), np.max(tstamps_c)

    def get_light_tstamps(lf: h5py.File):
        evts = lf['light/events/data']
        return evts['utime_ms'][:, 0] / 1000

    tstamps_first_l = get_light_tstamps(first_lf)
    tstamps_last_l = get_light_tstamps(last_lf)

    # Note: h5flow's --end-position is "exclusive", i.e. --start_position 0,
    # --end_position 5 means process events 0, 1, 2, 3, 4. Thus the "+1" in
    # calculating end_pos.
    start_pos = np.where(tstamps_first_l >= tmin_c)[0][0]
    end_pos = np.where(tstamps_last_l <= tmax_c)[0][-1] + 1
    return start_pos, end_pos


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--workflow', type=Path, required=True,
                    help='light event building yaml')
    ap.add_argument('--chargef', type=Path, required=True)
    ap.add_argument('--first-lightf', type=Path, required=True)
    ap.add_argument('--last-lightf', type=Path,
                    help='May be the same as --first-lightf')
    ap.add_argument('--tmpdir', default='/tmp')
    args = ap.parse_args()

    outdir_obj = TemporaryDirectory(dir=args.tmpdir)
    outdir = Path(outdir_obj.name)

    first_lightf_built = \
        run_light_build(args.first_lightf, outdir, args.workflow)
    first_lightf_built_h5 = h5py.File(first_lightf_built)

    if args.last_lightf and args.last_lightf != args.first_lightf:
        last_lightf_built = \
            run_light_build(args.last_lightf, outdir, args.workflow)
        last_lightf_built_h5 = h5py.File(last_lightf_built)
    else:
        last_lightf_built_h5 = first_lightf_built_h5

    chargef_h5 = h5py.File(args.chargef)

    start_pos, end_pos = get_limits(chargef_h5,
                                    first_lightf_built_h5,
                                    last_lightf_built_h5)

    print(start_pos, end_pos)


if __name__ == '__main__':
    main()
