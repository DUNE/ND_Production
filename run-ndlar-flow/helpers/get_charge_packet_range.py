#!/usr/bin/env python3

import argparse
from pathlib import Path
from subprocess import DEVNULL, check_call
from tempfile import TemporaryDirectory

import h5py
import numpy as np


def get_limits(lf: h5py.File, first_cf: h5py.File, last_cf: h5py.File,
               start_padding=0, end_padding=0) \
        -> tuple[int, int]:
    """Based on the time range of the light file `lf`, returns --start_position
    for the charge file `first_cf` and --end_position for the charge file
    `last_cf`. `first_cf` and `last_cf` may be the same file.
    """
    # Get unix time of first/last light event
    l_evts = lf['light/events/data']
    utime = l_evts['utime_ms'][[0, -1]] // 1000 # shape (2, n_adc)
    # Sanity check that all ADCs are in agreement
    assert np.all(utime == utime[:, 0][:, np.newaxis])
    t0, t1 = utime[:, 0]

    # Get corresponding indices in the packets
    pkts = first_cf['packets']
    pkt_type, tstamp = pkts['packet_type'][:], pkts['timestamp'][:]
    i0 = np.argmax((pkt_type == 4) & (tstamp >= t0))

    if last_cf is not first_cf:
        pkts = last_cf['packets']
        pkt_type, tstamp = pkts['packet_type'][:], pkts['timestamp'][:]
    i1 = np.argmax((pkt_type == 4) & (tstamp > t1))

    i0 = max(i0 - start_padding, 0)
    i1 = min(i1 + end_padding, len(pkts))
    return i0, i1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--lightf', type=Path, required=True,
                    help='Flowed light file')
    ap.add_argument('--first-chargef', type=Path, required=True,
                    help='Packet file')
    ap.add_argument('--last-chargef', type=Path,
                    help='May be the same as --first-chargef')
    ap.add_argument('--start-padding', default=0)
    ap.add_argument('--end-padding', default=0)
    args = ap.parse_args()

    first_chargef_h5 = h5py.File(args.first_chargef)

    if args.last_chargef and args.last_chargef != args.first_chargef:
        last_chargef_h5 = h5py.File(args.last_chargef)
    else:
        last_chargef_h5 = first_chargef_h5

    lightf_h5 = h5py.File(args.lightf)

    start_pos, end_pos = get_limits(lightf_h5, first_chargef_h5, last_chargef_h5,
                                    args.start_padding, args.end_padding)

    print(start_pos, end_pos)


if __name__ == '__main__':
    main()
