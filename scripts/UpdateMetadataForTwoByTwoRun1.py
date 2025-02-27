#!/bin/env python

import os, sys, string, re, shutil, math, time, subprocess, json
import datetime as dt

import sqlite3

from pathlib import Path
from argparse import ArgumentParser as ap
from metacat.webapi import MetaCatClient


#+++++++++++++++++++++++++++++++++
# get the metacat client
#+++++++++++++++++++++++++++++++++
def _GetMetacatClient() :
    client = MetaCatClient(server_url='https://metacat.fnal.gov:9443/dune_meta_prod/app',
                           auth_server_url='https://metacat.fnal.gov:8143/auth/dune',
                           timeout=30)
    return client


#++++++++++++++++++++++++++++++++++++++++++++
# get the run info from the light file name
#+++++++++++++++++++++++++++++++++++++++++++
def _GetRunInfoFromLightFile(filename) :
    lrs2morcs = {87: 50001, 92: 50005, 93: 50006, 94: 50007, 96: 50009,
                 97: 50010, 104: 50017, 105: 50018}
    parts = Path(filename).stem.split('_')
    assert parts[5].startswith('p')
    lrs_run, lrs_subrun = int(parts[4]), int(parts[5][1:])
    morcs_run = lrs2morcs[lrs_run] if lrs_run in lrs2morcs else -1
    return morcs_run, lrs_subrun
  


#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# check the metadata via sqlite db
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
def _Update2x2Metadata(did) :

    sqlite_filename = "/cvmfs/minerva.opensciencegrid.org/minerva2x2/databases/mx2x2runs_v0.2_beta1.sqlite"

    try :
       connect = sqlite3.connect(f"file:{sqlite_filename}?mode=ro", uri=True)
       cursor  = connect.cursor()
    except sqlite3.Error as e :
       pass
       print(f"Error connecting to the sqlite database: {e}")    
       return []

    table_name = ""
    if did['metadata']['core.application.name'] == "crs_daq" :
       table_name = "CRS_summary"
    elif did['metadata']['core.application.name'] == "lrs_daq" : 
       table_name = "LRS_summary"

    updated_filename = did['name'].replace("hdf5","h5")

    cmd = "SELECT run,subrun FROM %s WHERE filename=\"%s\" " % (table_name,updated_filename)
    cursor.execute(cmd)
    results = cursor.fetchall()
    rvalue  = [result for ntuple in results for result in ntuple]

    connect.close()

    if len(rvalue) == 0 :
       if did['metadata']['core.application.name'] == "lrs_daq" :
          r,s = _GetRunInfoFromLightFile( did['name'] ) 
          if r == -1 :
             print( "Unable to get the run information for the runs database for filename [%s]" % did['name'] )
             return None
          else :
             rvalue.append(r)
             rvalue.append(s) 
       else : 
          print( "Unable to get the run information for the runs database for filename [%s]" % did['name'] )
          return None

    run = int(rvalue[0])
    sub = int(rvalue[1])

    runs_subruns = run*100000+sub
    
    updated_metadata = dict()
    updated_metadata['core.runs_subruns'] = [runs_subruns]

    return updated_metadata



#++++++++++++++++++++++++++++++++++++++++++++++++++++
# update the mx2 subruns metadata
#++++++++++++++++++++++++++++++++++++++++++++++++++++
def _UpdateMx2Metadata(did) :
    filename     = did['name']
    namespace    = did['namespace']
    run          = int(filename.split('_')[1])
    subrun       = int(filename.split('_')[2])
    runs_subruns = run*100000+subrun 

    updated_metadata = dict()
    updated_metadata['core.runs_subruns'] = [runs_subruns]

    return updated_metadata 



##########################################################################
#  main block for processing the data
##########################################################################
if __name__ == '__main__' :

   print( "Enter update the metadata of the files" )

   # input arguments
   parser = ap()
   parser.add_argument('--dataset', type=str, required=True, help='Name of the dataset')
   parser.add_argument('--update', action='store_true', help="Update the metadata with the correct value")

   args = parser.parse_args()

   # get the metacat client
   client = _GetMetacatClient()

   # get the files in the dataset 
   files_in_dataset = client.get_dataset_files(did=args.dataset, with_metadata=True) 

   # loop over files in dataset
   for d, dfile in enumerate(files_in_dataset) :
       if dfile['namespace'].find('neardet-2x2-minerva') != -1 :
          updated_metadata = _UpdateMx2Metadata(dfile)
       else : 
          updated_metadata = _Update2x2Metadata(dfile)

       if args.update :
          client.update_file(namespace=dfile['namespace'],name=dfile['name'],metadata=updated_metadata)
       else :
          print(updated_metadata)
         

   print( "Exit update 2x2 run1 metadata\n\n" )





