#!/usr/bin/env python3
#
# based on https://github.com/DUNE/ND_Production/blob/main/run-validation/edepsim_validation.py
# usage eg: python  edepsim_g4proc_validation.py -f MicroProdN4p1_NDComplex_FHC.convert2h5.full.0002500.EDEPSIM.hdf5
# input h5 file from 
# /pnfs/dune/persistent/physicsgroups/dunendsim/abooth/nd-production/MicroProdN4p1/run-convert2h5/

import matplotlib
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages

import h5py
import argparse
import numpy as np

import seaborn as sns
import pandas as pd

# uncomment if running on gpvm
#from validation_utils import rasterize_plots
#rasterize_plots()

# sample only 100 events for plot if TEST=True
TEST    = False
# print everything
VERBOSE = True

from edepsim_g4proc_helpers import *

def main(sim_file, input_type, det_complex):

    sim_h5 = h5py.File(sim_file,'r')
    print('\n----------------- File content -----------------')
    print('File:',sim_file)
    print('Keys in file:',list(sim_h5.keys()))
    for key in sim_h5.keys():
        print('* Number of',key,'entries in file:', len(sim_h5[key]))
    print('------------------------------------------------\n')

    output_pdf_name = sim_file.split('.hdf5')[0]+'_g4proc.pdf'

    output_pdf_name = output_pdf_name.split('/')[-1] # !!

    dataset = sim_h5['trajectories']

    print("\n... converting h5 DS to pandas DF")
    df = h5_Dataset_to_pandas_DataFrame( dataset )
    #summarise_df(df, "raw data")

    print("\n... selecting primaries")
    df = select_primary_processes(df)
    #summarise_df(df, f"primary process selection")

    # add a series to the DataFrame with the evtgen particle names
    print("\n... adding evt_gen particle names")
    df, particle_list = add_particle_names(df)
    print(particle_list)
    

    # add a series to the DataFrame with the G4Process names
    print("\n... adding start_process names")
    df, process_list = add_process_names(df, "start")
    print(process_list)

    print("\n... adding end_process names")
    df, end_process_list = add_process_names(df, "end")
    print(end_process_list)

    # add a series to the DataFrame with the G4SubProcess names
    print("\n... adding start_subprocess names")
    df, subprocess_list = add_subprocess_names(df, "start")
    print(subprocess_list)

    print("\n... adding end_subprocess names")
    df, end_subprocess_list = add_subprocess_names(df, "end")
    print(end_subprocess_list)

    # try to gain insight into the weird process numbers
    print("\n... printing weird processes")
    print_spurious_processes(df)

    with PdfPages(output_pdf_name) as output:

        ncats    = 10 # number of particles to include, ordered by how prolificly they occur
        mincount = 1  # minimum occurrences of a process to include it

        dfplot = df.copy(deep=False)

        cat1 = "ParticleType"
        cat2 = "G4ProcessType_start"
        cat3 = "G4SubProcessType_start"

        # reduce the phase space for plotting purposes
        print("\n... reducing category space for plots, ncats = {}, mincount = {}".format(ncats, mincount))
        dfplot = reduce_category_space(dfplot, cat1, cat2, cat3, ncats, mincount)
        #summarise_df(dfplot, "reduced category space")

        if(TEST):
            print("\n...Plotting 100 entries as TEST is selected")
            dfplot=dfplot.sample(n=100)

        # LINEAR SCALE PLOT  
        print("\n... making linear count process plots")             
        g=make_sn_displot(dfplot, cat1, cat2, cat3, sim_file, ncats, mincount,False) 
        output.savefig()
        plt.close()

        # LOG X SCALE PLOT 
        print("\n... making log count process plots") 
        g=make_sn_displot(dfplot, cat1, cat2, cat3, sim_file, ncats, mincount, True)
        output.savefig()
        plt.close()

        # All plots saved to big pdf      
        print('\nPlots saved to {}'.format(output_pdf_name))
        

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-f', '--sim_file', default=None, required=True, type=str, help='''string corresponding to the path of the edep-sim output simulation file to be considered''')
    parser.add_argument('-t', '--input_type', default='edep', choices=['edep', 'larnd'], type=str, help='''string corresponding to the output file type: edep or larnd''')
    parser.add_argument('-d', '--det_complex', default='2x2', choices=['2x2', 'full'], type=str, help='''string describing the detector complex''')
    args = parser.parse_args()
    main(**vars(args))      



