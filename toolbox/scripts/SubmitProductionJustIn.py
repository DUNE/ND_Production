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
    usage     = """ The Data Production for Near Detector Processing """
    formatter = TitledHelpFormatter( indent_increment=5, max_help_position=50, width=300, short_first=10 )
    parser    = OptionParser( formatter = formatter, usage = usage )

    # 2x2 job parameters
    parser.add_option("-d", "--dataset", dest="dataset", type="string", default=None, help="name of the Metacat dataset [required]")
    parser.add_option("-s", "--software", dest="software", type="string", default="v00_00_01d0", help="software release for processing [default: %default]")
    parser.add_option("-n", "--nfiles", dest="nfiles", type="int", default=-1, help="the number of files to process in the dataset [default is all files in the dataset]") 
    parser.add_option("-e", "--nevts", dest="nevts", type="int", default=-1, help="the number of events to process in the option file [default is all events per file]")
    parser.add_option("-j", "--jobscript", dest="jobscript", type="string", default="NDLarFlowProduction.jobscript", help="name of the job processing script [default: %default]")
    parser.add_option("--outdir", dest="outdir", type="string", default="/pnfs/dune/scratch/users/%s/ProductionDataFor2x2"%USER, help="name of the top output directory [default: %default]")
    parser.add_option("--debug", dest="debug", default=False, action="store_true", help="run in debug mode")
    parser.add_option("--tier", dest="tier", type="string", default="flow", help="the data tier for processing (flow, reco_pandora, reco_spine, caf) [default: %default]")
    parser.add_option("--stream", dest="stream", type="string", default="", help="the input data stream (light, charge, combined, calibrated, reco) [default: %default]")
    parser.add_option("--detector", dest="detector", type="string", default="proto_nd", help="the detector configuration (proto_nd, fsd, ndlar) [default: %default]")

    parser.add_option("--run-caf-pandora-spine-mx2", dest="run-caf-pandora-spine-mx2", default=False, action="store_true", help="Make cafs for pandora, spine, and mx2 reco. Input dataset must be pandora.")
    parser.add_option("--run-caf-pandora", dest="run-caf-pandora", default=False, action="store_true", help="Make cafs for pandora reco only.")
    parser.add_option("--run-caf-spine", dest="run-caf-spine", default=False, action="store_true", help="Make cafs for spine reco only.")
    parser.add_option("--run-caf-mx2", dest="run-caf-mx2", default=False, action="store_true", help="Make cafs for mx2 reco only.")
    parser.add_option("--run-caf-pandora-spine", dest="run-caf-pandora-spine", default=False, action="store_true", help="Make cafs for pandora and spine reco. Input dataset must be pandora.")
    parser.add_option("--run-caf-pandora-mx2", dest="run-caf-pandora-mx2", default=False, action="store_true", help="Make cafs for pandora and mx2 reco. Input dataset must be pandora.")
    parser.add_option("--run-caf-spine-mx2", dest="run-caf-spine-mx2", default=False, action="store_true", help="Make cafs for spine and mx2 reco only. Input dataset must be spine")

    parser.add_option("--spine-workflow-id", dest="spine-workflow-id", default=1, type=string, help="The spine justin workflow id for making cafs. This is required for the options: --run-caf-pandora-spine-mx2, --run-caf-pandora-spin")
    parser.add_option("--mx2-workflow-id", dest="mx2-workflow-id", default=1, type=string, help="The mx2 justin workflow id for making cafs. This is required for the options: --run-caf-pandora-spine-mx2, --run-caf-pandora-mx2, --run-caf-spine-mx2") 

    parser.add_option("--data", dest="data", default=False, action="store_true", help="processing real data")
    parser.add_option("--mc", dest="mc", default=False, action="store_true", help="processing simulated data")
    parser.add_option("--run", dest="run", type="string", default="run1", help="The run period.")
    parser.add_option("--rse", dest="rse", default=False, action="store_true", help="Outputs go to a rucio storage element")

    # h5flow parameters
    parser.add_option("--start_position", dest="startPosition", type=int, default=None, help="start position within source dset (for partial file processing)")
    parser.add_option("--end_position", dest="endPosition", type=int, default=None, help="end position within source dset (for partial file processing)")
    
    # justin submit parameters
    parser.add_option("--test-jobscript", dest="testJobscript", default=False, action="store_true", help="test the jobscript")
    parser.add_option("--memory", dest="memory", type="int", default=2000, help="the requested worker node memory usage [default: %default]")
    parser.add_option("--maxDistance", dest="maxDistance", type="int", default=102, help="the max distance for reading from storage [default: %default]")
    parser.add_option("--lifetime", dest="lifetime", type="int", default=7, help="rucio lifetime for output files [default: %default]")
    parser.add_option("--processors", dest="processors", type="int", default=1, help="the number of processors required [default: %default]") 
    parser.add_option("--wallTime", dest="wallTime", type="int", default=3600, help="the maximum wall seconds [default: %default]")
    parser.add_option("--nersc", dest="nersc", default=False, action="store_true", help="Submit the job to NERSC facility")
    parser.add_option("--gpu", dest="gpu", default=False, action="store_true", help="The job requires a gpu")
    parser.add_option("--scope", dest="scope", default="usertests", type="string", help="The scope of the justin job [default: %default]")

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


