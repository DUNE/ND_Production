# create a script to run a customized ND production on the grid
from optparse import OptionParser
import os
import sys

N_TO_SHOW = 1000

def run_gen( sh, args ):
    print("\n\n\necho running genie", file=sh)
    print("echo Local files right now:\nls -alh", file=sh)
    mode = "neutrino" if args.horn == "FHC" else "antineutrino"
    fluxopt = ""
    maxmb = 100
    if args.use_dk2nu:
        fluxopt = "--dk2nu"
        maxmb = 300
    print("${ND_PRODUCTION_DIR}/bin/copy_dune_flux --top %s --flavor %s --maxmb=100 %s" % (args.fluxdir, mode, fluxopt), file=sh)
    print("ls flux_files/ -alh", file=sh)

    # Modify GNuMIFlux.xml to the specified off-axis position
    print("sed \"s/<beampos> ( 0.0, 0.05387, 6.66 )/<beampos> ( %1.2f, 0.05387, 6.66 )/g\" ${ND_PRODUCTION_CONFIG}/GNuMIFlux.xml > GNuMIFlux.xml" % args.oa, file=sh)
    if args.large_flux_window:
        print('''sed -i '/<point coord="det"> /s/-6.0,\s*-5.0,\s*-1.0/-45.0, -18.0, -40.0/g' GNuMIFlux.xml''', file=sh)
        print('''sed -i '/<point coord="det"> /s/6.0,\s*-5.0,\s*-1.0/15.0, -18.0, -40.0/g' GNuMIFlux.xml''', file=sh)
        print('''sed -i '/<point coord="det"> /s/6.0,\s*5.0,\s*-1.0/15.0, 27.0, -40.0/g' GNuMIFlux.xml''', file=sh)
        print('''sed -i '/<upstreamz> /s/-3/-40.0/g' GNuMIFlux.xml''', file=sh)
        print('cat GNuMIFlux.xml', file=sh)
        
  
    print("export GXMLPATH=${PWD}:${GXMLPATH}", file=sh)
    print("export GNUMIXML=\"GNuMIFlux.xml\"", file=sh)
    
    if args.b_field_location != None:
        assert args.b_field_filename != None, "Expected a b_field_filename in conjunction with b_field_location"
        print("ifdh cp %s %s" % (args.b_field_location, args.b_field_filename), file=sh)
        
        
    if "v3" in args.genie_tune:
        if args.manual_genie_xsec_file != None:
            print("GENIEXSECFILETOUSE=%s" % args.manual_genie_xsec_file, file=sh)
        else:
            if args.use_big_genie_file:
                print("GENIEXSECFILETOUSE=`dirname $GENIEXSECFILE`/gxspl-FNALbig.xml.gz", file=sh)
            else:
                print("GENIEXSECFILETOUSE=$GENIEXSECFILE", file=sh)
        
  
    # Run GENIE
    flux = "dk2nu" if args.use_dk2nu else "gsimple"
    print("gevgen_fnal \\", file=sh)
    print("    -f flux_files/%s*,DUNEND \\" % flux, file=sh)
    if args.manual_geometry_override != None:
        print("Using manual geometry override")
        print("    -g %s \\" % args.manual_geometry_override, file=sh)
    else:
        if args.anti_fiducial:
            print("USING ANTI FIDUCIAL:anti_fiducial_%s.gdml" % args.geometry)
            print("    -g ${ND_PRODUCTION_GDML}/anti_fiducial_%s.gdml \\" % args.geometry, file=sh)
        else:
            print("    -g ${ND_PRODUCTION_GDML}/%s.gdml \\" % args.geometry, file=sh)
    print("    -t %s \\" % args.topvol, file=sh)
    print("    -L cm -D g_cm3 \\", file=sh)
    print("    -e %g \\" % args.pot, file=sh)
    print("    --seed ${SEED} \\", file=sh)
    print("    -r ${RUN} \\", file=sh)
    print("    -o %s \\" % mode, file=sh)
    print("    --message-thresholds ${ND_PRODUCTION_CONFIG}/Messenger_production.xml \\", file=sh)
    print("    --event-record-print-level 0 \\", file=sh)
    # Needed for genie3
    if "v3" in args.genie_tune:
        print("    --cross-sections $GENIEXSECFILETOUSE --tune $GENIE_XSEC_TUNE ", file=sh)
    else:
        print("    --cross-sections ${GENIEXSECPATH}/gxspl-FNALsmall.xml \\", file=sh)
        print("    --event-generator-list Default+CCMEC", file=sh)

    # Copy the output
    print("""# Store the exit code of the previous command
exit_code=$?
if [ $exit_code -ne 0 ]; then
# Print an error message to stderr (cerr)
echo "Error: genie failed with exit code $exit_code" >&2
echo "Error: genie failed with exit code $exit_code"
# Exit the script with a non-zero exit code
exit $exit_code
fi""", file=sh)
 
    


