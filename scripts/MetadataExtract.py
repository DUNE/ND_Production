#!/bin/env python

import os, sys, string, re, shutil, math, time, subprocess, json
import datetime as dt

import sqlite3
import h5py

from argparse import ArgumentParser as ap
from metacat.webapi import MetaCatClient

from collections import OrderedDict

#++++++++++++++++++++++++++++
# environment variables
#++++++++++++++++++++++++++++
PWD  = str(os.environ.get('PWD'))
USER = str(os.environ.get('USER'))
SOFTWARE   = str(os.environ.get('SOFTWARE'))
RUN_PERIOD = str(os.environ.get('RUN_PERIOD'))
DETECTOR_CONFIG       = str(os.environ.get('DETECTOR_CONFIG'))
DATA_STREAM           = str(os.environ.get('DATA_STREAM'))
LIGHT_CONFIG_FILES    = str(os.environ.get('LIGHT_CONFIG_FILES'))
CHARGE_CONFIG_FILES   = str(os.environ.get('CHARGE_CONFIG_FILES'))
COMBINED_CONFIG_FILES = str(os.environ.get('COMBINED_CONFIG_FILES'))
JUSTIN_WORKFLOW = "justin workflow [%s, %s]" % ( str(os.environ.get('JUSTIN_WORKFLOW_ID')), str(os.environ.get('JUSTIN_SITE_NAME')) )

#+++++++++++++++++++++++++++++++++
# get the metacat client
#+++++++++++++++++++++++++++++++++
def _GetMetacatClient() :
    client = MetaCatClient(server_url='https://metacat.fnal.gov:9443/dune_meta_prod/app',
                           auth_server_url='https://metacat.fnal.gov:8143/auth/dune',
                           timeout=30)
    return client


#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# get the mx2x2 global subrun number via sqlite db
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
def _GetGlobalSubrun(metadata) :

    filename = ""
    if RUN_PERIOD == "run1" :
       if DETECTOR_CONFIG == "proto_nd" :
          filename = "/cvmfs/minerva.opensciencegrid.org/minerva2x2/databases/mx2x2runs_v0.2_beta1.sqlite"
       else :
          print("The detector configuration [%s] is unknown." % DETECTOR_CONFIG)
          return []
    else :
       print("The run period [%s] is not implemented." % RUN_PERIOD)
       return []

    try :
       cmd     = "file:%s?mode=ro" % filename
       connect = sqlite3.connect(cmd, uri=True)
       cursor  = connect.cursor()
    except sqlite3.Error as e :
       pass
       print("Error connecting to the sqlite database: [%s]" % (e.sqlite_errorname))    
       return []

    global_values = []
    runs_subruns  = [(m.get('core.runs'),m.get('core.runs_subruns'),m.get('core.run_type')) for m in metadata]
    for run_subrun in runs_subruns :
     
        config = ""
        run    = int(run_subrun[0][0])
        sub    = int(int(run_subrun[1][0]) - run*1e5)

        if run_subrun[2] == "neardet-2x2-lar-light" :
           config = "lrs"
        elif run_subrun[2] == "neardet-2x2-lar-charge" :
           config = "crs"
        else :
           print("\tThe run_type [%s] is not implemented. Cannot get the metadata." % run_subrun[2])
           return []
      
        cmd = "SELECT global_subrun FROM All_global_subruns WHERE %s_run=%d and %s_subrun=%d" % (config,run,config,sub)
        cursor.execute(cmd)
        results = cursor.fetchall()
        global_values.extend( [result for ntuple in results for result in ntuple] )

    connect.close()

    global_values = list(OrderedDict.fromkeys(global_values))
    return global_values
    

#++++++++++++++++++++++++++++
# get the number of events
#++++++++++++++++++++++++++++
def _GetNumberOfEvents(filename,workflow) :
    nevts = 0
    if filename.find(".hdf5") != -1 :
       f = h5py.File(filename,'r') 
       if workflow == "combined" :
          evts = f['combined/t0/data']
       else :
          evts  = f['%s/events/data' % workflow]
       nevts = evts.len()
       f.close()
    else :
       print( "Unable to determine the number of events for file [%s]." % filename )
       return -1
    return nevts


