import h5py
import numpy as np
import seaborn as sns
import pandas as pd
import matplotlib
import matplotlib.pyplot as plt
#-----------------------------------------------#
# HELPER FUNCTIONS
#-----------------------------------------------#

# h5 to pandas depends on file structure, so here is bespoke conversion
# input is a h5 Dataset eg hfile['trajectories']
# returns a pandas DataFrame
def h5_Dataset_to_pandas_DataFrame( h5Dataset ):
    #print('\n---- h5_Dataset_to_pandas_DataFrame ----\n')
    df = pd.DataFrame(h5Dataset) # this guy has issues

    prop_names = np.dtype(h5Dataset).names # tuple
    # eg prop_names : ('event_id', 'vertex_id', 'traj_id', 'file_traj_id', 'parent_id', 'primary', 'E_start', 'pxyz_start', 'xyz_start', 't_start', 'E_end', 'pxyz_end', 'xyz_end', 't_end', 'pdg_id', 'start_process', 'start_subprocess', 'end_process', 'end_subprocess', 'dist_travel')

    df_names = pd.DataFrame(prop_names)
    df_names.columns=['property_name']

    property_dfs=[]

    for index, row in df_names.iterrows():
        pname = row['property_name'] 

        data = h5Dataset[pname]

        dfi = pd.DataFrame( data )
  
        # lazy, dodgy, effective for this file format
        if(dfi.columns.size ==3):
            #print(f'...splitting data for {pname} into {pname}.x,y,z')
            dfi.columns=[str(pname)+'.x', str(pname)+'.y', str(pname)+'.z']
        elif(dfi.columns.size ==1):
            dfi.columns=[str(pname)]
        else:
            print('UH OH. This script only handles single values and 3-vectors. It will now bork.')

        property_dfs.append(dfi)

    df_fixed = pd.concat(property_dfs, axis=1)

    return df_fixed


# Prints summary statistics for every column in the DataFrame
# useful for eyeballing ranges and unique occurences
def summarise_df(df, message=""):
    print('Summary of DataFrame ',message)
    # calculate the sumamry stats for each property of the parent df
    # row=property, columns=summary stats.
    print('df shape', df.shape)
        
    o_median = pd.DataFrame( data = df.median(numeric_only=True)  )
    o_std    = pd.DataFrame( data = df.std(numeric_only=True)     )
    o_min    = pd.DataFrame( data = df.min(numeric_only=True)     )
    o_max    = pd.DataFrame( data = df.max(numeric_only=True)     )
    o_n      = pd.DataFrame( data = df.count()   )
    o_nu     = pd.DataFrame( data = df.nunique() )
    
    o_min.columns    = ["min"]
    o_max.columns    = ["max"]
    o_median.columns = ["median"]
    o_std.columns    = ["std"]
    o_n.columns      = ["n"]
    o_nu.columns     = ["nunique"]

    oframes = [  o_median, o_std, o_min, o_max, o_n, o_nu ]
    o_summary = pd.concat( oframes, axis=1 )
   
    pd.set_option('display.float_format', '{:.0f}'.format)
    print( o_summary )

    return

# --------------------
# This function augments the passed DataFrame
# input is a pandas DataFrame
# output is same pandas DataFrame with a new column for ParticleType
# Naming is a la evtgen
def add_particle_names(dfo, prinfo=False):

    #print('\n-------- add_particle_names ----------\n')

    pd.options.mode.chained_assignment = None  # default='warn'
    
    series_pdg_id = dfo["pdg_id"]
    uids = np.unique( series_pdg_id )
    series_particle = series_pdg_id.copy(deep=False)

    from particle import Particle
    
    evtgen_particle_names=[]
    
    for uid in uids:

        p = Particle.from_pdgid(uid).name        
        series_particle.replace( uid, p , inplace=True )        
        evtgen_particle_names.append( p )
    
    if(prinfo):
        print("Primary particle types present in this file:{}\n".format(evtgen_particle_names) )
    
    dfo['ParticleType'] = series_particle 

    pd.options.mode.chained_assignment = 'warn' 

    return dfo 


# --------------------
# This function augments the passed DataFrame
# input is a pandas DataFrame
# output is same pandas DataFrame with a new column for G4ProcessType

