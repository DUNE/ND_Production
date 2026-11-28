#!/usr/bin/env python3

import argparse
from collections import defaultdict
import json
import sqlite3


def get_friends(conn: sqlite3.Connection, basis='charge', include_mx2=False):
    """
    Returns a dict where the keys are charge files (if basis is 'charge') or
    light files (if basis is 'light'), and the values are dicts with keys:
      'FRIENDS', a list of the corresponding light (or charge) files,
      'MINERVA', a list of the Mx2 files (if include_mx2 is True)
    """
    assert basis in ['charge', 'light']

    mx2_cols, mx2_join, mx2_order = '', '', ''
    if include_mx2:
        mx2_cols = ', m.nersc_path'
        mx2_join = "LEFT JOIN Mx2_summary m ON (a.mx2_run = m.run AND a.mx2_subrun = m.subrun)"
        mx2_order = ', mx2_run, mx2_subrun'

    q = f"SELECT c.nersc_path, l.nersc_path {mx2_cols} from All_global_subruns a" + \
        f" JOIN CRS_summary c ON (a.crs_run = c.run AND a.crs_subrun = c.subrun)" + \
        f" LEFT JOIN LRS_summary l ON (a.lrs_run = l.run AND a.lrs_subrun = l.subrun)" + \
        f" {mx2_join}" + \
        f" ORDER BY crs_run, crs_subrun, lrs_run, lrs_subrun {mx2_order}"

    friends = {}

    for row in conn.execute(q):
        crs_path, lrs_path = row[:2]
        if basis == 'charge':
            base_path, friend_path = crs_path, lrs_path
        else:
            base_path, friend_path = lrs_path, crs_path
        if base_path is None:
            continue
        if base_path not in friends:
            friends[base_path] = defaultdict(list)
        if friend_path and friend_path not in friends[base_path]['FRIENDS']:
            friends[base_path]['FRIENDS'].append(friend_path)
        if include_mx2:
            mx2_path = row[2]
            if mx2_path and mx2_path not in friends[base_path]['MINERVA']:
                friends[base_path]['MINERVA'].append(mx2_path)

    return friends


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('-d', '--db-file',
                    help='RunDB sqlite file',
                    required=True)
    ap.add_argument('-o', '--output',
                    help='Output json file',
                    required=True)
    ap.add_argument('-b', '--basis', choices=['charge', 'light'], required=True,
                    help='Whether each output should correspond to a charge or a light file')
    ap.add_argument('-m', '--include-mx2', action='store_true')
    args = ap.parse_args()

    result = []

    conn = sqlite3.connect(args.db_file)
    friend_map = get_friends(conn, args.basis, args.include_mx2)

    if args.basis == 'charge':
        base_key, friend_key = 'ND_PRODUCTION_CHARGE_FILES', 'ND_PRODUCTION_LIGHT_FILES'
    else:
        base_key, friend_key = 'ND_PRODUCTION_LIGHT_FILES', 'ND_PRODUCTION_CHARGE_FILES'

    for base_path, friends in friend_map.items():
        friend_paths = friends['FRIENDS']
        spec = {
            base_key: base_path,
            # hope there ain't no spaces in them paths
            friend_key: ' '.join(friend_paths) if friend_paths else '',
        }
        if args.include_mx2:
            mx2_paths = friends['MINERVA']
            spec['ND_PRODUCTION_MINERVA_FILES'] = ' '.join(mx2_paths) if mx2_paths else ''
        result.append(spec)

    with open(args.output, 'w') as f:
        json.dump(result, f, indent=4)

    conn.close()


if __name__ == '__main__':
    main()
