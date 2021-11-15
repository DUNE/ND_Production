# create a script to run a customized ND production on the grid
from optparse import OptionParser
import os
import sys

def run_gen( sh, args ):

    mode = "neutrino" if args.horn == "FHC" else "antineutrino"
    fluxopt = ""
    maxmb = 100
    if args.use_dk2nu:
        fluxopt = "--dk2nu"
        maxmb = 300
    print >> sh, "${ND_PRODUCTION_DIR}/bin/copy_dune_flux --top %s --flavor %s --maxmb=100 %s" % (args.fluxdir, mode, fluxopt)

    # Modify GNuMIFlux.xml to the specified off-axis position
    print >> sh, "sed \"s/<beampos> ( 0.0, 0.05387, 6.66 )/<beampos> ( %1.2f, 0.05387, 6.66 )/g\" ${ND_PRODUCTION_CONFIG}/GNuMIFlux.xml > GNuMIFlux.xml" % args.oa
  
    print >> sh, "export GXMLPATH=${PWD}:${GXMLPATH}"
    print >> sh, "export GNUMIXML=\"GNuMIFlux.xml\""
  
    # Run GENIE
    flux = "dk2nu" if args.use_dk2nu else "gsimple"
    print >> sh, "gevgen_fnal \\"
    print >> sh, "    -f flux_files/%s*,DUNEND \\" % flux
    if args.anti_fiducial:
        print "USING ANTI FIDUCIAL:anti_fiducial_%s.gdml" % args.geometry
        print >> sh, "    -g ${ND_PRODUCTION_GDML}/anti_fiducial_%s.gdml \\" % args.geometry
    else:
        print >> sh, "    -g ${ND_PRODUCTION_GDML}/%s.gdml \\" % args.geometry
    print >> sh, "    -t %s \\" % args.topvol
    print >> sh, "    -L cm -D g_cm3 \\"
    print >> sh, "    -e %g \\" % args.pot
    print >> sh, "    --seed ${SEED} \\"
    print >> sh, "    -r ${RUN} \\"
    print >> sh, "    -o %s \\" % mode
    print >> sh, "    --message-thresholds ${ND_PRODUCTION_CONFIG}/Messenger_production.xml \\"
    print >> sh, "    --cross-sections ${GENIEXSECPATH}/gxspl-FNALsmall.xml \\"
    print >> sh, "    --event-record-print-level 0 \\"
    print >> sh, "    --event-generator-list Default+CCMEC"

    # Copy the output

def run_g4( sh, args ):
    mode = "neutrino" if args.horn == "FHC" else "antineutrino"

    # Get the input file
    if any(x in stages for x in ["gen", "genie", "generator"]):
        # Then we just made the GENIE file, and it's sitting in the working directory
        print >> sh, "cp %s.${RUN}.ghep.root input_file.ghep.root" % mode
    else:
        # We need to get the input file
        print >> sh, "ifdh cp %s/genie/%s/%02.0fm/${RDIR}/%s.${RUN}.ghep.root input_file.ghep.root" % (args.indir, args.horn, args.oa, mode)

    # convert to rootracker to run edep-sim
    print >> sh, "gntpc -i input_file.ghep.root -f rootracker --event-record-print-level 0 --message-thresholds ${ND_PRODUCTION_CONFIG}/Messenger_production.xml"

    # Get edep-sim
    print >> sh, "setup edepsim v3_0_1b -q e17:prof"

    # Get the number of events in the genie file
    # if we're doing overlay, then we want to get the poisson mean and then the number of spills, and be careful not to overshoot
    if args.overlay:
        print >> sh, "MEAN=$(echo \"std::cout << gtree->GetEntries()*(%3.3g/%3.3g) << std::endl;\" | genie -l -b input_file.ghep.root 2>/dev/null  | tail -1)" % (args.spill_pot, args.pot)
        print >> sh, "NSPILL=$(echo \"std::cout << (int)floor(0.9*gtree->GetEntries()/${MEAN}) << std::endl;\" | genie -l -b input_file.ghep.root 2>/dev/null  | tail -1)"

        # change the macro to use mean
        print >> sh, "sed \"s/count\/set fixed/cout\/set mean/g\" ${ND_PRODUCTION_CONFIG}/dune-nd.mac > dune-nd.mac" % mac
        print >> sh, "sed -i \"s/count\/fixed\/number 1/count\/mean\/number ${MEAN}/g\" dune-nd.mac"
    else:
        print >> sh, "NSPILL=$(echo \"std::cout << gtree->GetEntries() << std::endl;\" | genie -l -b input_file.ghep.root 2>/dev/null  | tail -1)"
        print >> sh, "cat ${ND_PRODUCTION_CONFIG}/dune-nd.mac > dune-nd.mac"

    #Run it
    print >> sh, "edep-sim -C \\"
    print >> sh, "  -g ${ND_PRODUCTION_GDML}/%s.gdml \\" % args.geometry
    print >> sh, "  -o %s.${RUN}.edep.root \\" % mode
    print >> sh, "  -e ${NSPILL} \\"
    print >> sh, "  dune-nd.mac"

