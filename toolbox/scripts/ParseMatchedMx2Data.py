#!/bin/env python3

import os, sys, string, re, shutil, math, time, subprocess, json
import datetime as dt
import ROOT 

from argparse import ArgumentParser as ap


#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# get the file timestamp using the metadata
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
def _GetFileTimestamp( infile ) :
   
    cmd  = "%s %s metacat file show -m -j %s" % (setcmd,envcmd,infile)
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    stdout, error = proc.communicate()

    if proc.returncode != 0 :
       error = error.decode('ascii')
       sys.exit("Error:[ %s ]" % error.strip())
    else :
       stdout = stdout[stdout.decode('ascii').find("{"):].decode('ascii')

   info      = json.loads(stdout)
   metadata  = info['metadata']
   timestamp = [ float(metadata["core.start_time"]), float(metadata["core.end_time"]) ]

   return timestamp


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# get the parent charge file
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
def _GetTimestampFromParentChargeFile( infile ) :

    cmd  = "%s %s metacat file show -l -j %s" % (setcmd,envcmd,infile)
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    stdout, error = proc.communicate()

    if proc.returncode != 0 :
       error = error.decode('ascii')
       sys.exit("Error:[ %s ]" % error.strip())
    else :
       stdout = stdout[stdout.decode('ascii').find("{"):].decode('ascii')

   info    = json.loads(stdout)
   parents = info['parents']

   if len(parents) == 0 :
      sys.exit( "The parent information is not included in the metadata. The file [%s] is a bad file. Can not continue." % infile )
   else :
      print("\tExtracting metadata from the file [", infile, "]")

   if len(parents) == 1 :
      namespace = parents[0]['namespace']
      filename  = parents[0]['name']
      _GetTimestampFromParentChargeFile( "%s:%s" % (namespace,filename) )
    
   else : 
      for parent in parents :
          namespace = parent['namespace']
          filename  = parent['name']
 
          if namespace == "neardet-2x2-lar-charge" :
             timestamp = _GetFileTimestamp( "%s:%s" % (namespace,filename) )
             return timestamp

   return []


#++++++++++++++++++++++++++++++++++++++++++++++++++++
# create a slim mx2 matching file for cafmaker
# this code is based on the software develop by N. Roy
# https://github.com/DUNE/2x2_sim/blob/feature_spine_on_data/run-cafmaker/match_minerva.cpp
#++++++++++++++++++++++++++++++++++++++++++++++++++++
def _CreateParseMx2File( filename, timestamp ) :

    words    = filename.split("_")
    words[5] = datetime.datetime.now().strftime("%y%m%d%H%S")
    name     = "_".join(words) 

    minerva_tree = ROOT.TChain("minerva")
    minerva_tree.Add(filename)
   
    selection   = "ev_gps_time_sec >=%d && ev_gps_time_sec <=%d" % (timestamp[0],timestamp[1])
    nvalues     = minerva_tree.Draw("Entry$",selection)
    entry_value = minerva_tree.GetVal(0)

    mfile = ROOT.TFile.Open(name, "RECREATE")
    parse_minerva_tree = minerva_tree.CloneTree(0)

    for value in range(nvalues) :
        minerva_tree.GetEntry(int(entry_value[value]))
        parse_minerva_tree.Fill()

    parse_minerva_tree.AutoSave()
    parse_minerva_tree.Write() 

    cmds = "mkdir matched_mx2; mv %s matched_mx2/" % name
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    stdout, error = proc.communicate()

    if proc.returncode != 0 :
       error = error.decode('ascii')
       sys.exit("Error:[ %s ]" % error.strip())
 
    return True 



##########################################################################
#  This script uses the Metacat API
##########################################################################
if __name__ == '__main__' :

   print( "Enter parsing getting the input list of matching files for the ndlar production jobs\n")

   # input arguments
   parser = ap()
   parser.add_argument('--input-file', type=str, required=True, help="The file data identifier (DID)")
   parser.add_argument('--minerva-file', type=str, required=True, help="The input mx2 file name")

   args = parser.parse_args()

   global setcmd
   global envcmd

   setcmd = "source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh; setup python v3_9_15; setup metacat; setup rucio;"
   envcmd = "export METACAT_SERVER_URL=https://metacat.fnal.gov:9443/dune_meta_prod/app;export METACAT_AUTH_SERVER_URL=https://metacat.fnal.gov:8143/auth/dune;"

   # get the timestamp from the parent charge file
   timestamp = _GetTimestampFromParentChargeFile( args.input-file )

   # create a new minerva dst root file
   success = _CreateParseMx2File(args.minerva-file,timestamp)
   if not success :
      sys.exit( "Failed to successful create a parse Mx2 file.")


   print( "Exit parsing getting the input list of matching files for the ndlar production jobs\n")




