#!/bin/env python

import os, sys, string, re, shutil, math, time, subprocess, json
import datetime as dt

import sqlite3
import h5py

import ROOT # change to uproot with a ups or spack product is available

from pathlib import Path
from argparse import ArgumentParser as ap
from metacat.webapi import MetaCatClient

from collections import OrderedDict

#++++++++++++++++++++++++++++
# environment variables
#++++++++++++++++++++++++++++
PWD  = str(os.environ.get('PWD'))
USER = str(os.environ.get('USER'))
SOFTWARE   = str(os.environ.get('TWOBYTWO_RELEASE')) if 'TWOBYTWO_RELEASE' in os.environ else 'None'
RUN_PERIOD = str(os.environ.get('RUN_PERIOD')) if 'RUN_PERIOD' in os.environ else 'None'
DETECTOR_CONFIG       = str(os.environ.get('DETECTOR_CONFIG')) if 'DETECTOR_CONFIG' in os.environ else 'None'
DATA_TYPE             = str(os.environ.get('DATA_TYPE')) if 'DATA_TYPE' in os.environ else 'None'
DATA_STREAM           = str(os.environ.get('DATA_STREAM')) if 'DATA_STREAM' in os.environ else 'None'
DATA_TIER             = str(os.environ.get('DATA_TIER')) if 'DATA_TIER' in os.environ else 'None'
GENIE_CONFIG_FILES    = f"{str(os.environ.get('DK2NU_FILE'))},{str(os.environ.get('GENIE_XSEC_FILE'))}" if 'DK2NU_FILE' and 'GENIE_XSEC_FILE' in os.environ else 'None'
GENIE_CONFIG_FILES    = f"{GENIE_CONFIG_FILES},{str(os.environ.get('MAX_PATH_XML_FILE'))}" if 'MAX_PATH_XML_FILE' in os.environ else GENIE_CONFIG_FILES
LIGHT_CONFIG_FILES    = str(os.environ.get('LIGHT_CONFIG_FILES')) if 'LIGHT_CONFIG_FILES' in os.environ else 'None'
CHARGE_CONFIG_FILES   = str(os.environ.get('CHARGE_CONFIG_FILES')) if 'CHARGE_CONFIG_FILES' in os.environ else 'None'
COMBINED_CONFIG_FILES = str(os.environ.get('COMBINED_CONFIG_FILES')) if 'COMBINED_CONFIG_FILES' in os.environ else 'None'
PANDORA_CONFIG_FILES  = str(os.environ.get('PANDORA_SETTINGS')) if 'PANDORA_SETTINGS' in os.environ else 'None'
CAFMAKER_CONFIG_FILES = str(os.environ.get('CAFFCLFILE')) if 'CAFFCLFILE' in os.environ else 'None'
JUSTIN_WORKFLOW_ID    = str(os.environ.get('JUSTIN_WORKFLOW_ID')) if 'JUSTIN_WORKFLOW_ID' in os.environ else 'None'
JUSTIN_SITE_NAME      = str(os.environ.get('JUSTIN_SITE_NAME')) if 'JUSTIN_SITE_NAME' in os.environ else 'None'


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
# event helper function
#+++++++++++++++++++++++++++
def _EventHelper(name,filename,workflow,delete=False) :
    if DATA_TIER == "" : return -1

    evt = -1
    tree_map = [ ("genie", "gtree"), ("spill_builder", "EDepSimEvents"), ("reco_pandora","LArRecoND"), ("caf","caftree") ]

    if filename.find(".hdf5") != -1 :
       with h5py.File(filename,'r') as f :
            evts = f['combined/t0/data'] if workflow == "combined" else f['%s/events/data' % workflow]

            if name == "GetFirstEvent" :
               evt = evts[0][0].item()
            elif name == "GetLastEvent" :
               evt = evts[-1][0].item()
            elif name == "GetEvents" :
               evt = evts.len()


    elif filename.find(".root") != -1 :
       with ROOT.TFile(filename, "READ") as file :

            values = [tup for tup in tree_map if tup[0] == DATA_TIER]
            tname  = "gRooTracker" if filename.find("GTRAC") != 1 else values[0][1]

            if DATA_TIER.find("spill_builder") != -1  :
               if os.path.exists("%s/%s.so" % (tname,tname)) :
                  ROOT.gSystem.Load("%s/%s.so" % (tname,tname))
               else :
                  file.MakeProject(tname,"*", "RECREATE++")

               events = file.Get(tname)
               total  = events.GetEntries()

               if name == "GetEvents" : evt = total
               else :
                    for e, entry in enumerate(events) :
                        event = entry.Event
                        if (e == 0 and name == "GetFirstEvent") or (e == total-1 and name == "GetLastEvent") :
                           evt   = event.EventId
                           break
               if delete : shutil.rmtree(tname)

            elif DATA_TIER.find("genie") != -1 :
                 tree  = file.Get(tname)
                 evt   = 1 if name == "GetFirstEvent" else tree.GetEntries()
            elif DATA_TIER == "reco_pandora" :
                 tree = file.Get(tname)
                 if name == "GetFirstEvent" :
                    tree.GetEntry(0)
                    evt = tree.event
                 elif name == "GetLastEvent" :
                    tree.GetEntry( tree.GetEntries() - 1 )
                    evt = tree.event
                 elif name == "GetEvents" :
                    evt = tree.GetEntries()
            elif DATA_TIER == "caf" :
                 tree = file.cafTree
                 if name == "GetFirstEvent" :
                    evt = tree.GetEntry(0)
                 elif name == "GetLastEvent" :
                    evt = tree.GetEntry( tree.GetEntries() - 1 )
                 elif name == "GetEvents" :
                    evt = tree.GetEntries()

    return evt