def add_process_names(dfo, which_end='start',prinfo=False):

    #print(f"...Adding G4ProcessTypes ({which_end}_process)\n")

    pd.options.mode.chained_assignment = None  # default='warn'

    # Copy the [start,end]_process Series from the original DataFrame dfo
    df = dfo[f"{which_end}_process"].copy(deep=False)
    
    sp_unique_values = df.unique()
    spurious_processes = []
    for sp in sp_unique_values:
        if (sp not in range(1,8)):
            spurious_processes.append(sp)
    
    if(prinfo):
        print('Unrecognised {}_process numbers ({}):{}\n'.format(which_end,len(spurious_processes),spurious_processes))
    #print('Plots saved to {}'.format(output_pdf_name))

    strange_ones = dfo[ dfo[f"{which_end}_process"]>7 ]
    #print(f"df for these: {strange_ones}")
    # Add G4 names for each of the process types
    # https://apc.u-paris.fr/~franco/g4doxy/html/G4ProcessType_8hh.html
    df.replace(1, "fTransportation", inplace=True)
    df.replace(2, "fElectromagnetic", inplace=True)
    df.replace(3, "fOptical", inplace=True)
    df.replace(4, "fHadronic", inplace=True)
    df.replace(5, "fPhotolepton_hadron", inplace=True)
    df.replace(6, "fDecay", inplace=True)
    df.replace(7, "fGeneral", inplace=True)
    for i in spurious_processes:
        df.replace(i, "SpuriousProcess", inplace=True)
    # add the Series as a new column in the original DataFrame
    if(prinfo):
        print("Named G4Process types present in this file:{}\n".format( df.unique() ) )

    dfo[f"G4ProcessType_{which_end}"] = df  

    #print(f"Added G4ProcessType_{which_end} column to dataframe with process names:")

    pd.options.mode.chained_assignment = 'warn' 

    return dfo

# --------------------
# This function augments the passed DataFrame
# input is a pandas DataFrame
# output is same pandas DataFrame with a new column for G4SubProcessType

def add_subprocess_names(dfo, which_end='start', prinfo=False):       

    #print(f"...Adding G4SubProcessTypes ({which_end}_process)\n")
    pd.options.mode.chained_assignment = None
    # Copy the start_subprocess Series from the original DataFrame dfo
    spname = which_end+"_subprocess"
    df = dfo[spname].copy(deep=False)
    sp_unique_values = df.unique()
    if(prinfo):
        print("{} unique_values: {}".format(spname,sp_unique_values) )

    named_sp_enums=[]
    # Add G4 names for each of the subprocess types
    # This is the complete set as of April 2026.I have used identical naming and capitalising to the G4 code.
    # https://apc.u-paris.fr/~franco/g4doxy/html/G4EmProcessSubType_8hh.html
    df.replace(1,  "fCoulombScattering",     inplace=True)
    df.replace(2,  "fIonisation",            inplace=True)
    df.replace(3,  "fBremsstrahlung",        inplace=True)
    df.replace(4,  "fPairProdByCharged",     inplace=True)
    df.replace(5,  "fAnnihilation",          inplace=True)
    df.replace(6,  "fAnnihilationToMuMu",    inplace=True)
    df.replace(7,  "fAnnihilationToHadrons", inplace=True)
    df.replace(8,  "fNuclearStopping",       inplace=True)
    df.replace(10, "fMultipleScattering",    inplace=True)
    df.replace(11, "fRayleigh",              inplace=True)
    df.replace(12, "fPhotoElectricEffect",   inplace=True)
    df.replace(13, "fComptonScattering",     inplace=True)
    df.replace(14, "fGammaConversion",       inplace=True)
    df.replace(15, "fGammaConversionToMuMu", inplace=True)
    df.replace(21, "fCerenkov",              inplace=True)
    df.replace(22, "fScintillation",         inplace=True)
    df.replace(23, "fSynchrotronRadiation",  inplace=True)
    df.replace(24, "fTransitionRadiation",   inplace=True)  
    named_sp_enums.extend( list(range(1,24) ) )

    # https://apc.u-paris.fr/~franco/g4doxy/html/G4TransportationProcessType_8hh.html      
    df.replace(91,  "TRANSPORTATION",         inplace=True)
    df.replace(92,  "COUPLED_TRANSPORTATION", inplace=True)
    df.replace(401, "STEP_LIMITER",           inplace=True)
    df.replace(402, "USER_SPECIAL_CUTS",      inplace=True)
    df.replace(403, "NEUTRON_KILLER",         inplace=True)
    named_sp_enums.extend( [91,92,401,402,403] )

    # https://apc.u-paris.fr/~franco/g4doxy/html/G4HadronicProcessType_8hh.html
    df.replace(111, "fHadronElastic",    inplace=True)
    df.replace(121, "fHadronInelastic",  inplace=True)
    df.replace(131, "fCapture",          inplace=True)
    df.replace(141, "fFission",          inplace=True)
    df.replace(151, "fHadronAtRest",     inplace=True)
    df.replace(152, "fLeptonAtRest",     inplace=True)
    df.replace(161, "fChargeExchange",   inplace=True) 
    df.replace(210, "fRadioactiveDecay", inplace=True)
    named_sp_enums.extend( [111,121,131,141,151,152,161,210] )
    # https://apc.u-paris.fr/~franco/g4doxy/html/G4DecayProcessType_8hh.html
    df.replace(201, "DECAY",             inplace=True)
    df.replace(210, "DECAY_Radioactive", inplace=True)
    df.replace(211, "DECAY_Unknown",     inplace=True)
    df.replace(231, "DECAY_External",    inplace=True)
    named_sp_enums.extend( [201,210,211,231] )

    spurious_processes = []
    for sp in sp_unique_values:
        if ( abs(sp) not in named_sp_enums):
            spurious_processes.append(sp)
        if ( sp==0 ):
            spurious_processes.append(sp)
    if(prinfo):
        print('Unrecognised {}_subprocess numbers ({}):{}\n'.format(which_end,len(spurious_processes),spurious_processes))

    for i in spurious_processes:
        df.replace(i, "SpuriousSubProcess", inplace=True)
    # add the Series as a new column in the original DataFrame
    dfo[f"G4SubProcessType_{which_end}"] = df

    if(prinfo):
        print("Named G4SubProcess types present in this file:{}\n".format( df.unique() ) )

    #print(df.unique())

    pd.options.mode.chained_assignment = 'warn' 

    return dfo