def run_tms( sh, args ):
    print("\n\n\necho running TMS", file=sh)
    print("echo Local files right now:\nls -alh", file=sh)
    global N_TO_SHOW
    #print >> sh, "ifdh cp /cvmfs/dune.osgstorage.org/pnfs/fnal.gov/usr/dune/persistent/stash/ND_simulation/production_v01/dune-tms.tar.gz dune-tms.tar.gz"
    #print >> sh, "ifdh cp " + args.tms_reco_tar + " dune-tms.tar.gz"
    #print >> sh, "tar -xzvf dune-tms.tar.gz"
    print("cd $INPUT_TAR_DIR_LOCAL/dune-tms; . setup.sh; cd -", file=sh)
    if "v3" in args.genie_tune:
      print("setup edepsim v3_2_0 -q e20:prof", file=sh)
    else:
      print("setup edepsim v3_0_1b -q e17:prof", file=sh)
    if not any(x in stages for x in ["gen", "genie", "generator"]):
      print("filename=${allfiles[${PROCESS}]}", file=sh)
      print("basefilename=`basename $filename`", file=sh)
      print("ifdh cp ${filename} ${basefilename}", file=sh)
      print("EDEP_OUTPUT_FILE=${basefilename}", file=sh)
      print("EDEP_FILE=${EDEP_OUTPUT_FILE}", file=sh)
    
    print("$INPUT_TAR_DIR_LOCAL/dune-tms/bin/ConvertToTMSTree.exe ${EDEP_OUTPUT_FILE}", file=sh)
    # Copy the output
    print("""# Store the exit code of the previous command
exit_code=$?
if [ $exit_code -ne 0 ]; then
# Print an error message to stderr (cerr)
echo "Error: tms failed with exit code $exit_code" >&2
echo "Error: tms failed with exit code $exit_code"
# Exit the script with a non-zero exit code
#exit $exit_code
fi""", file=sh)
    # Finds the name regardless of which algs were turned on.
    # Names like neutrino.0.edep_LineCandidates_AStar_Cluster1.root
    print("TMS_OUTPUT_FILE=`ls ${EDEP_OUTPUT_FILE/.root/_TMS_RecoCandidates_*.root}`", file=sh)
    print("TMS_READOUT_FILE=`ls ${EDEP_OUTPUT_FILE/.root/_TMS_Readout.root}`", file=sh)
    # Example name: neutrino.0.edep_TMS_EventViewer_AStar_Cluster1.pdf
    print("TMS_PDF_FILE=", file=sh) # First make it blank
    print("TMS_PDF_FILE=`ls ${EDEP_OUTPUT_FILE/.root/_*.pdf}`", file=sh) # Now try to get the pdf file
    