#++++++++++++++++++++++++++++
# get the number of events
#++++++++++++++++++++++++++++
def _GetNumberOfEvents(filename,workflow,delete=False) :
    name = "GetEvents"
    return _EventHelper(name,filename,workflow,delete) 


#++++++++++++++++++++++++++++
# get the first event number
#++++++++++++++++++++++++++++
def _GetFirstEventNumber(filename,workflow,delete=False) :
    name = "GetFirstEvent"
    return _EventHelper(name,filename,workflow,delete)


#++++++++++++++++++++++++++++
# get the first event number
#++++++++++++++++++++++++++++
def _GetLastEventNumber(filename,workflow,delete=False) :
    name = "GetLastEvent"
    return _EventHelper(name,filename,workflow,delete)


   
#+++++++++++++++++++++++++++++
# get the application family
#+++++++++++++++++++++++++++++
def _GetApplicationFamily() :
    if DATA_TIER.find("genie") != -1 :
       return "genie"
    elif DATA_TIER.find("spill_builder") != -1 : 
       return "root_tg4event_standalone"
    elif DATA_TIER == "flow" :
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
    if workflow.find("genie") != -1 :
       return GENIE_CONFIG_FILES
    elif workflow == "light" :
       return LIGHT_CONFIG_FILES
    elif workflow == "charge" :
       return CHARGE_CONFIG_FILES
    elif workflow == "combined" :
       return COMBINED_CONFIG_FILES
    elif workflow == "pandora" :
       return PANDORA_CONFIG_FILES
    elif workflow.find("cafmaker") != -1 :
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
def _GetDataStream() :
    if DETECTOR_CONFIG == "proto_nd" :
       return "numibeam" if DATA_TYPE == 'data' else _GetSimulationFlavor() 
    elif DETECTOR_CONFIG == "fsd" :
       return metadata_blocks[0].get('core.data_stream') if DATA_TYPE == 'data' else "cosmics"
    elif DETECTOR_CONFIG == "dunend" :
       return "lbnfbeam" if DATA_TYPE == 'data' else _GetSimulationFlavor() 
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



