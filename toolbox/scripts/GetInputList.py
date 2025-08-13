#!/bin/env python3

import os, sys, string, re, shutil, math, time, subprocess, json
import sqlite3

from argparse import ArgumentParser as ap




#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# create a metacat query string for global subruns 
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
def _CreateMetacatQueryString(global_subrun_list) :
    queryString = ""

    for i, subrun in enumerate(global_subrun_list) :
       queryString += "dune.mx2x2_global_subrun_numbers[any] == %s" % subrun
       if i != len(global_suburun_list)-1 :
          queryString += " and "

    return queryString 


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# get the files via a metacat query
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
def _GetFilenames( metacat_query, namespace ) :
    filenames = []

    cmd  = "%s %s metacat query \"%s\"" % (G_SETCMD,G_ENVCMD,metacat_query)
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    stdout, error = proc.communicate() 

    if proc.returncode != 0 :
       error = error.decode('ascii')
       print("Error:[ %s ]" % error.strip())
       sys.exit("Did not find the file for query [%s].\n" % query)
    else :
       stdout = stdout[stdout.decode('ascii').find("%s"%namespace):].decode('ascii').strip()
       filenames.append(stdout)

    return filenames


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# use rucio to download the files 
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
def _DownloadFiles( files_to_download ) :
    ndownloads = 0

    for lfile in files_to_download :
        cmd   = "%s export RUCIO_ACCOUNT=\"justinreadonly\"; rucio download %s" % (G_SETCMD,lfile)
        proc  = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
        pipe  = proc.communicate()[0].decode('ascii')
        proc.wait()

        if proc.returncode != 0 :
           sys.exit( "Cannot download the file [%s].\n" % lfile )
        else :
           print( "\t\tSuccessfully download the file [%s]." % lfile )
           ndownloads += 1

    if ndownloads > 0 :
       namespace = files_to_download[0].split(":")[0]
       cmds = "mkdir downloads; mv %s/* downloads;" % namespace
       proc = subprocess.Popen(cmds, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
       pipe = proc.communicate()[0].decode('ascii')

       if proc.returncode != 0 :
          sys.exit( "Cannot move files." ) 
     
    return ndownloads 


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# get the mx2 reconstructed files 
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
def _GetMx2Files(global_subrun_list, workflow_id) :
 
    queryString = _CreateMetacatQueryString(global_subrun_list)
 
    main_query  = "files with namespace=neardet-2x2-minerva and creator=dunepro and core.data_tier=dst-reconstructed and dune.workflow['workflow_id']=%s and (%s)" % (workflow_id,queryString)
    mfiles      = _GetFilenames( main_query, "neardet-2x2-minerva" )
    ndownloads  = _DownloadFiles(mfiles) 

    return ndownloads


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# get the spine reconstructed files 
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
def _GetSpineFiles(global_subrun_list, workflow_id) :
 
    queryString = _CreateMetacatQueryString(global_subrun_list)
 
    main_query  = "files with namespace=neardet-2x2-lar and creator=dunepro and core.data_tier=spine-reconstruction and dune.workflow['workflow_id']=%s and (%s)" % (workflow_id,queryString)
    sfiles      = _GetFilenames( main_query, "neardet-2x2-lar" )
    ndownloads  = _DownloadFiles(sfiles) 

    return ndownloads


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# get the light files - using python interface because
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
def _GetLightFiles(lightInfoCont) :

    lfiles     = []
    main_query = "files where namespace=neardet-2x2-lar-light and creator=dunepro and core.data_tier=raw"

    for lightInfo in lightInfoCont :
        if lightInfo[0] == None : continue

        lrun    = int(lightInfo[0])
        lsubrun = int(lrun*1e5 + int(lightInfo[1]))
        query   = "%s and core.runs[0]=%d and core.runs_subruns[0]=%d" % (main_query,lrun,lsubrun)

        tmp     = _GetFilenames( query, "neardet-2x2-lar-light" )
        for t in tmp : lfiles.append(t) 
         
    ndownloads = _DownloadFiles(lfiles) 
    return ndownloads



#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# get the light metadata for the incoming charge file's run and subrun
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
def _GetLightMetadata(run,subrun) :

    filename = ""
    if run >= 20003 and run <= 20180 :
       filename = "/cvmfs/dune.opensciencegrid.org/dunend/2x2/databases/fsd_run_db.20241216.sqlite"
    elif run >= 50005 and run <= 50018 :
       filename = "/cvmfs/dune.opensciencegrid.org/dunend/2x2/databases/mx2x2runs_v0.2_beta1.sqlite"
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

   print( "Enter getting the input list of matching files for the ndlar production jobs\n")

   # input arguments
   parser = ap()
   parser.add_argument('--file', nargs='?', type=str, required=True, help="The file data identifier (DID)")
   parser.add_argument('--light', default=False, action="store_true", help="Retreiving the matching raw light files for an input raw charge file")
   parser.add_argument('--spine', default=False, action="store_true", help="Retreiving the matching spine reconstructed file for an input pandora file")
   parser.add_argument('--spine-justin', type=str, help='The input justin workflow-id for the spine reconstruction')
   parser.add_argument('--mx2', default=False, action="store_true", help="Retreiving the matching minerva dst file for an input pandora or spine file")
   parser.add_argument('--mx2-justin', type=str, help='The input justin workflow-id for the mx2 reconstruction')
 
   args = parser.parse_args()

   global G_SETCMD
   global G_ENVCMD

   G_SETCMD = "source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh; setup python v3_9_15; setup metacat; setup rucio;"
   G_ENVCMD = "export METACAT_SERVER_URL=https://metacat.fnal.gov:9443/dune_meta_prod/app;export METACAT_AUTH_SERVER_URL=https://metacat.fnal.gov:8143/auth/dune;"

   cmd     = "%s %s metacat file show -m -j %s" % (G_SETCMD,G_ENVCMD,args.file)
   proc    = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
   stdout, error = proc.communicate()

   if proc.returncode != 0 :
      error = error.decode('ascii')
      sys.exit("Error:[ %s ]" % error.strip())
   else :
      stdout = stdout[stdout.decode('ascii').find("{"):].decode('ascii')

   info = json.loads(stdout)
   print( "\tThe input file is [%s]" % args.file )

   # get the metadata
   metadata = info['metadata']
   downloadFiles = 0

   # get the matching files for a particular input file
   if args.light :
      run    = metadata['core.runs'][0]
      subrun = int(metadata['core.runs_subruns'][0] - run*1e5)
      lightInfoCont = _GetLightMetadata(run,subrun)

      print( "\t\tThe matching runs/subruns list :", lightInfoCont, "\n" )   
      downloadFiles = _GetLightFiles(lightInfoCont)

   else :
      global_subrun_list = metadata['dune.mx2x2_global_subrun_numbers']
      print( "\t\tThe matching global subrun numbers are :", global_subrun_list, "\n" )
 
      if args.spine and not args.mx2 : 
         downloadFiles = _GetSpineFiles(global_subrun_list,args.spine-justin)
      elif args.mx2 and not args.spine :
         downloadFiles = _GetMx2Files(global_subrun_list,args.mx2-justin)
      elif args.spine and args.mx2 :
         d1 = _GetSpineFiles(global_subrun_list,args.spine-justin)
         d2 = _GetMx2Files(global_subrun_list,args.mx2-justin) 
         downloadFiles = d1 + d2
   

   print( "Exit getting the input list of matching files." )
   print( "\tThe number of files is [%d].\n" % downloadFiles ) 



