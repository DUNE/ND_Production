#!/bin/env python3


import os, sys, string, re, shutil, math, time, subprocess, json
import sqlite3

from argparse import ArgumentParser as ap
from metacat.webapi import MetaCatClient


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# get the light files - using python interface because
#    the API returns a HTTPClient.unpack_json_seq object
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
def _GetLightFiles(lightInfoCont,isOnTapeCheck) :

   lfiles     = []
   main_query = "files where namespace=neardet-2x2-lar-light and creator=dunepro and core.data_tier=raw"

   for lightInfo in lightInfoCont :
       lrun    = lightInfo[0]
       lsubrun = lightInfo[1]
       query   = "%s and core.runs[0]=%s and core.runs_subruns[0]=%s" % (main_query,lrun,lsubrun)
      
       cmd     = "metacat query \"%s\"" % query
       proc    = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
       stdout, error = proc.communicate() #[0].decode('ascii')

       if proc.returncode != 0 :
          error = error.decode('ascii')
          print("Error:[ %s ]" % error.strip())
          sys.exit("Did not find the file for query [%s].\n" % query)
       else :
          stdout = stdout.decode('ascii')
          lfiles.append(stdout.strip())


   for lfile in lfiles :
       download = True

       cmd  = f"rucio list-file-replicas {lfile} --pfns"
       proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
       stdout, error = proc.communicate() #[0].decode('ascii')

       if proc.returncode != 0 :
          error = error.decode('ascii')
          print("Error:[ %s ]" % error.strip())
          sys.exit("Did not find the phyiscal file name for query [%s].\n" % cmd)
       else :
          stdout = stdout.decode('ascii').split("\n")

       print( f"\tThe paths for {lfile} is [{stdout}].\n" )

       rucio_download = False
       download       = False

       for path in stdout :
           if len(path) == 0 : continue
           pnfs      = path.replace("root://fndca1.fnal.gov:1094/pnfs/fnal.gov/usr/","/pnfs/")
           filename  = pnfs.split("/")[-1]
           pnfs_path = pnfs.replace(filename,"")
           cmds      = [ "cat %s\".(get)(%s)(locality)\"" % (pnfs_path,filename),
                         "mkdir neardet-2x2-lar-light; xrdcopy %s neardet-2x2-lar-light/" % (path.strip()) ]

           for c, cmd in enumerate(cmds) :
               proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
               pipe = proc.communicate()[0].decode('ascii')
 
               if c == 0 and isOnTapeCheck : 
                  if proc.returncode != 0 :
                     print( f"Cannot determine the locality of the file on dCache [{path}]." )
                  else :
                     if pipe.strip().find("ONLINE") != -1 :
                        rucio_download = True
               if c == 1 :
                  if proc.returncode == 0 :
                     download = True

           if download : break

       if rucio_download and not download :
          print( f"\tDownloading the light raw file [{lfile}]" )

          cmd   = f"rucio download {lfile}"
          proc  = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
          pipe  = proc.communicate()[0].decode('ascii')

          if proc.returncode != 0 :
             sys.exit( f"Cannot download the file [{lfile}]." )
          else :
             print( f"\t\tSuccessfully download the file [{lfile}]." )







#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# get the light metadata for the incoming charge file's run and subrun
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
def _GetLightMetadata(run,subrun) :

    filename = ""
    if run >= 50005 and run <= 50018 :
       filename = "/cvmfs/minerva.opensciencegrid.org/minerva2x2/databases/mx2x2runs_v0.1_alpha3.sqlite"
    else :
       print("The run period is not implemented.")
       return []

    try :
       connect = sqlite3.connect(f"file:{filename}?mode=ro", uri=True)
       cursor  = connect.cursor()
       query   = "SELECT lrs_run, lrs_subrun FROM All_global_subruns WHERE crs_run=%s and crs_subrun=%s" % (run,subrun) 
       cursor.execute(query)
       results = cursor.fetchall()

       values = []
       for result in results :
           values.append(result)

       values = list(set(values))

       connect.close()
       return values

    except sqlite3.Error as e :
        pass
        print(f"Error connecting to the sqlite database: {e}")
      
    return []
    


#+++++++++++++++++++++++++++++++++
# get the metacat client
#+++++++++++++++++++++++++++++++++
def _GetMetacatClient() :
    client = MetaCatClient(server_url='https://metacat.fnal.gov:9443/dune_meta_prod/app',
                           auth_server_url='https://metacat.fnal.gov:8143/auth/dune',
                           timeout=30)
    return client




##########################################################################
#  This script uses the Metacat API
##########################################################################
if __name__ == '__main__' :

   print( "Enter getting the input list of light files for the 2x2 production jobs\n")

   # input arguments
   parser = ap()
   parser.add_argument('--file', nargs='?', type=str, required=True, help="The file data identifier (DID)")
   parser.add_argument('--tapeCheck', action='store_true', help="Check if the file is on tape, only works when running a justin test job.")
   args = parser.parse_args()


   # get the metacat client
   client = _GetMetacatClient()
   info   = client.get_file(did=args.file,with_metadata=True,with_provenance=True,with_datasets=False) 

   print( "\tCharge file is [%s]" % args.file )

   # get the metadata
   metadata = info['metadata']
   run      = metadata['core.runs'][0]
   subrun   = int(metadata['core.runs_subruns'][0] - run*1e4)

   # get the runs/subruns for the matching light files
   lightInfoCont = _GetLightMetadata(run,subrun)
   print( f"\t\tThe matching runs/subruns list [ {lightInfoCont} ]\n" )   

   # download the light files to local disk (TODO: work for other detector configurations)
   _GetLightFiles(lightInfoCont,args.tapeCheck)

   print( "Exit getting the input list of matching light files." )
   print( "\tThe number of files is [%d].\n" % len(lightInfoCont) ) 