def run_g4( sh, args ):
    print("\n\n\necho running edep sim", file=sh)
    print("echo Local files right now:\nls -alh", file=sh)
    mode = "neutrino" if args.horn == "FHC" else "antineutrino"

    # Get the input file
    if any(x in stages for x in ["gen", "genie", "generator"]):
        # Then we just made the GENIE file, and it's sitting in the working directory
        print("cp %s.${RUN}.ghep.root input_file.ghep.root" % mode, file=sh)
    else:
        # We need to get the input file
        #print >> sh, "ifdh cp %s/genie/%s/%02.0fm/${RDIR}/%s.${RUN}.ghep.root input_file.ghep.root" % (args.indir, args.horn, args.oa, mode)
        print("filename=${allfiles[${PROCESS}]}", file=sh)
        print("ifdh cp $filename input_file.ghep.root", file=sh)
        # Need to pick run based on the filename
        #print >> sh, "basefilename=`basename $filename`"
        #print >> sh, """RUN=$(echo "$basefilename" | grep -oE '[0-9]+' | head -1)"""
        #print >> sh, "RDIR=$((${RUN} / 1000))"
        #print >> sh, "if [ ${RUN} -lt 10000 ]; then"
        #print >> sh, "RDIR=0$((${RUN} / 1000))"
        #print >> sh, "fi"
        

    # Needed for genie3, rootracker file changed between versions.
    if "v3" in args.genie_tune and False:
        print("setup dk2nugenie   v01_06_01f -q e17:prof", file=sh)
        print("setup genie_xsec   v2_12_10   -q DefaultPlusValenciaMEC", file=sh)
        print("setup genie_phyopt v2_12_10   -q dkcharmtau", file=sh)
    # convert to rootracker to run edep-sim
    print("gntpc -i input_file.ghep.root -f rootracker --event-record-print-level 0 --message-thresholds ${ND_PRODUCTION_CONFIG}/Messenger_production.xml", file=sh)

    # Get the number of events in the genie file
    # if we're doing overlay, then we want to get the poisson mean and then the number of spills, and be careful not to overshoot
    if args.overlay:
        print("MEAN=$(echo \"std::cout << gtree->GetEntries()*(%3.3g/%3.3g) << std::endl;\" | genie -l -b input_file.ghep.root 2>/dev/null  | tail -1)" % (args.spill_pot, args.pot), file=sh)
        print("NSPILL=$(echo \"std::cout << (int)floor(0.9*gtree->GetEntries()/${MEAN}) << std::endl;\" | genie -l -b input_file.ghep.root 2>/dev/null  | tail -1)", file=sh)

        # change the macro to use mean
        print("sed \"s/count\/set fixed/count\/set mean/g\" ${ND_PRODUCTION_CONFIG}/dune-nd.mac > dune-nd.mac", file=sh)
        print("sed -i \"s/count\/fixed\/number 1/count\/mean\/number ${MEAN}/g\" dune-nd.mac", file=sh)
    else:
        print("NSPILL=$(echo \"std::cout << gtree->GetEntries() << std::endl;\" | genie -l -b input_file.ghep.root 2>/dev/null  | tail -1)", file=sh)
        print("cat ${ND_PRODUCTION_CONFIG}/dune-nd.mac > dune-nd.mac", file=sh)
        if args.event_multiplicity > 1:
            print("sed -i \"s/count\/fixed\/number 1/count\/fixed\/number %s/g\" dune-nd.mac" % args.event_multiplicity, file=sh)
            
    
    should_simulate_spill_time = False
    if args.timing == "spill": should_simulate_spill_time = True
    elif args.timing == "fixed": should_simulate_spill_time = False
    elif args.timing == "default":
        # By default we only want a random time more than one event per spill
        if args.overlay: should_simulate_spill_time = True
        elif args.event_multiplicity > 1: should_simulate_spill_time = True
        else: should_simulate_spill_time = False
    else: raise ValueError("Don't understand timing option '%s'" % args.timing)
    if should_simulate_spill_time:
        # Change the macro to use a random time using a batch structure
        # /generator/time/set fixed -> time\/set spil
        # r'' option requires fewer \" but within sed's option we still need \/ to differentiate inside quotes sed -i 's/old-text/new-text/g' input.txt
        # https://github.com/ClarkMcGrew/edep-sim/blob/eaf8b1f8fc083c0a0e1a4d7f1efd413378e6d3df/src/kinem/EDepSimSpillTimeFactory.cc
        print(r'sed -i "s/\/generator\/time\/set fixed//g" dune-nd.mac', file=sh)
        print(r'sed -i "s/\/generator\/add//g" dune-nd.mac', file=sh)
        print("echo /generator/time/spill/start %s ns >> dune-nd.mac" % args.spill_start, file=sh)
        print("echo /generator/time/spill/bunchSep %s ns >> dune-nd.mac" % args.bunch_separation, file=sh)
        print("echo /generator/time/spill/bunchLength %s ns >> dune-nd.mac" % args.bunch_length, file=sh)
        print("echo /generator/time/spill/bunchCount %s >> dune-nd.mac" % args.bunch_count, file=sh)
        print("echo /generator/time/set spill >> dune-nd.mac", file=sh)
        print("echo /generator/add >> dune-nd.mac", file=sh) # Makes sure to update the generator based on parameters
        # TODO make batch structure changable with parameters

    # Get edep-sim
    # Needed for genie3, rootracker file changed between versions.
    if "v3" in args.genie_tune:
        print("setup edepsim v3_2_0 -q e20:prof", file=sh)
    else:
        print("setup edepsim v3_0_1b -q e17:prof", file=sh)
        
    print("EDEP_OUTPUT_FILE=%s.${RUN}.edep.root" % mode, file=sh)
    
    
    if args.b_field_location != None:
        assert args.b_field_filename != None, "Expected a b_field_filename in conjunction with b_field_location"
        print("ifdh cp %s %s" % (args.b_field_location, args.b_field_filename), file=sh)

    #Run it
    print("edep-sim -C \\", file=sh)
    if args.manual_geometry_override != None:
        print("Using manual geometry override")
        print("  -g %s \\" % args.manual_geometry_override, file=sh)
    else:
        print("  -g ${ND_PRODUCTION_GDML}/%s.gdml \\" % args.geometry, file=sh)
    print("  -o ${EDEP_OUTPUT_FILE} \\", file=sh)
    print("  -e ${NSPILL} \\", file=sh)
    print("  dune-nd.mac", file=sh)

    print("""# Store the exit code of the previous command
exit_code=$?
if [ $exit_code -ne 0 ]; then
# Print an error message to stderr (cerr)
echo "Error: edep-sim failed with exit code $exit_code" >&2
echo "Error: edep-sim failed with exit code $exit_code"
# Exit the script with a non-zero exit code
#exit $exit_code
fi""", file=sh)

