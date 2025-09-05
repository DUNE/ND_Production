#!/bin/env python

import os, sys, string, re, shutil, math, time, subprocess, json
import datetime as dt

import sqlite3
import h5py

import ROOT # change to uproot with a ups or spack product is available

from argparse import ArgumentParser as ap
from metacat.webapi import MetaCatClient

from collections import OrderedDict

#++++++++++++++++++++++++++++
# environment variables
#++++++++++++++++++++++++++++
PWD  = str(os.environ.get('PWD'))
USER = str(os.environ.get('USER'))
SOFTWARE   = str(os.environ.get('TWOBYTWO_RELEASE'))
RUN_PERIOD = str(os.environ.get('RUN_PERIOD'))
DETECTOR_CONFIG       = str(os.environ.get('DETECTOR_CONFIG'))
DATA_STREAM           = str(os.environ.get('DATA_STREAM'))
DATA_TIER             = str(os.environ.get('DATA_TIER'))
LIGHT_CONFIG_FILES    = str(os.environ.get('LIGHT_CONFIG_FILES'))
CHARGE_CONFIG_FILES   = str(os.environ.get('CHARGE_CONFIG_FILES'))
COMBINED_CONFIG_FILES = str(os.environ.get('COMBINED_CONFIG_FILES'))
PANDORA_CONFIG_FILES  = str(os.environ.get('PANDORA_SETTINGS'))
SPINE_CONFIG_FILES    = str(os.environ.get('SPINE_SETTINGS'))
CAFMAKER_CONFIG_FILES = str(os.environ.get('CAFFCLFILE'))
JUSTIN_WORKFLOW_ID    = str(os.environ.get('JUSTIN_WORKFLOW_ID'))
JUSTIN_SITE_NAME      = str(os.environ.get('JUSTIN_SITE_NAME')) 

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
          filename = "/cvmfs/dune.opensciencegrid.org/dunend/2x2/databases/mx2x2runs_v0.2_beta1.sqlite"
       elif DETECTOR_CONFIG == "fsd" :
          filename = "/cvmfs/dune.opensciencegrid.org/dunend/2x2/databases/fsd_run_db.20241216.sqlite"
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

        if run_subrun[2] in ["neardet-2x2-lar-light", "neardet-fsd-lar-light"] :
           config = "lrs"
        elif run_subrun[2] in ["neardet-2x2-lar-charge", "neardet-fsd-lar-charge"]:
           config = "crs"
        else :
           print("\tThe run_type [%s] is not implemented. Cannot get the metadata." % run_subrun[2])
           return []

        # We really only need the global subruns corresponding to the charge
        # file, since the charge file maps one-to-one to the processed file, and
        # the light file(s) might extend beyond the time period of the charge file
        if config == 'lrs':
            continue

        # HACK: Look up the actual CRS subrun since, for FSD, the metadata
        # currently has subrun=1 everywhere
        idx = runs_subruns.index(run_subrun)
        name_in_db = metadata[idx]['name'].replace('.hdf5', '.h5')
        cmd = "SELECT subrun FROM CRS_summary WHERE filename='%s'" % name_in_db
        cursor.execute(cmd)
        sub, = cursor.fetchone()

        cmd = "SELECT global_subrun FROM All_global_subruns WHERE %s_run=%d and %s_subrun=%d" % (config,run,config,sub)
        cursor.execute(cmd)
        results = cursor.fetchall()
        global_values.extend( [result for ntuple in results for result in ntuple] )

    connect.close()

    global_values = list(OrderedDict.fromkeys(global_values))
    return sorted(global_values)
    

#++++++++++++++++++++++++++++
# event helper function
#+++++++++++++++++++++++++++
def _EventHelper(name,filename,workflow) :
    evt = -1

    if filename.find(".hdf5") != -1 :
        with h5py.File(filename,'r') as f :
            if DATA_TIER == 'flow':
                evts = f['combined/t0/data'] if workflow == "combined" else f['%s/events/data' % workflow]

                if name == "GetFirstEvent" :
                    evt = evts[0][0].item()
                elif name == "GetLastEvent" :
                    evt = evts[-1][0].item()
                elif name == "GetEvents" :
                    evt = evts.len()

            elif DATA_TIER == 'spine':
                if name == "GetFirstEvent":
                    evt = 0
                elif name in ["GetLastEvent", "GetEvents"]:
                    evt = len(f['events'])

    elif filename.find(".root") != -1 :
       file = ROOT.TFile.Open(filename, "READ")
       if not file or file.IsZombie() :
          return nevts

       if DATA_TIER == "reco_pandora" :
          tree_name = "LArRecoND"
          tree = file.Get(tree_name)

          if name == "GetFirstEvent" :
             tree.GetEntry(0)
             evt = tree.event
          elif name == "GetLastEvent" :
             n = tree.GetEntries() - 1
             tree.GetEntry(n)
             evt = tree.event
          elif name == "GetEvents" :
             evt = tree.GetEntries()

       elif DATA_TIER == "caf" :
          tree = file.cafTree   

          if name == "GetFirstEvent" :
             evt = tree.GetEntry(0)
          elif name == "GetLastEvent" :
             n = tree.GetEntries() - 1
             evt = tree.GetEntry(n)
          elif name == "GetEvents" :
             evt = tree.GetEntries()

       else : 
          return evt


    return evt

   