#++++++++++++++++++++++++++++
# get the first event number 
#++++++++++++++++++++++++++++
def _GetFirstEventNumber(filename,workflow) :
    first = -1
    if filename.find(".hdf5") != -1 :
       f = h5py.File(filename,'r')
       if workflow == "combined" :
          evts = f['combined/t0/data']  
       else :
          evts  = f['%s/events/data' % workflow]
       first = evts[0][0].item()
       f.close()
    else :
       print( "Unable to determine the number of events for file [%s]." % filename )
       return -1
    return first


#++++++++++++++++++++++++++++
# get the first event number 
#++++++++++++++++++++++++++++
def _GetLastEventNumber(filename,workflow) :
    last = -1
    if filename.find(".hdf5") != -1 :
       f = h5py.File(filename,'r') 
       if workflow == "combined" :
          evts = f['combined/t0/data']
       else :
          evts = f['%s/events/data' % workflow]
       last = evts[-1][0].item()
       f.close()
    else :
       print( "Unable to determine the number of events for file [%s]." % filename )
       return -1
    return last


#+++++++++++++++++++++++++++++
# get the application family
#+++++++++++++++++++++++++++++
def _GetApplicationFamily(tier) :
    if tier == "flow" :
       return "ndlar_flow"
    else :
       return ""


#+++++++++++++++++++++++++++++++++
# get the configurature files
#+++++++++++++++++++++++++++++++++
def _GetConfigFiles(workflow) :
    if workflow == "light" :
       return LIGHT_CONFIG_FILES
    elif workflow == "charge" :
       return CHARGE_CONFIG_FILES
    elif workflow == "combined" :
       return COMBINED_CONFIG_FILES
    else :
       return ""


#+++++++++++++++++++++++++++++++++
# get the parent file(s)
#+++++++++++++++++++++++++++++++++
def _GetParentFiles(workflow,metadata) :
    parents = []
    for key, data in metadata.items() :
        if workflow.find("light") != -1 :
           if data['core.run_type'].find("light")  != -1 : parents.append(key)
        elif workflow.find("charge") != -1 :
           if data['core.run_type'].find("charge") != -1 :  parents.append(key)
        elif workflow.find("combined") != -1 :  
           parents.append(key)
        else :
           sys.exit( "The workflow [%s] is not implemented" % workflow )

    return parents


#+++++++++++++++++++++++++++++++
# calculate the file checksum
#+++++++++++++++++++++++++++++++
def _GetChecksum(filename) :
    if not os.path.exists(filename) :
       return ""

    cmd    = "xrdadler32 %s | cut -f1 -d\' \'" % filename
    proc   = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    stdout, error = proc.communicate()
    stdout = stdout.decode("ascii").strip()
    return stdout