def run_larcv( sh, args ):

    print("LArCV stage is not currently supported.  Sorry")
    return

    mode = "neutrino" if args.horn == "FHC" else "antineutrino"

    # Get the input file, unless we just ran edep-sim and it's sitting in the working directory
    if not any(x in stages for x in ["g4", "geant4", "edepsim", "edep-sim"]):
        print("setup edepsim v2_0_1 -q e17:prof", file=sh)
        print("ifdh cp %s/edep/%s/%02.0fm/${RDIR}/%s.${RUN}.edep.root %s.${RUN}.edep.root" % (args.indir, args.horn, args.oa, mode, mode), file=sh)

    # Get larcv stuff
    #print >> sh, "ifdh cp %s/larcv2.tar.bz2 larcv2.tar.bz2" % args.tardir
    #print >> sh, "bzip2 -d larcv2.tar.bz2"
    #print >> sh, "tar -xf larcv2.tar"

    # additional python setup needed
    print("setup python_future_six_request  v1_3 -q python2.7-ucs2", file=sh)

    # run LArCV2
    print(". larcv2/configure.sh", file=sh)
    print("supera_dir=${LARCV_BASEDIR}/larcv/app/Supera", file=sh)
    print("python ${supera_dir}/run_supera.py reco/larcv.cfg %s.${RUN}.edep.root" % mode, file=sh)