def run_larcv( sh, args ):

    print "LArCV stage is not currently supported.  Sorry"
    return

    mode = "neutrino" if args.horn == "FHC" else "antineutrino"

    # Get the input file, unless we just ran edep-sim and it's sitting in the working directory
    if not any(x in stages for x in ["g4", "geant4", "edepsim", "edep-sim"]):
        print >> sh, "setup edepsim v2_0_1 -q e17:prof"
        print >> sh, "ifdh cp %s/edep/%s/%02.0fm/${RDIR}/%s.${RUN}.edep.root %s.${RUN}.edep.root" % (args.indir, args.horn, args.oa, mode, mode)

    # Get larcv stuff
    #print >> sh, "ifdh cp %s/larcv2.tar.bz2 larcv2.tar.bz2" % args.tardir
    #print >> sh, "bzip2 -d larcv2.tar.bz2"
    #print >> sh, "tar -xf larcv2.tar"

    # additional python setup needed
    print >> sh, "setup python_future_six_request  v1_3 -q python2.7-ucs2"

    # run LArCV2
    print >> sh, ". larcv2/configure.sh"
    print >> sh, "supera_dir=${LARCV_BASEDIR}/larcv/app/Supera"
    print >> sh, "python ${supera_dir}/run_supera.py reco/larcv.cfg %s.${RUN}.edep.root" % mode


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
    parser.add_option('--test', help='Use test mode (interactive job)', default=False, action="store_true")
    parser.add_option('--overlay', help='Simulate full spills (default is single events)', default=False, action="store_true")
    parser.add_option('--stages', help='Production stages (gen+g4+larcv+ana)', default="gen+g4+larcv+ana")
    parser.add_option('--persist', help='Production stages to save to disk(gen+g4+larcv+ana)', default="all")
    parser.add_option('--indir', help='Input file top-directory (if not running gen)', default="/pnfs/dune/persistent/users/%s/nd_production"%user)
    parser.add_option('--fluxdir', help='Specify the top-level flux file directory', default="/cvmfs/dune.osgstorage.org/pnfs/fnal.gov/usr/dune/persistent/stash/Flux/g4lbne/v3r5p4/QGSP_BERT/OptimizedEngineeredNov2017")
    parser.add_option('--outdir', help='Top-level output directory', default="/pnfs/dune/persistent/users/%s/nd_production"%user)
    parser.add_option('--use_dk2nu', help='Use full dk2nu flux input (default is gsimple)', action="store_true", default=False)
    parser.add_option('--sam_name', help='Make a sam dataset with this name', default=None)
    parser.add_option('--dropbox_dir', help='dropbox directory', default="/pnfs/dune/scratch/dunepro/dropbox/neardet")
    parser.add_option('--data_stream', help='data_stream', default=None)
    parser.add_option('--file_format', help='file format', default="root")
    parser.add_option('--application_family', help='application family', default=None)
    parser.add_option('--application_name', help='application name', default=None)
    parser.add_option('--application_version', help='application version', default=None)
    parser.add_option('--campaign', help='DUNE.campaign', default=None)
    parser.add_option('--requestid', help='DUNE.requestid', default=None)

    parser.add_option('--anti_fiducial', help='anti fiducial using : anti_fiducial_geometry.gdml', default=False, action="store_true")

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
        print "WARNING: specified flux file directory:"
        print args.fluxdir
        print "is not in cvmfs. The flux setup probably will not work unless you really know what you are doing"

    # Software setup -- eventually we may want options for this
    print >> sh, "source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh"
    print >> sh, "setup ifdhc"
    print >> sh, "setup dk2nugenie   v01_06_01f -q e17:prof"
    print >> sh, "setup genie_xsec   v2_12_10   -q DefaultPlusValenciaMEC"
    print >> sh, "setup genie_phyopt v2_12_10   -q dkcharmtau"
    print >> sh, "setup geant4 v4_10_3_p03e -q e17:prof"
    print >> sh, "setup ND_Production v01_05_00 -q e17:prof"
    print >> sh, "setup jobsub_client"
    print >> sh, "setup cigetcert"


    # If we are going to do a sam metadata, set it up
    if args.sam_name is not None:
        print >> sh, "setup sam_web_client v2_2"


    # edep-sim needs to know the location of this file, and also needs to have this location in its path
    print >> sh, "G4_cmake_file=`find ${GEANT4_FQ_DIR}/lib64 -name 'Geant4Config.cmake'`"
    print >> sh, "export Geant4_DIR=`dirname $G4_cmake_file`"
    print >> sh, "export PATH=$PATH:$GEANT4_FQ_DIR/bin"

    # if test mode, run it in a new directory so we don't tarbomb
    # Run number and random seed must be set in the script because the $PROCRESS variable is different for each job
    if args.test:
        print >> sh, "mkdir test;cd test"
        print >> sh, "RUN=%d" % args.first_run
        print >> sh, "SEED=%d" % (1E6*args.oa + args.first_run)
    else:
        print >> sh, "RUN=$((${PROCESS}+%d))" % args.first_run
        print >> sh, "SEED=$((1000000*%d+${RUN}))" % (int(args.oa))

    # Set the run dir in the script, as it can be different for different jobs within one submission if N is large
    print >> sh, "RDIR=$((${RUN} / 1000))"
    print >> sh, "if [ ${RUN} -lt 10000 ]; then"
    print >> sh, "RDIR=0$((${RUN} / 1000))"
    print >> sh, "fi"

    stages = (args.stages).lower()
    copylines = []

    # put the timestamp for unique file names
    print >> sh, "TIMESTAMP=`date +%s`"

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
            copylines.append( "ifdh cp ${GHEP_FILE} %s/${GHEP_FILE}\n" % args.dropbox_dir )
            copylines.append( "ifdh cp ${GHEP_FILE}.json %s/${GHEP_FILE}.json\n" % args.dropbox_dir )
        if args.persist == "all" or any(x in args.persist for x in ["gen", "genie", "generator"]):
            copylines.append( "ifdh_mkdir_p %s/genie/%s/%02.0fm/${RDIR}\n" % (args.outdir, args.horn, args.oa) )
            copylines.append( "ifdh cp ${GHEP_FILE} %s/genie/%s/%02.0fm/${RDIR}/${GHEP_FILE}\n" % (args.outdir, args.horn, args.oa) )

    # G4/edep-sim stage
    if any(x in stages for x in ["g4", "geant4", "edepsim", "edep-sim"]):
        run_g4( sh, args )
        copylines.append( "EDEP_FILE=%s.${RUN}_${TIMESTAMP}.edep.root\n" % mode )
        copylines.append( "mv %s.${RUN}.edep.root ${EDEP_FILE}\n" % mode )

        if args.sam_name is not None:
            copylines.append( "generate_sam_json ${EDEP_FILE} ${RUN} ${NSPILL} \"simulated\" %s %1.2f %s %s %1.1f %d %s %s %s %s %s %s %s\n" % (args.sam_name, args.oa, args.topvol, args.geometry, hc, fluxid, args.data_stream, args.file_format, args.application_family, args.application_name, args.application_version, args.campaign, args.requestid) )
            copylines.append( "ifdh cp ${EDEP_FILE} %s/${EDEP_FILE}\n" % args.dropbox_dir )
            copylines.append( "ifdh cp ${EDEP_FILE}.json %s/${EDEP_FILE}.json\n" % args.dropbox_dir )
        if args.persist == "all" or any(x in args.persist for x in ["g4", "geant4", "edepsim", "edep-sim"]):
            copylines.append( "ifdh_mkdir_p %s/edep/%s/%02.0fm/${RDIR}\n" % (args.outdir, args.horn, args.oa) )
            copylines.append( "ifdh cp ${EDEP_FILE} %s/edep/%s/%02.0fm/${RDIR}/${EDEP_FILE}\n" % (args.outdir, args.horn, args.oa) )

    # LarCV stage
    if any(x in stages for x in ["larcv"]):
        run_larcv( sh, args )
        if args.persist == "all" or any(x in args.persist for x in ["larcv"]):
            copylines.append( "ifdh_mkdir_p %s/larcv/%s/%02.0fm/${RDIR}\n" % (args.outdir, args.horn, args.oa) )
            copylines.append( "ifdh cp larcv.root %s/larcv/%s/%02.0fm/${RDIR}/%s.${RUN}.larcv.root\n" % (args.outdir, args.horn, args.oa, mode) )

    sh.writelines(copylines)

    if not args.test:
        print "Script processnd.sh created. Submit example:\n"
        print "jobsub_submit --group dune --role=Analysis -N 1000 --OS=SL7 --expected-lifetime=24h --memory=2000MB file://processnd.sh"

