#!/bin/env python

import os, sys, string, re, shutil, math, time, subprocess, json
import datetime as dt
from optparse import OptionParser, TitledHelpFormatter

#environment variables
PWD = str(os.environ.get('PWD'))
USER = str(os.environ.get('USER'))


#========================================
# Get the options from the Help Menu
#========================================
def _HelpMenu() :

    # set up the parser
    usage     = """ The Data Production for 2x2 Processing """
    formatter = TitledHelpFormatter( indent_increment=5, max_help_position=50, width=300, short_first=10 )
    parser    = OptionParser( formatter = formatter, usage = usage )

    # 2x2 job parameters
    parser.add_option("-d", "--dataset", dest="dataset", type="string", default=None, help="name of the Metacat dataset [required]")
    parser.add_option("-s", "--software", dest="software", type="string", default="v00_00_01d0", help="software release for processing [default: %default]")
    parser.add_option("-n", "--nfiles", dest="nfiles", type="int", default=-1, help="the number of files to process in the dataset [default is all files in the dataset]") 
    parser.add_option("-e", "--nevts", dest="nevts", type="int", default=-1, help="the number of events to process in the option file [default is all events per file]")
    parser.add_option("-j", "--jobscript", dest="jobscript", type="string", default="2x2Production.jobscript", help="name of the job processing script [default: %default]")
    parser.add_option("--outdir", dest="outdir", type="string", default="/pnfs/dune/scratch/users/%s/2x2ProductionData"%USER, help="name of the top output directory [default: %default]")
    parser.add_option("--debug", dest="debug", default=False, action="store_true", help="run in debug mode")
    parser.add_option("--tier", dest="tier", type="string", default="flow", help="the data tier for processing (flow) [default: %default]")
    parser.add_option("--stream", dest="stream", type="string", default="light", help="the data stream (light,charge,or combined) [default: %default]")
    parser.add_option("--detector", dest="detector", type="string", default="proto_nd", help="the detector configuration [default: %default]")
    parser.add_option("--metadata", dest="metadata", default=False, action="store_true", help="create json file with metadata")
    parser.add_option("--data", dest="data", default=False, action="store_true", help="processing real data")
    parser.add_option("--mc", dest="mc", default=False, action="store_true", help="processing simulated data")
    parser.add_option("--production", dest="production", default=False, action="store_true", help="using production (shifter) role")
 


    # h5flow parameters
    parser.add_option("--start_position", dest="startPosition", type=int, default=-1, help="start position within source dset (for partial file processing)")
    parser.add_option("--end_position", dest="endPosition", type=int, default=-1, help="end position within source dset (for partial file processing)")
    

    # justin submit parameters
    parser.add_option("--test-jobscript", dest="testJobscript", default=False, action="store_true", help="test the jobscript")
    parser.add_option("--namespace", dest="namespace", type="string", default="neardet-2x2-minerva", help="the namespace for the input files [default: %default]")
    parser.add_option("--memory", dest="memory", type="int", default=2000, help="the requested worker node memory usage [default: %default]")
    parser.add_option("--maxDistance", dest="maxDistance", type="int", default=0, help="the max distance for reading from storage [default: %default]")
    parser.add_option("--lifetime", dest="lifetime", type="int", default=1, help="rucio lifetime for output files [default: %default]")
    parser.add_option("--processors", dest="processors", type="int", default=1, help="the number of processors required [default: %default]") 
    parser.add_option("--wallTime", dest="wallTime", type="int", default=80000, help="the maximum wall seconds [default: %default]")


    (opts, args) = parser.parse_args(sys.argv)
    opts = vars(opts)

    return opts