# --------------------
# This function skims the passed DataFrame
# input is a pandas DataFrame
# output is skim of frame with no undefined G4 processes

def remove_spurious_processes(dfo, which_end="start"):
    #print(f"\n-------- remove_spurious_processes ({which_end})-----------\n")
    # some odd process numbers. For now, just remove them
    sel1 = ( abs( dfo[f"{which_end}_process"] ) <13 )
    sel2 = ( abs( dfo[f"{which_end}_process"] ) >0 )

    df_clean = dfo[ sel1 & sel2 ]
    return df_clean


# --------------------
# This function skims the passed DataFrame
# input is a pandas DataFrame
# output is skim of frame with only primary particles

def select_primary_processes(dfo):
    #print('\n-------- select_primary_processes -----------\n')
    # only want particles from the primary interaction
    sel = ( dfo["parent_id"] == -1 )
    df_primary = dfo[ sel ]
    return df_primary

# --------------------
# This function skims the passed DataFrame
# input is a pandas DataFrame
# output is skim of frame with "rare" particles and processes removed
# for example if K+ is the 6th most prolific particle and we have ncats=5, K+ are removed
# for example if fHadronic only appears 1 time and we have mincount=0, fHadronic are removed
def reduce_category_space(dfo, catname1, catname2, catname3, ncats, mincount):

    nparticletypes = dfo[catname1].nunique()

    #print(f"\nReducing category space. Selecting top {ncats} of {nparticletypes} particles and processes, subproccesses with a minimum of {mincount} occurrences.\n")
    
    if(ncats>nparticletypes):
        ncats=nparticletypes

    highest_process_count = dfo[catname2].value_counts().max()
    #print(f"highest_process_count: {highest_process_count }")
    highest_subprocess_count = dfo[catname3].value_counts().max()
    #second_highest_process_count = dfo[catname2].value_counts().nlargest(2).iloc[-1]
    #print(f"second_highest_process_count: {second_highest_process_count }")

    hmax = min(highest_process_count , highest_subprocess_count )

    if(mincount > hmax):
        #print(f"you have selected mincount={mincount} which excludes all processes. Resetting to mincount={hmax-1}")
        mincount = hmax-1

    dfr = dfo.copy(deep=False)

    if(ncats==0 and mincount==0):
        #print(f'Need to specify either ncats>0 or mincount>0 (or both). Returning original df')
        return dfr

    # count the occurrences of each particle type   
    cat1_counts = dfr[catname1].value_counts()
    # list particles with more than ncats occurrences
    red_cats = list( cat1_counts[ : ncats ].keys() )
    # select only these particles
    sel1 = ( dfr[catname1].isin( red_cats ) )

    # count the occurrences of each G4Process
    cat2_counts = dfr[catname2].value_counts()
    # select only processes with more than mincount occurrences
    sel2 = ( dfr[catname2].map( cat2_counts ) >= mincount )
    
    # want at least one of a given subprocess
    cat3_counts = dfr[catname3].value_counts()
    sel3 = ( dfr[catname3].map( cat3_counts ) >= mincount )   

    df_reduced  = dfr[ sel1 & sel2 & sel3 ]       
    
    return df_reduced