#=============================================
# Check the dataset validity
#=============================================
def _CheckDataset( dataset ) :
    success = True
    print( "\tChecking the validity of the dataset." )

    proc = subprocess.Popen(f'metacat dataset show {dataset}', stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)  
    stdout, error = proc.communicate()
    if proc.returncode != 0 :
       print(stdout)
       success = False

    print( f'\tCompleted checking the validity of the dataset [{dataset}].' )
    return success


#======================================================================================================
# For processing the combined light and charge files, verfied that the correct dataset is deployed
#======================================================================================================
def _CheckDatasetForCombinationWorkflow( dataset, detector ) :

    success  = False
    run_type = ""

    if detector == "proto_nd" :
       run_type = "neardet-2x2-lar-charge"
    elif detector == "fsd" :
       run_type = "neardet-fsd-lar-charge"
    else :
       sys.exit("Unable to determine if the correct dataset is deployed for the light+charge combination workflow.\n")

    cmds = [ "metacat query -s \"files from %s\" | grep -i Files | cut -f2 -d':'" % (dataset),
             "metacat query -s \"files from %s where (core.run_type=%s)\" | grep -i Files | cut -f2 -d':'" % (dataset,run_type) ]

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
       sys.exit( "FATAL::The files in dataset [%s, %d] do not belong to the run_type [%s]. Cannot proceed with combination workflow.\n" % (dataset,nfiles[0],run_type) )

    return success


#======================================================================================================
# For processing the reconstructed files via the cafmaker, verfied that the correct dataset is deployed
#======================================================================================================
def _CheckDatasetForCafWorkflow( opts ) :

    success   = False
    data_tier = ""

    if opts["run-caf-pandora-spine-mx2"] or opts["run-caf-pandora-spine"] or opts["run-pandora-mx2"] or opts["run-pandora"] :
       data_tier = "pandora-reconstruction"        
    elif opts["run-caf-spine-mx2"] or opts["run-caf-spine"] :
       data_tier = "spine-reconstruction"    
    elif opts["run-caf-mx2"] : 
       data_tier = "dst-reconstructed"
    else :
       sys.exit("Unable to determine if the correct dataset is deployed for the caf workflow.\n")

    cmd  = "metacat query -s \"files from %s where (core.data_tier=%s)\" | grep -i Files | cut -f2 -d':'" % (dataset,data_tier) 
    proc = proc.communicate()[0].decode('ascii')
    pipe   = proc.communicate()[0].decode('ascii') 
    if proc.returncode != 0 :
       sys.exit("Failed in sanity check for caf  workflow.\n")

    if int(pipe) > 0 :
       success = True
    else :
       sys.exit( "FATAL::This is the incorrect type of dataset to use as input. Please see the help menu." ) 

    return success



