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
    df_names.columns = ['property_name']

    property_dfs=[]

    for index, row in df_names.iterrows():

        pname = row['property_name'] 
        data  = h5Dataset[pname]
        dfi   = pd.DataFrame( data )
  
        # lazy, dodgy, effective for this file format
        if( dfi.columns.size ==3):
            #print(f'...splitting data for {pname} into {pname}.x,y,z')
            dfi.columns=[str(pname)+'.x', str(pname)+'.y', str(pname)+'.z']

        elif( dfi.columns.size ==1):
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

    pd.options.mode.chained_assignment = None  # default='warn'
    
    series_pdg_id   = dfo["pdg_id"]

    series_particle = series_pdg_id.copy(deep=False)

    from particle import Particle
    
    uids = np.unique( series_pdg_id )
    for uid in uids:       
        series_particle.replace( uid, Particle.from_pdgid(uid).name, inplace=True )        

    evtgen_particle_names=[ Particle.from_pdgid(uid).name for uid in uids ]
    dfo['ParticleType'] = series_particle 

    pd.options.mode.chained_assignment = 'warn' 

    return dfo, evtgen_particle_names 

# --------------------
# This function augments the passed DataFrame
# input is a pandas DataFrame
# output is same pandas DataFrame where colname int values are assigned the string value label
def replace_num_with_label(dfo, colname, label):

    pd.options.mode.chained_assignment = None  # default='warn'

    spn = dfo[colname].copy(deep=False)

    is_int = ( spn.apply( lambda x: isinstance(x, int) ) )
    
    bad_procs = spn[ is_int ]

    for i in bad_procs:       
        spn.replace(i, label, inplace=True)

    dfo[colname] = spn

    pd.options.mode.chained_assignment = 'warn' 

    return dfo

# --------------------
# This function augments the passed DataFrame
# input is a pandas DataFrame
# output is same pandas DataFrame with a new column for G4ProcessType
def add_process_names(dfo, which_end='start'):

    pd.options.mode.chained_assignment = None  # default='warn'

    prop_name   = which_end+"_process"
    newcol_name = "G4ProcessType_"+which_end
    
    # Copy the [start,end]_process Series from the original DataFrame dfo
    spn = dfo[prop_name].copy(deep=False)

    # Add G4 names for each of the process types
    # https://apc.u-paris.fr/~franco/g4doxy/html/G4ProcessType_8hh.html
    spn.replace(0, "fNotDefined", inplace=True)
    spn.replace(1, "fTransportation", inplace=True)
    spn.replace(2, "fElectromagnetic", inplace=True)
    spn.replace(3, "fOptical", inplace=True)
    spn.replace(4, "fHadronic", inplace=True)
    spn.replace(5, "fPhotolepton_hadron", inplace=True)
    spn.replace(6, "fDecay", inplace=True)
    spn.replace(7, "fGeneral", inplace=True)
    spn.replace(8, "fParameterisation", inplace=True)

    # add the Series as a new column in the original DataFrame
    dfo[newcol_name] = spn

    # if any of the values are ints rather than strings, they are spurious.
    replace_num_with_label(dfo, newcol_name, "SpuriousProcess")

    pd.options.mode.chained_assignment = 'warn' 

    return dfo, dfo[newcol_name].unique()

