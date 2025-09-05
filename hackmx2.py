#!/usr/bin/env python3

import argparse
import json
from pathlib import Path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('mx2_list_file')
    ap.add_argument('input_json')
    ap.add_argument('output_json')
    args = ap.parse_args()

    mapper = {}
    for l in open(args.mx2_file_list):
        raw_fname = l.strip()
        prefix = '_'.join(raw_fname.split('_')[:5])
        mapper[prefix] = raw_fname

    the_json = json.read(open(args.input_json))

    for i, rec in the_json:
        dst_files = rec['ND_PRODUCTION_MINERVA_FILES'].split()
        raw_files = []
        for dst_file in dst_files:
            prefix = '_'.join(dst_File.split('_')[:5])
            raw_files.append(mapper[prefix])
        rec['ND_PRODUCTION_MINERVA_FILES'] = ' '.join(raw_files)

    json.dump(the_json, open(args.output_json, 'w'), indent=4)


if __name__ == '__main__':
    main()