#++++++++++++++++++++++++++++++++++
# get the flavor of simulation
#++++++++++++++++++++++++++++++++++
def _GetSimulationFlavor() :
   if 'GENIE_ANTINU' in os.environ :
       if str(os.environ.get('GENIE_ANTINU')) == "1" : return "antineutrino"
   
   if 'GENIE_NU' in os.environ :
      if str(os.environ.get('GENIE_NU')) == "1" : return "neutrino"

   return "simulation"



#+++++++++++++++++++++++
# get the metadata 
#+++++++++++++++++++++++
def _GetMetadata(metadata_blocks,filename,workflow,tier) :
    
    return_md = {}
    return_md['core.data_tier']   = "caf-flat-analysis" if workflow == "cafmaker_flat" else tier
    return_md['core.data_stream'] = _GetDataStream()
    return_md['core.end_time']    = -1 if not os.path.exists(filename) else int(os.path.getmtime(filename))
    return_md['core.file_format'] = filename.split(".")[-1]
    return_md['core.file_type']   = "montecarlo" if len(metadata_blocks) == 0 else metadata_blocks[0].get('core.file_type')

    return_md['core.events']              = -1 if not os.path.exists(filename) else _GetNumberOfEvents(filename,workflow)
    return_md['core.last_event_number']   = -1 if not os.path.exists(filename) else _GetLastEventNumber(filename,workflow)
    return_md['core.first_event_number']  = -1 if not os.path.exists(filename) else _GetFirstEventNumber(filename,workflow)
    return_md['core.file_content_status'] = "good"

    return_md['core.group']               = "dune"
    return_md['dune.dqc_quality']         = "unknown"
    return_md['dune.campaign']            = str(os.environ.get('CAMPAIGN_NAME')) if 'CAMPAIGN_NAME' in os.environ else RUN_PERIOD
    return_md['dune.requestid']           = str(os.environ.get('REQUEST_ID')) if 'REQUEST_ID' in os.environ else 'None'
    return_md['dune.config_file']         = _GetConfigFiles(workflow)
    return_md['dune.workflow']            = { 'workflow_id' : JUSTIN_WORKFLOW_ID, 'site_name' : JUSTIN_SITE_NAME }
    return_md['dune.output_status']       = "good"
    return_md['core.application.family']  = _GetApplicationFamily()
    return_md['core.application.name']    = tier
    return_md['core.application.version'] = SOFTWARE
    return_md['retention.status']         = 'active'
    return_md['retention.class']          = 'physics'

    # get the runs, runs_subruns, and global subrun numbers
    if len(metadata_blocks) != 0 :
       for name in ['core.runs','core.runs_subruns'] :
           run_list = [m.get(name) for m in metadata_blocks]
           tmp      = [ n for nums in run_list for n in nums ]
           runs     = list(OrderedDict.fromkeys(tmp))
           return_md[name] = runs

       if DETECTOR_CONFIG == "proto_nd" :
          name = 'dune.mx2x2_global_subrun_numbers'  
          return_md[name] = _GetGlobalSubrun(metadata_blocks) if metadata_blocks[0].get('core.data_tier') == "raw" else etadata_blocks[0].get(name)
    else :
       run = int(str(os.environ.get('RUN'))) if 'RUN' in os.environ else -1
       return_md['core.runs']         =  [run]
       return_md['core.runs_subruns'] =  [run*100000+1]
       
       if DETECTOR_CONFIG == "proto_nd" :
          return_md['dune.mx2x2_global_subrun_numbers'] = [run*100000+1]

    # return the metadata block
    return return_md


