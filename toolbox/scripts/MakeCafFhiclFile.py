#!/bin/env python3

import os, sys, string, re, shutil, math, time, subprocess, json
import datetime as dt

from argparse import ArgumentParser as ap


#++++++++++++++++++++++++++++
# environment variables
#++++++++++++++++++++++++++++
DETECTOR_CONFIG = str(os.environ.get('DETECTOR_CONFIG'))
DATA_TYPE       = str(os.environ.get('DATA_TYPE'))



#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# create the caf maker fhicl file
# Based on the script :
# https://github.com/DUNE/2x2_sim/blob/feature_spine_on_data/run-cafmaker/gen_cafmaker_cfg.data.py
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
if __name__ == '__main__' :

   print( "Enter make the fhicl file for the caf maker production jobs\n")

   # input arguments
   parser = ap()
   parser.add_argument('--infiles', nargs='?', type=str, required=True, help="The input files to process via the cafmaker maker")
   parser.add_argument('--outfile', type=str, required=True, help="The output file name" )
   parser.add_argument('--disable-ifbeam', action='store_true')

   args = parser.parse_args()

   # get the input files
   infiles = args.infiles.split(",")

   # create a fhicl file
   fclname = "nd_cafmaker_%s_%s.fcl" % (DETECTOR_CONFIG,DATA_TYPE)

   with open(fclname,'w') as fcl :
        fcl.write( "\n#include \"NDCAFMaker.fcl\"\n\nnd_cafmaker: @local::standard_nd_cafmaker\n\n" )

        for infile in infiles :
            if infile.find('dst') != -1 :
               fcl.write( "nd_cafmaker.CAFMakerSettings.MINERVARecoFile: \"%s\"\n" % infile )
            elif infile.find('SPINE') != -1 : 
               fcl.write( "nd_cafmaker..NDLArRecoFile: \"%s\"\n" % infile )
            elif infile.find('LAR_RECO') != -1 :
               fcl.write( "nd_cafmaker.CAFMakerSettings.PandoraLArRecoNDFile: \"%s\"\n" % infile )
           
        if args.disable_ifbeam :
           fcl.write( "nd_cafmaker.CAFMakerSettings.ForceDisableIFBeam: true\n" )

        if DATA_TYPE == "data" :
           fcl.write( "nd_cafmaker.CAFMakerSettings.TriggerMatchDeltaT: 5000000\n" )
      
        fcl.write( "nd_cafmaker.CAFMakerSettings.OutputFile: \"%s\"\n" % args.outfile )

   print( "Exit make the fhicl file for the caf maker production jobs\n")