# --------------------
# This function augments the passed DataFrame
# input is a pandas DataFrame
# output is same pandas DataFrame with a new column for G4SubProcessType
def add_subprocess_names(dfo, which_end='start'):       

    pd.options.mode.chained_assignment = None  # default='warn'

    prop_name   = which_end+"_subprocess"
    newcol_name = "G4SubProcessType_"+which_end
    
    # Copy the [start,end]_process Series from the original DataFrame dfo
    spn = dfo[prop_name].copy(deep=False)

    spn.replace(0,  "fNotDefined",             inplace=True)

    # Add G4 names for each of the subprocess types
    # This is the complete set as of April 2026.I have used identical naming and capitalising to the G4 code.
    # https://apc.u-paris.fr/~franco/g4doxy/html/G4EmProcessSubType_8hh.html
    spn.replace(1,  "fCoulombScattering",     inplace=True)
    spn.replace(2,  "fIonisation",            inplace=True)
    spn.replace(3,  "fBremsstrahlung",        inplace=True)
    spn.replace(4,  "fPairProdByCharged",     inplace=True)
    spn.replace(5,  "fAnnihilation",          inplace=True)
    spn.replace(6,  "fAnnihilationToMuMu",    inplace=True)
    spn.replace(7,  "fAnnihilationToHadrons", inplace=True)
    spn.replace(8,  "fNuclearStopping",       inplace=True)
    spn.replace(10, "fMultipleScattering",    inplace=True)
    spn.replace(11, "fRayleigh",              inplace=True)
    spn.replace(12, "fPhotoElectricEffect",   inplace=True)
    spn.replace(13, "fComptonScattering",     inplace=True)
    spn.replace(14, "fGammaConversion",       inplace=True)
    spn.replace(15, "fGammaConversionToMuMu", inplace=True)
    spn.replace(21, "fCerenkov",              inplace=True)
    spn.replace(22, "fScintillation",         inplace=True)
    spn.replace(23, "fSynchrotronRadiation",  inplace=True)
    spn.replace(24, "fTransitionRadiation",   inplace=True)  

    # https://apc.u-paris.fr/~franco/g4doxy/html/G4TransportationProcessType_8hh.html      
    spn.replace(91,  "TRANSPORTATION",         inplace=True)
    spn.replace(92,  "COUPLED_TRANSPORTATION", inplace=True)
    spn.replace(401, "STEP_LIMITER",           inplace=True)
    spn.replace(402, "USER_SPECIAL_CUTS",      inplace=True)
    spn.replace(403, "NEUTRON_KILLER",         inplace=True)

    # https://apc.u-paris.fr/~franco/g4doxy/html/G4HadronicProcessType_8hh.html
    spn.replace(111, "fHadronElastic",    inplace=True)
    spn.replace(121, "fHadronInelastic",  inplace=True)
    spn.replace(131, "fCapture",          inplace=True)
    spn.replace(141, "fFission",          inplace=True)
    spn.replace(151, "fHadronAtRest",     inplace=True)
    spn.replace(152, "fLeptonAtRest",     inplace=True)
    spn.replace(161, "fChargeExchange",   inplace=True) 
    spn.replace(210, "fRadioactiveDecay", inplace=True)

    # https://apc.u-paris.fr/~franco/g4doxy/html/G4DecayProcessType_8hh.html
    spn.replace(201, "DECAY",             inplace=True)
    spn.replace(210, "DECAY_Radioactive", inplace=True)
    spn.replace(211, "DECAY_Unknown",     inplace=True)
    spn.replace(231, "DECAY_External",    inplace=True)
   
    # add the Series as a new column in the original DataFrame
    dfo[newcol_name] = spn

    # if any of the values are ints rather than strings, they are spurious.
    replace_num_with_label(dfo, newcol_name, "SpuriousSubProcess")

    pd.options.mode.chained_assignment = 'warn' 

    return dfo, dfo[newcol_name].unique()