#+++++++++++++++++++++++++++
# get the mc metadata
#+++++++++++++++++++++++++++
def _GetMCMetadata(workflow) :

    return_md = {}
    return_md['dune_mc.name']       = str(os.environ.get('CAMPAIGN_NAME')) if 'CAMPAIGN_NAME' in os.environ else 'None'
    return_md['dune_mc.generators'] = "genie" if DATA_TIER.find("genie") != -1  else "Unknown"
    return_md['dune.dqc_quality']   = 'good'

    if workflow.find("genie") != -1 :
       return_md['dune_mc.genie_tune']       = str(os.environ.get('GENIE_PRODUCTION_TUNE')) if 'GENIE_PRODUCTION_TUNE' in os.environ else 'None'
       return_md['dune_mc.top_volume']       = str(os.environ.get('GENIE_TOP_VOLUME')) if 'GENIE_TOP_VOLUME' else 'World'
       return_md['dune_mc.geometry_version'] = str(os.environ.get('GENIE_DETECTOR_GEOM')) if 'GENIE_DETECTOR_GEOM' else 'None'

       if str(os.environ.get('GENIE_ANTINU')) == "1" :
          return_md['dune_mc.nu'] = "RHC_%s" % ( str(os.environ.get('GENIE_EVENT_GENERATOR_LIST')) if 'GENIE_EVENT_GENERATOR_LIST' in os.environ else 'Nominal' )
       elif str(os.environ.get('GENIE_NU')) == "1" :
          return_md['dune_mc.nu'] = "FHC_%s" % ( str(os.environ.get('GENIE_EVENT_GENERATOR_LIST')) if 'GENIE_EVENT_GENERATOR_LIST' in os.environ else 'Nominal' )

       if str(os.environ.get('GENIE_ROCK')) == "1" :
          return_md['dune_mc.rock'] = "True"
       else :
          return_md['dune_mc.rock'] = "False"



    return return_md


##########################################################################
#  main block for processing the data
##########################################################################
if __name__ == '__main__' :

   print( "Enter creating the metadata json file(s) for the 2x2 production jobs\n" )

   # input arguments
   parser = ap()
   parser.add_argument('--input', nargs='?', type=str, required=True, help='Create metadata for the input list of file(s)')
   parser.add_argument('--parents', nargs='?', type=str,  help='The parent file(s) of the input list of file(s)')
   parser.add_argument('--workflow', nargs='?', type=str, required=True, help='The workflow which should correspond to the input list of file(s)')
   parser.add_argument('--tier', type=str, required=True, help='The input data tier')
   parser.add_argument('--namespace', type=str, required=True, help='The namespace for the data tier')
   parser.add_argument('--mc', action='store_true', help='Is the input simulated data?')

   args = parser.parse_args()

   # get the metacat client
   client = _GetMetacatClient()

   # get the parent files metadata
   parent_metadata = {}
   parents = [] if args.parents == None else args.parents.split(",")

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

       metadata_blocks = []
   
       if len(parents) != 0 :
           parent_files  = _GetParentFiles(parent_metadata)
           for parent_file in parent_files :
               metadata_blocks.append( parent_metadata[parent_file] )
               metadata['parents'].append( {"did":parent_file} )


       metadata_block = _GetMetadata(metadata_blocks,filename,workflows[f],args.tier)

       metadata['name']      = filename
       metadata['namespace'] = namespace

       metadata['creator']   = USER
       metadata['size']      = "" if not os.path.exists(filename) else os.path.getsize(filename)
       metadata['metadata']  = metadata_block

       #Due to declad configuration, run type must be the namespace
       metadata['metadata']['core.run_type'] = namespace

       if args.mc :
          mc_metadata_block = _GetMCMetadata(workflows[f])
          metadata['metadata'].update(mc_metadata_block)

       # set the checksum
       checksum = _GetChecksum(filename)
       metadata['checksums'] = {"adler32":checksum}

       # serializing json
       json_object = json.dumps(metadata,indent=2)

       # write to the json file
       with open(json_filename,"w") as jsonfile :
            jsonfile.write(json_object)

   print( "Exit creating the metadata file for the 2x2 production jobs\n" )