#+++++++++++++++++++++++
# get the metadata 
#+++++++++++++++++++++++
def _GetMetadata(metadata_blocks,filename,workflow,tier) :
    
    return_md = {}
    return_md['core.data_tier']   = tier
    return_md['core.data_stream'] = metadata_blocks[0].get('core.data_stream')
    return_md['core.start_time']  = "" if not os.path.exists(filename) else os.path.getctime(filename)
    return_md['core.end_time']    = "" if not os.path.exists(filename) else os.path.getmtime(filename)
    return_md['core.file_format'] = filename.split(".")[-1]
    return_md['core.file_type']   = metadata_blocks[0].get('core.file_type')

    return_md['core.events']              = -1 if not os.path.exists(filename) else _GetNumberOfEvents(filename,workflow)
    return_md['core.last_event_number']   = -1 if not os.path.exists(filename) else _GetLastEventNumber(filename,workflow)
    return_md['core.first_event_number']  = -1 if not os.path.exists(filename) else _GetFirstEventNumber(filename,workflow)
    return_md['core.file_content_status'] = "good"

    return_md['dune.dqc_quality']         = "unknown"
    return_md['dune.campaign']            = RUN_PERIOD
    return_md['dune.requestid']           = ""
    return_md['dune.config_file']         = _GetConfigFiles(workflow)
    return_md['dune.workflow']            = JUSTIN_WORKFLOW
    return_md['dune.output_status']       = "good"
    return_md['core.application.family']  = _GetApplicationFamily(tier)
    return_md['core.application.name']    = tier
    return_md['core.application.version'] = SOFTWARE
    return_md['retention.status']         = 'active'
    return_md['retention.class']          = 'physics'

    # get the runs
    run_list = [m.get('core.runs') for m in metadata_blocks]
    tmp      = [ n for nums in run_list for n in nums ]
    runs     = list(OrderedDict.fromkeys(tmp))
    return_md['core.runs'] = runs

    # get the runs_subruns
    subrun_list = [m.get('core.runs_subruns') for m in metadata_blocks]
    tmp         = [ n for nums in subrun_list for n in nums ]
    subruns     = list(OrderedDict.fromkeys(tmp))
    return_md['core.runs_subruns'] = subruns

    # get the run_type
    run_types = list(set([m.get('core.run_type') for m in metadata_blocks]))
    if len(run_types) == 0 :
       return_md['core.run_type'] = run_types[0]
    else :
       if DATA_STREAM == "combined" and "DETECTOR_CONFIG" == "proto_nd" :
          return_md['core.run_type'] = 'neardet-2x2-lar-charge-light' 

    # get the global subrun number
    if metadata_blocks[0].get('core.data_tier') == "raw" : 
       return_md['dune.mx2x2_global_subrun_numbers'] = _GetGlobalSubrun(metadata_blocks)
    else :
       return_md['dune.mx2x2_global_subrun_numbers'] = metadata_blocks[0].get('dune.mx2x2_global_subrun_numbers')

    return return_md




##########################################################################
#  main block for processing the data
##########################################################################
if __name__ == '__main__' :

   print( "Enter creating the metadata json file(s) for the 2x2 production jobs\n" )

   # input arguments
   parser = ap()
   parser.add_argument('--input', nargs='?', type=str, required=True, help='Create metadata for the input list of file(s)')
   parser.add_argument('--parents', nargs='?', type=str, required=True, help='The parent file(s) of the input list of file(s)')
   parser.add_argument('--workflow', nargs='?', type=str, required=True, help='The workflow which should correspond to the input list of file(s)')
   parser.add_argument('--tier', type=str, required=True, help='The input data tier')
   parser.add_argument('--namespace', type=str, required=True, help='The namespace for the data tier')

   args = parser.parse_args()

   # get the metacat client
   client = _GetMetacatClient()

   # get the parent files metadata
   parent_metadata = {}
   parents = args.parents.split(",")
   for parent in parents :
       info = client.get_file(did=parent,with_metadata=True,with_provenance=True,with_datasets=False)
       parent_metadata[parent] = info['metadata']

   # loop over the input file names
   workflows = args.workflow.split(",")
   filenames = args.input.split(",")

   for f, filename in enumerate(filenames) :
       metadata = {}
       metadata['parents'] = []

       namespace     = args.namespace
       json_filename = "%s.json" % filename
       parent_files  = _GetParentFiles(workflows[f].strip(),parent_metadata)
     
       # set the metadata fields
       metadata_blocks = []
       for parent_file in parent_files :
           metadata_blocks.append( parent_metadata[parent_file] )
           metadata['parents'].append( {"did":parent_file} )

       metadata_block = _GetMetadata(metadata_blocks,filename,workflows[f],args.tier)

       metadata['name']      = filename
       metadata['namespace'] = namespace

       metadata['creator']   = USER
       metadata['size']      = "" if not os.path.exists(filename) else os.path.getsize(filename)
       metadata['metadata']  = metadata_block

       # set the checksum
       checksum = _GetChecksum(filename)
       metadata['checksums'] = {"adler32":checksum}

       # serializing json
       json_object = json.dumps(metadata,indent=2)

       # write to the json file
       with open(json_filename,"w") as jsonfile :
            jsonfile.write(json_object)

   print( "Exit creating the metadata file for the 2x2 production jobs\n" )





