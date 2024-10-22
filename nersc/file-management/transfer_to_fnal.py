#!/usr/bin/env python


# A script to transfer files from some source directory at NERSC
# to (by default) the ND dropbox at FNAL. Should be run at the 
# NERSC data transfer nodes ($USER@dtn0{1..4}.nersc.gov).


import argparse
import os


parser = argparse.ArgumentParser()
parser.add_argument("--ignore-jsons", required=False, action='store_true', help="Dont copy corresponding jsons.")
parser.add_argument("--destination-base", default="root://fndca1.fnal.gov/pnfs/fnal.gov/usr/dune/scratch/dunepro/dropbox/neardet", help="Base directory that files will be sent to.")
parser.add_argument("--dry-run", required=False, action='store_true', help="Utilise --dry-run in gfal-copy commands - dont make directories.")
parser.add_argument("--extensions", required=False, type=str, nargs='*', help="Specify file extensions that should be copied. Not specifying will copy everything.")
parser.add_argument("--extensions-ignore", required=False, type=str, nargs='*', help="Specify file extensions that should be ignored. Not specifying will copy everything.")
parser.add_argument("--maintain-structure-below", required=False, help="Directories of destination-base that will not appear in destionation directory structure.")
parser.add_argument("--print-only", required=False, action='store_true', help="Only print the gfal-cp command, dont execute.")
parser.add_argument("--source-base", required=True, help="Base directory below which all files will be sent to destination-base.")
parser.add_argument("--timeout", type=int, default=86400, help="Set timeout for gfal-copy (seconds).")


args = parser.parse_args()


dry_run = "--dry-run " if args.dry_run else ""
timeout = "--timeout " + str(args.timeout) + " "

if not args.maintain_structure_below:
    maintain_structure_below = args.source_base
else:
    maintain_structure_below = args.maintain_structure_below


# Pull together the sources and sinks.
transfer_pairs = []
for base, _, files in os.walk(args.source_base):
    if not files: continue

    for file in files:
        if args.extensions and not any([extension in file for extension in args.extensions]): continue
        if args.extensions_ignore and any([extension in file for extension in args.extensions_ignore]): continue
        if ".json" in file: continue

        index_candidates = [ splt for splt in file.split(".") if splt.isdigit() ]
        if not len(index_candidates) == 1:
            raise Exception("Cant find a index for following file and dont know how to handle that, bailing!\n"+file)
        # We want O (100) files in each /pnfs directory.
        group_index = index_candidates[0][:-2]
        group_directory = group_index.ljust(len(index_candidates[0]), "0")

        destination_path = [args.destination_base, base.split(maintain_structure_below)[-1].lstrip('/').rstrip('/'), group_directory, file]
        transfer_pairs.append([os.path.join(base,file),os.path.join(*destination_path)])
        
        # Deal with jsons.
        if args.ignore_jsons:
            continue

        this_json_source = os.path.splitext(transfer_pairs[-1][0])[0] + ".json"
        this_json_dest = os.path.splitext(transfer_pairs[-1][1])[0] + ".json"
        if not os.path.isfile(this_json_source): 
            raise Exception("Cant find a json for the following file, this will cause issues later, bailing!\n"+file)

        transfer_pairs.append([this_json_source, this_json_dest])


# Do the transfers.
for pair in transfer_pairs:
    cmd = "gfal-copy " + dry_run + timeout + pair[0] + " " + pair[1]
    if not args.print_only:
        os.system(cmd)
    else:
        print(cmd)


print("\n\n\nALL DONE!!!\n\n\n")