# --------------------
# This function prints out a sliced dataframe
# input is a pandas DataFrame
def print_spurious_processes(dfo):

    # All of the process numbers I am acknowledging
    named_p_enums = list(range(0,9))
    # All of the subprocess numbers I am acknowledging
    named_sp_enums=[]
    named_sp_enums.append(0)
    named_sp_enums.extend( list(range(1,  8) ) )
    named_sp_enums.extend( list(range(10,15) ) )
    named_sp_enums.extend( list(range(21,24) ) )
    named_sp_enums.extend( [91,92,401,402,403] )
    named_sp_enums.extend( [111,121,131,141,151,152,161,210] )
    named_sp_enums.extend( [201,210,211,231] )

    # numpy array of unique occurrences of eg start_process
    ar_unique_p   = dfo["start_process"].unique()
    ar_unique_sp  = dfo["start_subprocess"].unique()

    # list of values outside the expected subprocess numbers
    spurious_processes    = [s for s in ar_unique_p  if s not in named_p_enums ] 
    #print('Unrecognised start_process numbers ({}):{}\n'.format(len(spurious_processes), spurious_processes))

    spurious_subprocesses = [s for s in ar_unique_sp if s not in named_sp_enums ] 
    #print('Unrecognised start_subprocess numbers ({}):{}\n'.format(len(spurious_subprocesses), spurious_subprocesses))

    selA = ( dfo["start_process"].isin(spurious_processes)  )   
    selB = ( dfo["start_subprocess"].isin(spurious_subprocesses)  )   
    df_strange     = dfo[ selA | selB ]

    df_strange_slim = df_strange[["parent_id", "pdg_id", "start_process", "G4ProcessType_start", "start_subprocess", "G4SubProcessType_start", "E_start", "end_process", "end_subprocess","E_end" ]]
        
    print('Slimmed DF for weird subprocess numbers:' ) 
    print(df_strange_slim.to_string(index=False))

    return
    
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

    #print("Reducing category space. Selecting top {} of {} particles and processes, subproccesses with a minimum of {} occurrences.\n".format(ncats, nparticletypes, mincount ) )
    
    if(ncats>nparticletypes):
        ncats=nparticletypes

    highest_process_count = dfo[catname2].value_counts().max()
    highest_subprocess_count = dfo[catname3].value_counts().max()
    #second_highest_process_count = dfo[catname2].value_counts().nlargest(2).iloc[-1]
    
    hmax = min(highest_process_count , highest_subprocess_count )

    if(mincount > hmax):
        #print(f"you have selected mincount={mincount} which excludes all processes. Resetting to mincount={hmax-1}")
        mincount = hmax-1

    dfr = dfo.copy(deep=False)

    if(ncats==0 and mincount==0):
        print('Neither ncats>0 or mincount>0 (or both) are specified. Returning original df')
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
# Make a plot, what a faff
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

    # splitting into columns according to G4Process
    colnames = dfo[cat2].unique()

    # legend - more faffing below
    snl_frameon  = True   

    # grid     
    sng = True
    sng_minor_alpha = 0.2
    sng_major_alpha = 0.6    

    # make the plots
    g = sns.displot(
            data=dfo, 
            hue=cat1, col=cat2, y=cat3, 
            palette=sn_palette, multiple=sn_multiple, alpha=sn_alpha,  hue_order = pt_by_count,
        )

    # adjustments so legend can go outside figure
    # ncols plus space for ylabels on left and legend on right
    # if ncats>climit we split legend into columns and need more space
    climit = 15
    nparticletypes = dfo[cat1].nunique()

    # if we asked for more particles types than there are, fix that.
    if( ncats > nparticletypes ):
        ncats = nparticletypes

    snl_ncol = 1
    if( ncats > climit ): 
        # eg if ncats=20, snl_col=20/15 = 2
        snl_ncol = np.ceil( 1*(ncats/climit) )

    tot_ncols = len(colnames) + 1 + snl_ncol 
    colwidth  = 1 / tot_ncols
    # left edge of last column 
    snl_r     = 1 - snl_ncol * colwidth
    # center of last column 
    snl_rc    = 1 - 0.5 * snl_ncol * colwidth
    
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

    sn_file_note = f"file: {filename};"
    sn_cuts_note = f"cuts: (Sub)Processes with >= {mincount} occurrences; {ncats} most prolific particles"

    plt.figtext(0.05, 0.09, sn_file_note, wrap=True, horizontalalignment='left', fontsize=10, color='blue')
    plt.figtext(0.05, 0.02, sn_cuts_note, wrap=True, horizontalalignment='left', fontsize=10, color='blue')

    return g
     



