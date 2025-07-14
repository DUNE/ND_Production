#!/bin/env python3

import os, sys, string, re, shutil, math, time, subprocess, json
import sqlite3

from argparse import ArgumentParser as ap


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# get the light files - using python interface because
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
def _GetLightFiles(lightInfoCont) :

   setcmd = "source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh; setup python v3_9_15; setup metacat; setup rucio;"
   envcmd = "export METACAT_SERVER_URL=https://metacat.fnal.gov:9443/dune_meta_prod/app;export METACAT_AUTH_SERVER_URL=https://metacat.fnal.gov:8143/auth/dune;"

   lfiles     = []
   main_query = "files where namespace=neardet-2x2-lar-light and creator=dunepro and core.data_tier=raw"

   for lightInfo in lightInfoCont :
       if lightInfo[0] == None : continue

       lrun    = int(lightInfo[0])
       lsubrun = int(lrun*1e5 + int(lightInfo[1]))
       query   = "%s and core.runs[0]=%d and core.runs_subruns[0]=%d" % (main_query,lrun,lsubrun)
       cmd     = "%s %s metacat query \"%s\"" % (setcmd,envcmd,query)
       proc    = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
       stdout, error = proc.communicate() #[0].decode('ascii')

       if proc.returncode != 0 :
          error = error.decode('ascii')
          print("Error:[ %s ]" % error.strip())
          sys.exit("Did not find the file for query [%s].\n" % query)
       else :
          stdout = stdout[stdout.decode('ascii').find("neardet-2x2-lar-light"):].decode('ascii').strip()
          lfiles.append(stdout)

   ndownloads = 0
   for lfile in lfiles :
       cmd   = "%s export RUCIO_ACCOUNT=\"justinreadonly\"; rucio download %s" % (setcmd,lfile)
       proc  = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
       pipe  = proc.communicate()[0].decode('ascii')
       proc.wait()

       print(pipe)

       if proc.returncode != 0 :
          sys.exit( "Cannot download the file [%s].\n" % lfile )
       else :
          print( "\t\tSuccessfully download the file [%s]." % lfile )
          ndownloads += 1

   return ndownloads



#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# get the light metadata for the incoming charge file's run and subrun
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
def _GetLightMetadata(run,subrun) :

    filename = ""
    if run >= 50005 and run <= 50018 :
       filename = "/cvmfs/minerva.opensciencegrid.org/minerva2x2/databases/mx2x2runs_v0.2_beta1.sqlite"
    else :
       print("The run period is not implemented.")
       return []

    try :
       name    = f'file:{filename}?mode=ro'
       connect = sqlite3.connect(name, uri=True)
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
        print("Error connecting to the sqlite database", e)
      
    return []
    


##########################################################################
#  This script uses the Metacat API
##########################################################################
if __name__ == '__main__' :

   print( "Enter getting the input list of light files for the 2x2 production jobs\n")

   # input arguments
   parser = ap()
   parser.add_argument('--file', nargs='?', type=str, required=True, help="The file data identifier (DID)")
   args = parser.parse_args()

   setcmd = "source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh; setup python v3_9_15; setup metacat; setup rucio;"
   envcmd = "export METACAT_SERVER_URL=https://metacat.fnal.gov:9443/dune_meta_prod/app;export METACAT_AUTH_SERVER_URL=https://metacat.fnal.gov:8143/auth/dune;"
   cmd     = "%s %s metacat file show -m -j %s" % (setcmd,envcmd,args.file)
   proc    = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
   stdout, error = proc.communicate()

   if proc.returncode != 0 :
      error = error.decode('ascii')
      sys.exit("Error:[ %s ]" % error.strip())
   else :
      stdout = stdout[stdout.decode('ascii').find("{"):].decode('ascii')

   info = json.loads(stdout)

   print( "\tCharge file is [%s]" % args.file )

   # get the metadata
   metadata = info['metadata']
   run      = metadata['core.runs'][0]
   subrun   = int(metadata['core.runs_subruns'][0] - run*1e5)

   # get the runs/subruns for the matching light files
   lightInfoCont = _GetLightMetadata(run,subrun)
   print( "\t\tThe matching runs/subruns list :", lightInfoCont, "\n" )   

   # download the light files to local disk (TODO: work for other detector configurations)
   downloadFiles = _GetLightFiles(lightInfoCont)

   print( "Exit getting the input list of matching light files." )
   print( "\tThe number of files is [%d].\n" % downloadFiles ) 