#++++++++++++++++++++++++++++
# get the number of events
#++++++++++++++++++++++++++++
def _GetNumberOfEvents(filename,workflow) :
    name = "GetEvents"
    return _EventHelper(name,filename,workflow)


#++++++++++++++++++++++++++++
# get the first event number 
#++++++++++++++++++++++++++++
def _GetFirstEventNumber(filename,workflow) :
    name = "GetFirstEvent"
    return _EventHelper(name,filename,workflow)


#++++++++++++++++++++++++++++
# get the first event number 
#++++++++++++++++++++++++++++
def _GetLastEventNumber(filename,workflow) :
    name = "GetLastEvent"
    return _EventHelper(name,filename,workflow)


#+++++++++++++++++++++++++++++
# get the application family
#+++++++++++++++++++++++++++++
def _GetApplicationFamily() :
    if DATA_TIER == "flow" :
       return "python_framework"
    elif DATA_TIER == "reco_pandora" :
       return "pandora"
    elif DATA_TIER == "reco_spine" :
        return "larcv"
    elif DATA_TIER == "caf" :
        return "nd_caf_framwork"
    else :
        return "None"


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
    elif workflow == "pandora" :
       return PANDORA_CONFIG_FILES
    elif workflow == "spine" :
        return SPINE_CONFIG_FILES
    elif workflow == "cafmaker" or workflow == "cafmaker_flat" :
       return CAFMAKER_CONFIG_FILES
    else :
       return ""


#+++++++++++++++++++++++++++++++++
# get the parent file(s)
#+++++++++++++++++++++++++++++++++
def _GetParentFiles(metadata) :
    parents = []
    for key, data in metadata.items() :
        parents.append(key)
    return parents


#+++++++++++++++++++++++++++++++
# get the data stream
#+++++++++++++++++++++++++++++++
def _GetDataStream(metadata_blocks) :
    if DETECTOR_CONFIG == "proto_nd" :
       return "numibeam"
    elif DETECTOR_CONFIG == "fsd" :
       return metadata_blocks[0].get('core.data_stream')

    return "None"


#+++++++++++++++++++++++++++++++
# get the run type
#+++++++++++++++++++++++++++++++
def _GetRunType(workflow) :
   
    word = "-"
    if DETECTOR_CONFIG == "proto_nd" :
       word = "-2x2-"
    elif DETECTOR_CONFIG == "fsd" :
       word = "-fsd-"

    if DATA_STREAM == "combined" :
       return 'neardet%slar-charge-light' % word
    elif DATA_STREAM == "light" :
       return 'neardet%slar-light' % word
    elif DATA_STREAM == "charge" :
       return 'neardet%slar-charge' % word
    elif DATA_STREAM == "calibrated" : 
       return 'neardet%slar-reco' % word
    elif DATA_STREAM == "reco" :
       if workflow.find("flat") != -1 : 
           return 'neardet%slar-caf-flat' % word
       else :
           return 'neardet%slar-caf' % word

    return "None"



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
    return_md['core.data_tier']   = "caf-flat-analysis" if workflow == "cafmaker_flat" else tier
    return_md['core.data_stream'] = _GetDataStream(metadata_blocks)
    return_md['core.end_time']    = -1 if not os.path.exists(filename) else int(os.path.getmtime(filename))
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
    return_md['dune.workflow']            = { 'workflow_id' : JUSTIN_WORKFLOW_ID, 'site_name' : JUSTIN_SITE_NAME }
    return_md['dune.output_status']       = "good"
    return_md['core.run_type']            = _GetRunType(workflow)
    return_md['core.application.family']  = _GetApplicationFamily()
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
    # return_md['core.runs_subruns'] = subruns

    # Setting runs_subruns can lead to confusion, since it isn't obvious whether
    # we're specifying the charge or the light subruns, or both (in which case,
    # there's no simple way to distinguish the two). So, just leave it blank?
    return_md['core.runs_subruns'] = []

    # get the global subrun number
    if metadata_blocks[0].get('core.data_tier') == "raw" : 
       return_md['dune.mx2x2_global_subrun_numbers'] = _GetGlobalSubrun(metadata_blocks)
    else :
       return_md['dune.mx2x2_global_subrun_numbers'] = metadata_blocks[0].get('dune.mx2x2_global_subrun_numbers')

    # return the metadata block
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
       breakpoint()
       parent_metadata[parent] = info['metadata']

   # loop over the input file names
   workflows = args.workflow.split(",")
   filenames = args.input.split(",")

   for f, filename in enumerate(filenames) :
       metadata = {}
       metadata['parents'] = []

       namespace     = args.namespace
       json_filename = "%s.json" % filename
       parent_files  = _GetParentFiles(parent_metadata)
     
       # set the metadata fields
       metadata_blocks = []
       for parent_file in parent_files :
           parent_metadata[parent_file]['name'] = parent_file.split(':')[1] # TMP4HACK
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