if __name__ == "__main__":

    user = os.getenv("USER")

    # Make a bash script to run on the grid
    # Start with the template with functions used for all jobs
    template = open("template.sh","r").readlines()
    sh = open( "processnd.sh", "w" )
    sh.writelines(template)

    parser = OptionParser()

    parser.add_option('--horn', help='FHC or RHC', default="FHC")
    parser.add_option('--horn_current', help='horn current (default is 300 for FHC, -300 for RHC', type = "float", default=None)
    parser.add_option('--geometry', help='Geometry file', default="nd_hall_lar_tms")
    parser.add_option('--topvol', help='Top volume for generating events (gen stage only)', default="volWorld")
    parser.add_option('--pot', help='POT per job', type = "float", default=1.e16)
    parser.add_option('--spill_pot', help='POT per spill', type = "float", default=7.5e13)
    parser.add_option('--first_run', help='First run number to use', default=0, type = "int")
    parser.add_option('--oa', help='Off-axis position in meters', default=0, type = "float")
    parser.add_option('--large_flux_window', help='Use a larger flux window', default=False, action="store_true")
    parser.add_option('--test', help='Use test mode (interactive job)', default=False, action="store_true")
    parser.add_option('--overlay', help='Simulate full spills (default is single events)', default=False, action="store_true")
    parser.add_option('--timing', help='Simulate a random time in spill. default/fixed/spill (default is 1ns for single events and a random spill time for overlay or event_multiplicity > 1). ', default = "default")
    parser.add_option('--event_multiplicity', help='The fixed number of events. Overwritten with overlay option. Useful if you want say a fixed 5 events per spill', default=1, type = "int")
    parser.add_option('--stages', help='Production stages (gen+g4+larcv+ana+tmsreco)', default="gen+g4+larcv+ana+tmsreco")
    parser.add_option('--persist', help='Production stages to save to disk(gen+g4+larcv+ana+tmsreco)', default="all")
    parser.add_option('--indir', help='Input file top-directory (if not running gen)', default="/pnfs/dune/persistent/users/%s/nd_production"%user)
    parser.add_option('--fluxdir', help='Specify the top-level flux file directory', default="/cvmfs/dune.osgstorage.org/pnfs/fnal.gov/usr/dune/persistent/stash/Flux/g4lbne/v3r5p4/QGSP_BERT/OptimizedEngineeredNov2017")
    parser.add_option('--outdir', help='Top-level output directory', default="/pnfs/dune/scratch/users/%s/nd_production"%user)
    parser.add_option('--use_dk2nu', help='Use full dk2nu flux input (default is gsimple)', action="store_true", default=False)
    parser.add_option('--sam_name', help='Make a sam dataset with this name', default="dune_nd_miniproduction_2021_v1")
    parser.add_option('--dropbox_dir', help='dropbox directory', default="/pnfs/dune/scratch/dunepro/dropbox/neardet")
    #parser.add_option('--tms_reco_tar', help='The tar file which contains the tms reco code', default='/cvmfs/dune.osgstorage.org/pnfs/fnal.gov/usr/dune/persistent/stash/ND_simulation/production_v01/dune-tms.tar.gz')
    parser.add_option('--data_stream', help='data_stream', default="physics")
    parser.add_option('--file_format', help='file format', default="root")
    parser.add_option('--application_family', help='application family', default="neardet")
    parser.add_option('--application_name', help='application name', default="nd_production,genie,edep-sim")
    parser.add_option('--application_version', help='application version', default="v01_04_00,v2_12_10,v3_0_1b")
    parser.add_option('--campaign', help='DUNE.campaign', default="dune_nd_miniproduction_2021_v1")
    parser.add_option('--requestid', help='DUNE.requestid', default="RITM1254894")
    parser.add_option('--tms_reco_tar', help='The tar file which contains the tms reco code', default='/pnfs/dune/persistent/stash/ND_simulation/production_v01/dune-tms.tar.gz')
    parser.add_option('--sam_input', help='Use a sam dataset with this name', default=None)

    parser.add_option('--anti_fiducial', help='anti fiducial using : anti_fiducial_geometry.gdml', default=False, action="store_true")
    parser.add_option('--manual_geometry_override', help='Advanced feature: Point to a specific geometry file (like in the tar input file). Useful if you want to remove rotation for example', default="nd_hall_with_lar_tms_sand_TDR_Production_geometry_v_1.0.3.gdml")
    parser.add_option("--geometry_location", help='Advanced feature: Point to a specific geometry file and it will be copied over. Use in conjunction with manual_geometry_override to point to the local copy after being copied over.', default="/pnfs/dune/persistent/physicsgroups/dunendsim/geometries/TDR_Production_geometry_v_1.0.3/nd_hall_with_lar_tms_sand_TDR_Production_geometry_v_1.0.3.gdml")
    parser.add_option('--b_field_location', help='Advanced feature: Point to a specific b field file (like in the tar input file).', default=None)
    parser.add_option('--b_field_filename', help='Advanced feature: Required in conjunction with b_field_location. Dictates the final name', default=None)
    parser.add_option('--genie_tune', help='Genie version', default="v3_02_02_p01")
    parser.add_option('--genie_xsec_version', help='genie_xsec version', default="v3_02_00")
    parser.add_option('--genie_options', help='Genie version', default="G1810a0211a:e1000:k250")
    parser.add_option('--genie_phyopt_version', help='Version of genie_phyopt', default="v3_02_00")
    parser.add_option('--genie_phyopt_options', help='Additional args for genie_phyopt', default="dkcharmtau")
    parser.add_option('--use_big_genie_file', help='whether to use gxspl-FNALbig.xml.gz', default=False, action="store_true")
    parser.add_option('--manual_genie_xsec_file', help='use this specific genie xsec file', default = None)
    parser.add_option('--spill_start', help='Spill start time in ns', type="float", default=0)
    parser.add_option('--bunch_separation', help='Separation of each bunch in a spill in ns', type="float", default=19.23077)
    parser.add_option('--bunch_length', help='Length of each bunch in a spill in ns', type="float", default=0)
    parser.add_option('--bunch_count', help='Number of bunches in a spill', type="int", default=520)
    
    

    (args, dummy) = parser.parse_args()

    mode = "neutrino" if args.horn == "FHC" else "antineutrino"
    hc = 300.
    if args.horn == "RHC":
        hc = -300.
    if args.horn_current is not None:
        hc = args.horn_current
    fluxid = 2
    if args.use_dk2nu:
        fluxid = 1

    if "cvmfs" not in args.fluxdir:
        print("WARNING: specified flux file directory:")
        print(args.fluxdir)
        print("is not in cvmfs. The flux setup probably will not work unless you really know what you are doing")
    if "persistent" in args.outdir:
        print("FATAL: Cannot use persistent in outdir. Please use scratch and then copy over.")
        exit()

    # Software setup -- eventually we may want options for this
    print("start_process_nd_run_time=`date +%s`", file=sh)
    print("source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh", file=sh)
    print("setup ifdhc", file=sh)
    if "v3" in args.genie_tune:
        print("setup dk2nugenie  v01_10_01c  -q e20:prof", file=sh)
        print("setup genie %s -q e20:prof" % args.genie_tune, file=sh)
        print("setup genie_xsec    %s   -q %s" % (args.genie_xsec_version, args.genie_options), file=sh)
        print("setup genie_phyopt %s -q %s" % (args.genie_phyopt_version, args.genie_phyopt_options), file=sh)
    else:
        print("setup dk2nugenie   v01_06_01f -q e17:prof", file=sh)
        print("setup genie_xsec   v2_12_10   -q DefaultPlusValenciaMEC", file=sh)
        print("setup genie_phyopt v2_12_10   -q dkcharmtau", file=sh)
    #print >> sh, "setup geant4 v4_10_3_p03e -q e17:prof"
    print("setup geant4 v4_11_0_p01c -q e20:prof", file=sh)
    print("setup ND_Production v01_05_00 -q e17:prof", file=sh)
    print("setup jobsub_client", file=sh)
    print("setup cigetcert", file=sh)


    # If we are going to do a sam metadata, set it up
    if args.sam_name is not None:
        print("setup sam_web_client v2_2", file=sh)


    # edep-sim needs to know the location of this file, and also needs to have this location in its path
    print("G4_cmake_file=`find ${GEANT4_FQ_DIR}/lib64 -name 'Geant4Config.cmake'`", file=sh)
    print("export Geant4_DIR=`dirname $G4_cmake_file`", file=sh)
    print("export PATH=$PATH:$GEANT4_FQ_DIR/bin", file=sh)
    
    stages = (args.stages).lower()
    
    allfiles_mode = False
    if not any(x in stages for x in ["gen", "genie", "generator"]):
      # This doesn't work because we don't know the exact name bc of timestamps
      #print >> sh, "ifdh cp %s/genie/%s/%02.0fm/${RDIR}/%s.${RUN}.ghep.root input_file.ghep.root" % (args.indir, args.horn, args.oa, mode)
      import glob, os, fnmatch
      #all_files = glob.glob(os.path.join(args.indir, "*.edep.root"))
      allfiles_mode = True
      if args.sam_input != None and args.sam_input != "":
          import subprocess
          
          sam_input = args.sam_input
          bashCommand = "/nashome/a/ahimmel/bin/sam_query_paths %s" % sam_input
          process = subprocess.Popen(bashCommand.split(), stdout=subprocess.PIPE)
          output, error = process.communicate()
          all_files = output.split()
          print("allfiles=(" + " ".join(all_files) + ")", file=sh)
      else:
          all_files=[]
          for root, dirnames, filenames in os.walk(args.indir):
            for filename in fnmatch.filter([x for x in filenames], '*.root'):
              fullfilename = os.path.join(root, filename)
              all_files.append(fullfilename)
          N_TO_SHOW = len(all_files)
          all_files = sorted(all_files)
          print("allfiles=(" + " ".join(all_files) + ")", file=sh)

    # if test mode, run it in a new directory so we don't tarbomb
    # Run number and random seed must be set in the script because the $PROCRESS variable is different for each job
    if not allfiles_mode:
        if args.test:
            print("mkdir test;cd test", file=sh)
            print("RUN=%d" % args.first_run, file=sh)
            print("SEED=%d" % (1E6*args.oa + args.first_run), file=sh)
        else:
            print("RUN=$((${PROCESS}+%d))" % args.first_run, file=sh)
            print("SEED=$((1000000*%d+${RUN}))" % (int(args.oa)), file=sh)
    else:
        if args.test:
            print("PROCESS=0", file=sh) # test with first file
            print("mkdir test;cd test", file=sh)
            print("SEED=%d" % (1E6*args.oa + args.first_run), file=sh)
        print("filename=`basename ${allfiles[${PROCESS}]}`", file=sh)
        print('echo "Found filename=${filename}"', file=sh)
        print('RUN=`echo $filename | grep -Po "(?<=\.)\d+(?=_)"`', file=sh)
        print('echo "Found RUN=${RUN}"', file=sh)

    # Set the run dir in the script, as it can be different for different jobs within one submission if N is large
    print("RDIR=$((${RUN} / 1000))", file=sh)
    print("if [ ${RUN} -lt 10000 ]; then", file=sh)
    print("RDIR=0$((${RUN} / 1000))", file=sh)
    print("fi", file=sh)

    copylines = []

    # put the timestamp for unique file names
    print("TIMESTAMP=`date +%s`", file=sh)
    
    if args.geometry_location != None:
        print(("Copying geometry files from %s" % args.geometry_location))
        print("echo Copying geometry files from %s" % args.geometry_location, file=sh)
        print("ifdh cp %s ." % args.geometry_location, file=sh)

    # Generator/GENIE stage
    if any(x in stages for x in ["gen", "genie", "generator"]):
        run_gen( sh, args )
        copylines.append( "GHEP_FILE=%s.${RUN}_${TIMESTAMP}.ghep.root\n" % mode )
        copylines.append( "mv %s.${RUN}.ghep.root ${GHEP_FILE}\n" % mode )

        if args.sam_name is not None:
            # generate a unique file name with the timestamp
            if args.anti_fiducial:
                copylines.append( "generate_sam_json ${GHEP_FILE} ${RUN} ${NSPILL} \"generated\" %s %1.2f %s %s %1.1f %d %s %s %s %s %s %s %s\n" % (args.sam_name, args.oa, args.topvol, "anti_fiducial_"+args.geometry, hc, fluxid, args.data_stream, args.file_format, args.application_family, args.application_name, args.application_version, args.campaign, args.requestid) )
            else:
                copylines.append( "generate_sam_json ${GHEP_FILE} ${RUN} ${NSPILL} \"generated\" %s %1.2f %s %s %1.1f %d %s %s %s %s %s %s %s\n" % (args.sam_name, args.oa, args.topvol, args.geometry, hc, fluxid, args.data_stream, args.file_format, args.application_family, args.application_name, args.application_version, args.campaign, args.requestid) )
            #copylines.append( "ifdh cp ${GHEP_FILE} %s/${GHEP_FILE}\n" % args.dropbox_dir )
            copylines.append( "ifdh cp ${GHEP_FILE}.json %s/${GHEP_FILE}.json\n" % args.dropbox_dir )
        if args.persist == "all" or any(x in args.persist for x in ["gen", "genie", "generator"]):
            copylines.append( "ifdh_mkdir_p %s/genie/%s/%02.0fm/${RDIR}\n" % (args.outdir, args.horn, args.oa) )
            copylines.append( "ifdh cp ${GHEP_FILE} %s/genie/%s/%02.0fm/${RDIR}/${GHEP_FILE}\n" % (args.outdir, args.horn, args.oa) )

    # G4/edep-sim stage
    if any(x in stages for x in ["g4", "geant4", "edepsim", "edep-sim"]):
        run_g4( sh, args )
        copylines.append( "EDEP_FILE=%s.${RUN}_${TIMESTAMP}.edep.root\n" % mode )
        copylines.append( "mv ${EDEP_OUTPUT_FILE} ${EDEP_FILE}\n" )

        if args.sam_name is not None:
            if args.anti_fiducial:
                copylines.append( "generate_sam_json ${EDEP_FILE} ${RUN} ${NSPILL} \"simulated\" %s %1.2f %s %s %1.1f %d %s %s %s %s %s %s %s\n" % (args.sam_name, args.oa, args.topvol, "anti_fiducial_"+args.geometry, hc, fluxid, args.data_stream, args.file_format, args.application_family, args.application_name, args.application_version, args.campaign, args.requestid) )
            else:
                copylines.append( "generate_sam_json ${EDEP_FILE} ${RUN} ${NSPILL} \"simulated\" %s %1.2f %s %s %1.1f %d %s %s %s %s %s %s %s\n" % (args.sam_name, args.oa, args.topvol, args.geometry, hc, fluxid, args.data_stream, args.file_format, args.application_family, args.application_name, args.application_version, args.campaign, args.requestid) )
            #copylines.append( "ifdh cp ${EDEP_FILE} %s/${EDEP_FILE}\n" % args.dropbox_dir )
            copylines.append( "ifdh cp ${EDEP_FILE}.json %s/${EDEP_FILE}.json\n" % args.dropbox_dir )
        if args.persist == "all" or any(x in args.persist for x in ["g4", "geant4", "edepsim", "edep-sim"]):
            copylines.append( "ifdh_mkdir_p %s/edep/%s/%02.0fm/${RDIR}\n" % (args.outdir, args.horn, args.oa) )
            copylines.append( "ifdh cp ${EDEP_FILE} %s/edep/%s/%02.0fm/${RDIR}/${EDEP_FILE}\n" % (args.outdir, args.horn, args.oa) )
    #else:
    #    copylines.append("EDEP_FILE=${allfiles[${PROCESS}]}\n")

    # LarCV stage
    if any(x in stages for x in ["larcv"]):
        run_larcv( sh, args )
        if args.persist == "all" or any(x in args.persist for x in ["larcv"]):
            copylines.append( "ifdh_mkdir_p %s/larcv/%s/%02.0fm/${RDIR}\n" % (args.outdir, args.horn, args.oa) )
            copylines.append( "ifdh cp larcv.root %s/larcv/%s/%02.0fm/${RDIR}/%s.${RUN}.larcv.root\n" % (args.outdir, args.horn, args.oa, mode) )
            
    if any(x in stages for x in ["tmsreco"]):
        run_tms( sh, args )     
        #copylines.append( "TMS_FILE=%s.${RUN}_${TIMESTAMP}.tmsreco.root\n" % mode )
        # Want to keep the same name relative to the EDEP_FILE
        copylines.append( "TMS_FILE=`basename ${EDEP_FILE/edep.root/tmsreco.root}`\n" )
        copylines.append( "mv ${TMS_OUTPUT_FILE} ${TMS_FILE}\n" ) 
        #copylines.append( "TMS_PDF_FINAL_FILE=%s.${RUN}_${TIMESTAMP}.tmsreco.pdf\n" % mode )
        copylines.append( "TMS_PDF_FINAL_FILE=`basename ${EDEP_FILE/edep.root/tmsreco.pdf}`\n" )
        copylines.append( 'if [ -n "$TMS_PDF_FILE" ]; then\n' )
        copylines.append( "mv ${TMS_PDF_FILE} ${TMS_PDF_FINAL_FILE}\n" ) 
        copylines.append( "fi\n" ) 
            
        
        if args.sam_name is not None:
            copylines.append( "generate_sam_json ${TMS_FILE} ${RUN} ${NSPILL} \"simulated\" %s %1.2f %s %s %1.1f %d %s %s %s %s %s %s %s\n" % (args.sam_name, args.oa, args.geometry, args.topvol, hc, fluxid, args.data_stream, args.file_format, args.application_family, args.application_name, args.application_version, args.campaign, args.requestid) )
            copylines.append( "ifdh cp ${TMS_FILE} %s/${TMS_FILE}\n" % args.dropbox_dir )
            copylines.append( "ifdh cp ${TMS_FILE}.json %s/${TMS_FILE}.json\n" % args.dropbox_dir )
             
        if args.persist == "all" or any(x in args.persist for x in ["tmsreco"]):
            copylines.append( "ifdh_mkdir_p %s/tmsreco/%s/%02.0fm/${RDIR}\n" % (args.outdir, args.horn, args.oa) )
            copylines.append( "ifdh cp ${TMS_FILE} %s/tmsreco/%s/%02.0fm/${RDIR}/${TMS_FILE}\n" % (args.outdir, args.horn, args.oa) )
            copylines.append( "ifdh cp ${TMS_READOUT_FILE} %s/tmsreadout/%s/%02.0fm/${RDIR}/${TMS_READOUT_FILE}\n"  % (args.outdir, args.horn, args.oa) )
            copylines.append( 'if test -f "$TMS_PDF_FINAL_FILE"; then ifdh cp ${TMS_PDF_FINAL_FILE} %s/tmsreco/%s/%02.0fm/${RDIR}/${TMS_PDF_FINAL_FILE}; fi\n' % (args.outdir, args.horn, args.oa) )
            
            
    print("\n\necho Done running stages.", file=sh)
    print("end_process_nd_run_time=`date +%s`", file=sh)
    print("runtime=$((end_process_nd_run_time-start_process_nd_run_time))", file=sh)
    print('echo "Runtime (s): "${runtime}', file=sh)
    print("echo Local files right now:\nls -alh", file=sh)
    


    sh.writelines(copylines)

    if not args.test:
        if "tmsreco" in args.stages or "all" in args.stages:
            TMS_TAR_FILE = args.tms_reco_tar
            print("Script processnd.sh created. Submit example:\n")
            print("jobsub_submit --group dune --role=Analysis -N %s --OS=SL7 --expected-lifetime=24h --memory=4000MB --use-cvmfs-dropbox --tar_file_name=dropbox://%s file://processnd.sh" % (N_TO_SHOW, TMS_TAR_FILE))
        else:
            print("Script processnd.sh created. Submit example:\n")
            print("jobsub_submit --group dune --role=Analysis -N %s --OS=SL7 --expected-lifetime=24h --memory=4000MB file://processnd.sh" % N_TO_SHOW)