# --------------------
# Make a plot
# --------------------
def make_sn_displot(dfo, cat1, cat2, cat3, filename, ncats, mincount, sn_log=False):

    fig, ax = plt.subplots()

    # seaborn style
    sn_palette  = "Spectral"
    sn_multiple = "stack"
    sn_alpha    = 0.75
    sn_aspect   = 0.5
    sn_fontsize = 12 
    sn_title_fontsize = 14 

    # particle type by count for hue order
    pt_by_count = list( dfo[cat1].value_counts().keys() )

    #print(f"pt_by_count: {pt_by_count}")
    
    # splitting into columns according to G4Process
    colnames = dfo[cat2].unique()

    #print(f"colnames: {colnames}")

    # legend
    snl_frameon  = True   

    # grid     
    sng = True
    sng_minor_alpha = 0.2
    sng_major_alpha = 0.6    


    # make the plots
    g = sns.displot(
            data=dfo, 
            hue=cat1, col=cat2, y=cat3, 
            #palette=sn_palette, multiple=sn_multiple, alpha=sn_alpha, aspect=sn_aspect, hue_order = pt_by_count,
            palette=sn_palette, multiple=sn_multiple, alpha=sn_alpha,  hue_order = pt_by_count,
        )

    # adjustments so legend can go outside figure
    # ncols plus space for ylabels on left and legend on right
    # if ncats>climit we split legend into columns and need more space
    climit=15
    nparticletypes = dfo[cat1].nunique()
    # if we asked for more particles types than there are, fix that.
    ncatsrequested=ncats
    if( ncats > nparticletypes ):
        ncats = nparticletypes

    snl_ncol = 1
    if(ncats>climit): 
        # eg if ncats=20, snl_col=20/15 = 2
        snl_ncol = np.ceil( 1*(ncats/climit) )

    tot_ncols = len(colnames) + 1 + snl_ncol 
    colwidth  = 1 / tot_ncols
    snl_r     = 1 - snl_ncol * colwidth
    #print(f"Legend ncols: {snl_ncol}, colwidth:{colwidth}, snl_r:{snl_r}")
    snl_rc    = 1 - 0.5* snl_ncol  * colwidth
    
    g.figure.subplots_adjust(right=snl_r)

    snl_title   = "Primaries"
    snl_loc     = "upper center"
    
    snl_pos     = (snl_rc, .95)

    sns.move_legend(g, loc=snl_loc, bbox_to_anchor=snl_pos , ncol=snl_ncol,  frameon=snl_frameon, fontsize=sn_fontsize, title=snl_title, title_fontsize=sn_title_fontsize)
  
    # column titles and grid are axis-level
    g.set_titles(row_template="") 
    for i, ax in enumerate(g.axes[0]):
        ax.set_title(colnames[i], fontsize=sn_fontsize)
        if sng:
            ax.grid(which='minor', alpha=sng_minor_alpha)
            ax.grid(which='major', alpha=sng_major_alpha) 

    # linear or log
    if sn_log:
        g.set_axis_labels(' Log Count', '',fontsize=sn_fontsize)
        plt.xscale('log')
    else:
        g.set_axis_labels('Count', '',fontsize=sn_fontsize) 

    # notes to print on bottom of figure
    g.figure.subplots_adjust(bottom=.25)

    sn_file_note =f"file: {filename};"
    sn_cuts_note =f"cuts: (Sub)Processes with >= {mincount} occurrences; {ncats} most prolific particles"

    plt.figtext(0.05, 0.09, sn_file_note, wrap=True, horizontalalignment='left', fontsize=10, color='blue')
    plt.figtext(0.05, 0.02, sn_cuts_note, wrap=True, horizontalalignment='left', fontsize=10, color='blue')

    return g
     