#=============================================
# Check that certain variables are setup
#=============================================
def _CheckEnvironment() :
    success = True

    print( "\tChecking the environment.")    

    proc   = subprocess.Popen("metacat", stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    stdout, error = proc.communicate()
    error  = error.decode("utf-8").split("\n")
    if len([ e for e in error if 'metacat: command not found' in e ]) == 0 :
       print( "\t\tmetacat is setup" )
    else : 
       print( "\tPlease run 'setup metacat' in your current shell." )
       success = False
   
 
    METCAT_SERVER_URL = str(os.environ.get('METACAT_SERVER_URL'))
    if METCAT_SERVER_URL.find("https://metacat.fnal.gov:9443/dune_meta_prod/app") == -1 :
       print( "\tPlease run 'export METACAT_SERVER_URL=https://metacat.fnal.gov:9443/dune_meta_prod/app' in your current shell." )
       success = False
    else :
       print( "\t\tMETCAT_SERVER_URL is [%s]" % METCAT_SERVER_URL )


    METACAT_AUTH_SERVER_URL = str(os.environ.get('METACAT_AUTH_SERVER_URL'))
    if METACAT_AUTH_SERVER_URL.find("https://metacat.fnal.gov:8143/auth/dune") == -1 :
       print( "\tPlease run 'export METACAT_AUTH_SERVER_URL=https://metacat.fnal.gov:8143/auth/dune' in your current shell." )
       success = False
    else :
       print( "\t\tMETACAT_AUTH_SERVER_URL is [%s]" % METACAT_AUTH_SERVER_URL )


    proc   = subprocess.Popen("python --version", stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    stdout, error = proc.communicate()
    stdout = stdout.decode("utf-8").split("\n")
    if not "Python 3.9.15" in stdout :
       print( "\tPlease run 'setup python v3_9_15' in your current shell." )
       success = False
    else :
       print( "\t\tpython 3.9.15 is setup")


    proc   = subprocess.Popen("justin", stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    stdout, error = proc.communicate()
    error  = error.decode("utf-8").split("\n")
    if len([ e for e in error if 'justin: command not found' in e ]) == 0 :
       print( "\t\tjustin is setup" )
    else :
       print( "\tPlease run 'setup justin' in your current shell." )
       success = False


    proc = subprocess.Popen("justin time", stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    stdout, error = proc.communicate()
    error  = error.decode("utf-8").split("\n")
    if len(error) > 1 :
       print( "\n")
       for e in error :
           print("\t%s" % e.strip())
       print( "\tPlease follow the instruction above to authorize justin.\n")
       success = False
    else :
       print( "\t\tjustin is authorized to run on this computer." )


    print( "\tCompleted checking the environment variables." )
    return success



#======================================================================================================
# For processing the combined light and charge files, verfied that the correct dataset is deployed
#======================================================================================================
def _CheckDatasetForCombinationWorkflow( dataset, detector ) :

    success  = False
    run_type = ""

    if detector == "proto_nd" :
       run_type = "neardet-2x2-lar-charge"
    else :
       sys.exit("Unable to determine if the correct dataset is deployed for the light+charge combination workflow.\n")

    cmds = [ "metacat query -s \"files from %s\" | grep -i Files | cut -f2 -d':'" % (dataset),
             "metacat query -s \"files from %s having core.run_type=%s\" | grep -i Files | cut -f2 -d':'" % (dataset,run_type) ]

    nfiles = []
    for cmd in cmds :
        proc   = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
        pipe   = proc.communicate()[0].decode('ascii')
        if proc.returncode != 0 :
           sys.exit("Failed in sanity check for light+chare combination workflow.\n")
        nfiles.append( int(pipe) )

    if nfiles[0] == nfiles[1] :
       success = True
    else :
       sys.exit( "All files in dataset [%s, %d] do not belong to the run_type [%s]. Cannot proceed with combination workflow.\n" % (dataset,nfiles[0],run_type) )

    return success




##########################################################################
#  main block for processing the data
##########################################################################

if __name__ == '__main__' :

   print( "Enter launch the 2x2 production jobs via justIN\n" )

   #+++++++++++++++++++++++++++++++++++++++++++++
   # create a submission log
   #+++++++++++++++++++++++++++++++++++++++++++++
   log = open("justin_submission.log", "w+")
   log.write( "Enter launch the 2x2 production jobs via justIN\n" )


   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   # set the help menu and get options
   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   opts = _HelpMenu()
 
   if opts['dataset'] == None :
      log.write( "Please see the help menu. The Metacat dataset is required.\n")
      log.close()
      sys.exit("Please see the help menu. The Metacat dataset is required.")


   if opts['jobscript'] == None :
      log.write( "Please see the help menu. The jobscript file name is required.\n" )
      log.close()
      sys.exit("Please see the help menu. The jobscript file name is required.")


   print( "\nThe user [%s] is running SubmitProductionJustIN.py.\n" % USER )
   log.write( "\nThe user [%s] is running SubmitProductionJustIN.py.\n" % USER )

   
   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   # check if justin and metacat are setup
   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   success = _CheckEnvironment()
   if not success :
      sys.exit( "\nAll environment variables are not setup!\n" )


   #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   # check that the correct dataset is deployed for ndlar + combined workflow
   #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   if opts["tier"] == "flow" and opts["stream"] == "combined" :
      success = _CheckDatasetForCombinationWorkflow( opts['dataset'], opts["detector"] ) 
      if not success :
         sys.exit( "\nThe incorrect type of dataset is deployed for ndlar_flow stage:combination workflow.\nThe input dataset should consists of light raw data.\n" ) 


   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   # output directory
   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   topdir = opts["outdir"]
   subdir = dt.datetime.now().strftime("%Y-%m-%d-%H-%M-%S")
   outdir = "%s/%s" % (topdir,subdir)
   if not opts["testJobscript"] :
      if not os.path.isdir(outdir) :
         print( "\tcreating the output directory [%s]" % outdir )
         log.write( "\tcreating the output directory [%s]" % outdir )
         os.umask(0)
         os.makedirs(outdir,mode=0o1775)
         os.makedirs("%s/data"%outdir,mode=0o1775)
         os.makedirs("%s/logs"%outdir,mode=0o1775)
         os.makedirs("%s/json"%outdir,mode=0o1775)
         os.makedirs("%s/config"%outdir,mode=0o1775)
      else :
         print( "\tThe output directory [%s] already exist!" % outdir )
         log.write( "\tThe output directory [%s] already exist!\n" % outdir )



   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   # get the input parameters for running
   #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   cmdlist = []
 
   # get the number of files
   nfiles = opts["nfiles"]
   cmd    = "metacat query -s \"files from %s\" | grep -i Files | cut -f2 -d':'" % opts["dataset"]
   proc   = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
   pipe   = proc.communicate()[0].decode('ascii')
   if proc.returncode != 0 :
      log.write("Cannot retrieve the number of files in dataset [%s]" % opts["dataset"])
      sys.exit("Cannot retrieve the number of files in dataset [%s]" % opts["dataset"])
   files_in_dataset = int(pipe)

   if nfiles == -1 :
      nfiles = files_in_dataset 
   
   log.write( "\tRequest to process files [%d / %d]" % (nfiles,files_in_dataset) )
   print( "\tRequest to process files [%d / %d]" % (nfiles,files_in_dataset) )
   
   
   # set the metacat query 
   cmdlist.append( "--mql \"files from %s limit %d\"" % (opts["dataset"],nfiles) )


   # get the jobscript
   jobscript = "%s/%s" % (PWD,opts["jobscript"])
   cmdlist.append( "--jobscript %s" % jobscript)


   # set the authenication
   auth = "kx509; voms-proxy-init -noregen -rfc -voms dune:/dune/Role=Analysis; htgettoken -a htvaultprod.fnal.gov -i dune"
   if opts["production"] :
      auth = "kx509; voms-proxy-init -noregen -rfc -voms dune:/dune/Role=Production; htgettoken -a htvaultprod.fnal.gov -i dune -r production"


   # determine the data type
   if opts["data"] and opts["mc"] :
      sys.exit( "The jobscript can not process both data and simulation, simultaneously" )
   elif not opts["data"] and not opts["mc"] :
      sys.exit( "The jobscript needs to know the data type [data (--data) or simulation (--mc)]")
   elif opts["data"] and not opts["mc"] :
      cmdlist.append( "--env DATA_TYPE=\"data\"" )
   elif not opts["data"] and opts["mc"] :
       cmdlist.append( "--env DATA_TYPE=\"mc\"" )


   # set environment variables
   run_tests       = 1 if opts["testJobscript"] else 0
   run_debug_mode  = 1 if opts["debug"] else 0

   cmdlist.append( "--env TWOBYTWO_RELEASE=\"%s\"" % opts["software"] )
   cmdlist.append( "--env DEBUG_SUBMISSION_SCRIPT=%d" % run_debug_mode )
   cmdlist.append( "--env DATA_TIER=\"%s\"" % opts["tier"] )
   cmdlist.append( "--env DATA_STREAM=\"%s\"" % opts["stream"] )
   cmdlist.append( "--env DETECTOR_CONFIG=\"%s\"" % opts["detector"] )
   cmdlist.append( "--env NEVENTS=%d" % opts["nevts"] )
   cmdlist.append( "--env JOBSCRIPT_TEST=%d" % run_tests )
   cmdlist.append( "--env USER=%s" % USER )

   file_metadata = "True" if opts["production"] or opts["metadata"] else "False"
   cmdlist.append( "--env MAKE_METADATA=%s" % file_metadata)


   cmdlist.append( "--env START_POSITION=%d" % opts["startPosition"] )
   cmdlist.append( "--env END_POSITION=%d" % opts["endPosition"] )
 
   # other justin parameters
   if not opts["testJobscript"] :
      cmdlist.append( "--max-distance %d" % opts["maxDistance"] )
      cmdlist.append( "--rss-mib %d" % opts["memory"] )
      cmdlist.append( "--lifetime-days %d" % opts["lifetime"] )
      cmdlist.append( "--wall-seconds %d" % opts["wallTime"] )
      cmdlist.append( "--processors %d" % opts["processors"] )

   # set the output directories
   if not opts["testJobscript"] : 
      if opts["outdir"].find("pnfs") != -1 :
         tmp_outdir = outdir.replace("/pnfs/","/")
         DCACHEDIR = "https://fndcadoor.fnal.gov:2880%s" % tmp_outdir
         log.write( "\t\tThe top output directory is [%s]" % DCACHEDIR )
         print( "\t\tThe top output directory is [%s]" % DCACHEDIR )
  
         cmdlist.append( "--output-pattern='*.hdf5:%s/data'" % DCACHEDIR )
         cmdlist.append( "--output-pattern='*.yaml:%s/config'" % DCACHEDIR )
         cmdlist.append( "--output-pattern='*.log:%s/logs'" % DCACHEDIR )
         cmdlist.append( "--output-pattern='*.json:%s/json'" % DCACHEDIR )




   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   # run justIn launch submission
   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   cmdstring = " ".join(cmdlist)
   auth      = "kx509; voms-proxy-init -noregen -rfc -voms dune:/dune/Role=Analysis"
   cmd       = "%s; justin-test-jobscript %s" % (auth,cmdstring) if opts["testJobscript"] else "%s; justin simple-workflow %s" % (auth,cmdstring)

   print( "\n\tBelow is the launch command:\n\t%s\n\n" % cmd )
   log.write( "\n\tBelow is the launch command:\n\t%s\n\n" % cmd )

   proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)

   stdout, error = proc.communicate()
   stdout = stdout.decode("utf-8").split("\n")
   error  = error.decode("utf-8").split("\n")

   log.write( "\tCompleted launching the justin submission." )
   print( "\tCompleted launching the justin submission." )

   for s in stdout :
       log.write( "\t\tMessage: %s\n" % s)
       print( "\t\tMessage: %s" % s)
   for e in error :
       log.write( "\t\tError: %s\n" % e)
       print( "\t\tError: %s" % e)

   if proc.returncode != 0 : 
      log.write( "Unable to launch jobs successful." )
      log.close()
      sys.exit( "Unable to launch jobs successful." )



   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   # end
   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   log.write( "Exit launch 2x2 production jobs\n\n" )
   log.close() 
  
   if not opts["testJobscript"] : 
      shutil.move( PWD+"/justin_submission.log", outdir )
      print( "\n\tDirectory for output files [%s]" % outdir )
      print( "\n\tSubmission file is here [%s/submission.log]" % outdir ) 


   print( "Exit launch 2x2 production jobs\n\n" )