#======================================================================================================
# Get the number of files in a dataset
#======================================================================================================
def _GetNFilesInDataset( dataset ) :

   cmd  = "metacat query -s \"files from %s\" | grep -i Files | cut -f2 -d':'" % dataset
   proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
   pipe = proc.communicate()[0].decode('ascii')
   if proc.returncode != 0 :
      sys.exit("Cannot retrieve the number of files in dataset [%s]" % dataset)
   files_in_dataset = int(pipe)
  
   return files_in_dataset



##########################################################################
#  main block for processing the data
##########################################################################

if __name__ == '__main__' :

   print( "Enter launch the near detector production jobs via justIN\n" )

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


   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   # check the validity of the dataset
   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   success = _CheckDataset( opts['dataset'] )
   if not success :
      sys.exit( "\nThis is not a good dataset. Check the quality of the dataset [%s]." % opts['dataset'] )


   #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   # check that the correct dataset is deployed for the ndlar + combined workflow
   #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   if opts["tier"] == "flow" and opts["stream"] == "combined" :
      print( "\tChecking if the dataset for the ndlar flow charge and light combination workflow." )
      log.write( "\tChecking if the dataset for the ndlar flow charge and light combination workflow." )

      success = _CheckDatasetForCombinationWorkflow( opts['dataset'], opts["detector"] ) 
      if not success :
         sys.exit( "\nThe incorrect type of dataset is deployed for the ndlar_flow stage:combination workflow.\nThe input dataset should consists of light raw data.\n" ) 


   #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   # check that the correct dataset is deployed for the caf workflow
   #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   if opts["tier"] == "caf" :
      print( "\tChecking if the dataset for the caf workflow." )
      log.write( "\tChecking if the dataset for the caf workflow." )

      success = _CheckDatasetForCafWorkflow( opts )
      if not success :
         sys.exit( "\nThe incorrect type of dataset is deployed for the caf workflow.\nPlease see the help menu.\n")


   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   # output directory
   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   topdir = opts["outdir"]
   subdir = dt.datetime.now().strftime("%Y-%m-%d-%H-%M-%S")

   if topdir.find("/pnfs") == -1 :
      outdir = topdir
   else :
       outdir = "%s/%s/%s" % (topdir,opts['software'],subdir)

   if not opts["testJobscript"] :
      if not os.path.isdir(outdir) :
         if outdir.find("/pnfs") == -1 :
            print( "\tthe output directory [%s] is not on pnfs. will not create." % outdir )
            log.write( "\tthe output directory [%s] is not on pnfs. will not create." % outdir )
         else : 
            print( "\tcreating the output directory [%s]" % outdir )
            log.write( "\tcreating the output directory [%s]" % outdir )
            os.umask(0)
            os.makedirs(outdir,mode=0o1775)
            os.makedirs("%s/data"%outdir,mode=0o1775)
            os.makedirs("%s/logs"%outdir,mode=0o1775)
            os.makedirs("%s/json"%outdir,mode=0o1775)
      else :
         print( "\tThe output directory [%s] already exist!" % outdir )
         log.write( "\tThe output directory [%s] already exist!\n" % outdir )



   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   # get the input parameters for running
   #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   cmdlist = []
 
   # get the number of files
   nfiles = opts["nfiles"]
   files_in_dataset = _GetNFilesInDataset(opts["dataset"]) 

   if nfiles == -1 :
      nfiles = files_in_dataset 
   
   log.write( "\tRequest to process files [%d / %d]" % (nfiles,files_in_dataset) )
   print( "\tRequest to process files [%d / %d]" % (nfiles,files_in_dataset) )
   
   
   # set the metacat query 
   cmdlist.append( "--mql \"files from %s limit %d\"" % (opts["dataset"],nfiles) )


   # get the jobscript
   jobscript = "%s/%s" % (PWD,opts["jobscript"])
   cmdlist.append( "--jobscript %s" % jobscript)


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
   cmdlist.append( "--env RUN_PERIOD=%s" % opts["run"] )

   if opts["startPosition"] == None :
      cmdlist.append( "--env START_POSITION=None" )
   else :
      cmdlist.append( "--env START_POSITION=%d" % opts["startPosition"] )
   if opts["endPosition"] == None :
      cmdlist.append( "--env END_POSITION=None" )
   else :
      cmdlist.append( f"--env END_POSITION=%d" % opts["endPosition"] )

   cmdlist.append( "--env RUN_CAF_PANDORA_SPINE_MX2=%d" % (1 if opts["run-caf-pandora-spine-mx2"] else 0) )
   cmdlist.append( "--env RUN_CAF_PANDORA=%d" % (1 if opts["run-caf-pandora"] else 0) )
   cmdlist.append( "--env RUN_CAF_PANDORA_SPINE=%d" % (1 if opts["run-caf-pandora-spine"] else 0) )
   cmdlist.append( "--env RUN_CAF_PANDORA_MX2=%d" % (1 if opts["run-caf-pandora-mx2"] else 0) )
   cmdlist.append( "--env RUN_CAF_SPINE_MX2=%d" % (1 if opts["run-caf-spine-mx2"] else 0) )
   cmdlist.append( "--env RUN_CAF_SPINE=%d" % (1 if opts["run-caf-spine"] else 0) )
   cmdlist.append( "--env RUN_CAF_MX2=%d" % (1 if opts["run-caf-mx2"] else 0) )

   cmdlist.append( "--env SPINE_WORKFLOW_ID=%s" % opts["spine-workflow-id"] )
   cmdlist.append( "--env MX2_WORKFLOW_ID=%s % opts["mx2-workflow-id"] )


   # set nersc parameters
   if opts["nersc"] :
      if not opts["gpu"] :
         cmdlist.append( "--site US_NERSC-CPU" )
      else :
         cmdlist.append( "--site US_NERSC-GPU" )
         cmdlist.append( "--gpu" ) 
 
   # other justin parameters
   if not opts["testJobscript"] :
      cmdlist.append( "--max-distance %d" % opts["maxDistance"] )
      cmdlist.append( "--rss-mib %d" % opts["memory"] )
      cmdlist.append( "--lifetime-days %d" % opts["lifetime"] )
      cmdlist.append( "--wall-seconds %d" % opts["wallTime"] )
      cmdlist.append( "--processors %d" % opts["processors"] )
      cmdlist.append( "--scope %s" % opts["scope"] )

   # set the output directories
   if not opts["testJobscript"] :
      WRITE_DIR=outdir
 
      if opts["outdir"].find("pnfs") != -1 :
         tmp_outdir = outdir.replace("/pnfs/","/")
         WRITE_DIR = "https://fndcadoor.fnal.gov:2880%s" % tmp_outdir

      log.write( "\t\tThe top output directory is [%s]" % WRITE_DIR )
      print( "\t\tThe top output directory is [%s]" % WRITE_DIR )

      dtype = "hdf5" if opts["tier"] == "flow" else "root"
    
      if not opts["rse"] : 
         cmdlist.append( "--output-pattern='*.%s:%s/data'" % (dtype,WRITE_DIR) )
         cmdlist.append( "--output-pattern='*.log:%s/logs'" % WRITE_DIR )
         cmdlist.append( "--output-pattern='*.json:%s/json'" % WRITE_DIR )
      else :
         cmdlist.append( "--output-pattern *.log:%s" % WRITE_DIR )
         cmdlist.append( "--output-pattern *.%s:%s" % (dtype,WRITE_DIR) ) 
                 

   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   # run justIn launch submission
   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   cmdstring = " ".join(cmdlist)
   cmd       = "justin-test-jobscript %s" % (cmdstring) if opts["testJobscript"] else "justin get-token; justin simple-workflow %s" % (cmdstring)

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
  
   if not opts["testJobscript"] and os.path.isdir(outdir) : 
      shutil.move( PWD+"/justin_submission.log", outdir )
      print( "\n\tDirectory for output files [%s]" % outdir )
      print( "\n\tSubmission file is here [%s/justin_submission.log]" % outdir ) 


   print( "Exit launch near detector production jobs for [%s, %s]\n\n" % (opts["detector"],opts["tier"]) )
