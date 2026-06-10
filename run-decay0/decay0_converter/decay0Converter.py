import ROOT
import random, math
import numpy as np
import matplotlib.pyplot as plt
from array import array
import fire

decay0ToPdgId = {   
                    1:22,   # gamma
                    2:-11,  # e+
                    3:11,   # e-
                    13:2112,# n
                    14:2212,# p
                    47:1000020040 # alpha
                    } # maybe make a handler for 0 (which is INVALID)

decay0ToMass_MeV = {
                    1:0.0,    # gamma
                    2:0.51099906,  # e+
                    3:0.51099906,   # e-
                    13:939.56563,# n
                    14:938.27231,# p
                    47:3727.417 # alpha
                    }


def convert(input_file,output_file,n_events=-1,start_ind=0,no_Tl208=False):
    # input_file = "genBiPo212-1.d0t"
    # output_file = "genBiPo212-test.DECAY0.root"
    # n_events = -1  # set to -1 to convert all events
    # coincident = True - split all blocks into 2 blocks
    # coincident_time_threshold_s = 1e-10 # 0.1 ns - time threshold to split events into coincident events
    # right now only 2 blocks are used (so just Bi212 really)
    
    # P = []
    print("Reading input file: {}".format(input_file))
    print("Output file: {}".format(output_file))
    print("Number of events to convert: {}".format(n_events if n_events!=-1 else "All"))
    print("Starting event index: {}".format(start_ind))
    print("No Tl208 events: {}".format(no_Tl208))

    with open(input_file, 'r') as f:
        text = f.read().rstrip()
    blocks = [block.split('\n') for block in text.split('\n\n')][start_ind:]  # each block is one event
    numEvt = len(blocks)

    if n_events!=-1: # set number of events to convert
        if numEvt < n_events:
            print("Warning: Requested number of events ({}) is greater than available ({}). Converting all available events.".format(n_events, numEvt))
        numEvt = n_events
        blocks = blocks[:n_events]

    # numEvt *= (1 + coincident)  # double number of events if coincident splitting is on
    evt_idx,evt_VtxT,evt_parent = np.array([block[0].split() for block in blocks]).T
    evt_numPart = [int(block[1]) for block in blocks]
    evt_part_vals = [[line.split()for line in block[2:]]for block in blocks] # numEvt x numPart x 5
    maxPart = max(evt_numPart) # TODO: this will be greater than needed if coincident events are made...
    # -print(max([float(vals[1]) for part_vals in evt_part_vals for vals in part_vals])) # debug print of max time

    outfile = ROOT.TFile(output_file, "RECREATE")
    tree = ROOT.TTree("gRooTracker", "Realistic Fake GTRAC file")

    evtCode = ROOT.TObjString("")

    evtFlags = ROOT.TBits(16)
    evtFlags.ResetAllBits()  # Ensure all bits are cleared.

    evtNum   = array("i", [0])
    # evtKPS   = array("i", [10])    #Shall be 23 if we consider resonant elastic scattering 
    evtXSec  = array("d", [1.])   # cross section in 1e-38 cm^2 units (lognormal)
    evtDXSec = array("d", [1.])   # differential cross section in 1e-38 cm^2/Kn (unchanged)
    evtWght  = array("d", [1.])   # event weight (we keep this as a branch, though tree weight is set)
    evtProb  = array("d", [1.])   # event probability (lognormal)
    # EvtVtx is a 4-vector: x, y, z in meters, t in seconds (SI units)
    evtVtx   = array("d", [0.0, 0.0, 0.0, 0.0])
    
    # -------------------------------
    # Create particle-level leaf branches.
    # These are arrays with maxPart elements (or maxPart*#components for vectors)
    # -------------------------------
    stdHepN      = array("i", [0])                # number of particles in this event
    stdHepPdg    = array("i", [0] * maxPart)         # PDG code for each particle
    stdHepStatus = array("i", [1] * maxPart)         # status code for each particle
    stdHepRescat = array("i", [304896457] * maxPart)         # rescattering code for each particle
    
    # For the 4-vectors (position and momentum), create flat arrays of size maxPart*4.
    stdHepX4 = array("d", [0.0] * (maxPart * 4))    # 4-position in m (x, y, z, t)
    stdHepP4 = array("d", [0.0] * (maxPart * 4))    # 4-momentum in MeV (px, py, pz, E)
    
    # For polarization, an array of size maxPart*3 (3-vector per particle)
    stdHepPolz = array("d", [0.0] * (maxPart * 3))    # polarization 3-vector
    # stdHepPolz = [[0,0,0]] * maxPart               # polarization 3-vector
    
    # Daughter and mother indices: arrays of maxPart ints.
    stdHepFd = array("i", [0] * maxPart)
    stdHepLd = array("i", [0] * maxPart)
    stdHepFm = array("i", [0] * maxPart)
    stdHepLm = array("i", [0] * maxPart)
    
    # -------------------------------
    # Create branches in the tree.
    # -------------------------------
    tree.Branch("EvtFlags", evtFlags, 32000, 1)
    tree.Branch("EvtCode", evtCode, 32000, 1)
    tree.Branch("EvtNum", evtNum, "EvtNum/I")
    tree.Branch("EvtXSec", evtXSec, "EvtXSec/D")
    tree.Branch("EvtDXSec", evtDXSec, "EvtDXSec/D")
    tree.Branch("EvtWght", evtWght, "EvtWght/D")
    tree.Branch("EvtProb", evtProb, "EvtProb/D")
    tree.Branch("EvtVtx", evtVtx, "EvtVtx[4]/D")
    tree.Branch("StdHepN", stdHepN, "StdHepN/I")
    tree.Branch("StdHepPdg", stdHepPdg, "StdHepPdg[{}]/I".format(maxPart))
    tree.Branch("StdHepStatus", stdHepStatus, "StdHepStatus[{}]/I".format(maxPart))
    tree.Branch("StdHepRescat", stdHepRescat, "StdHepRescat[{}]/I".format(maxPart))
    tree.Branch("StdHepX4", stdHepX4, "StdHepX4[{}][4]/D".format(maxPart))
    tree.Branch("StdHepP4", stdHepP4, "StdHepP4[{}][4]/D".format(maxPart))
    tree.Branch("StdHepPolz", stdHepPolz, "StdHepPolz[{}][3]/D".format(maxPart))
    tree.Branch("StdHepFd", stdHepFd, "StdHepFd[{}]/I".format(maxPart))
    tree.Branch("StdHepLd", stdHepLd, "StdHepLd[{}]/I".format(maxPart))
    tree.Branch("StdHepFm", stdHepFm, "StdHepFm[{}]/I".format(maxPart))
    tree.Branch("StdHepLm", stdHepLm, "StdHepLm[{}]/I".format(maxPart))

    # # Debug: plot histogram of delayed event times
    # delayed_times = evt_VtxT
    # fig = plt.figure()
    # t = [float(t)*1e9 for t in delayed_times if float(t)!=0]
    # plt.hist(t, bins=100, histtype='step', label='Delayed event times (N={})'.format(len(t)))
    # plt.xlabel("Time after primary (ns)")
    # plt.ylabel("Counts")
    # plt.title("Histogram of delayed event times")
    # plt.legend()
    # plt.savefig("delayed_event_times_hist.png")
    # plt.close(fig)
    # -print()

    # beta_ke = []
    Total_ke = []

    for i_evt in range(numEvt):
        evtNum[0] = i_evt
        # print(evt_part_vals)
        if int(evt_idx[i_evt]) != i_evt:
            print("Warning: Event index mismatch at event {}: evt_idx[i_evt]={} but i={}".format(i_evt, evt_idx[i_evt], i_evt))
        
        vtxT = float(evt_VtxT[i_evt])
        parent = evt_parent[i_evt]
        
        evtVtx[0] = 0. # x in meters
        evtVtx[1] = 0. # y in meters
        evtVtx[2] = 0. # z in meters
        evtVtx[3] = vtxT

        numPart = evt_numPart[i_evt]
        if numPart:
            part_pdg,part_t,part_px,part_py,part_pz = np.array(evt_part_vals[i_evt]).T
            if numPart != len(part_pdg):
                print("Warning: Number of particles mismatch at event {}: numPart={} but len(part_pdg)={}".format(i_evt, numPart, len(part_pdg)))
                # numPart = min(numPart, len(part_pdg))
            if no_Tl208 and part_pdg[0]=='47': # skip events with Tl208 (which is the parent of Bi212 and thus the source of the delayed BiPo212 events)
                continue

        stdHepN[0]      = numPart                # number of particles in this event
        
        # For the 4-vectors (position and momentum), create flat arrays of size maxPart*4.
        for i in range(maxPart*4):
            stdHepX4[i] = 0.0
            stdHepP4[i] = 0.0

        # p = 0.0  # total momentum for debug print
        total_ke = 0.0

        for i_part in range(maxPart):
            stdHepPdg[i_part] = 0
            stdHepStatus[i_part] = 1
            stdHepRescat[i_part] = 304896457

        for i_part in range(numPart):
            decay0Pdg = int(part_pdg[i_part])
            t = float(part_t[i_part]) # convert to ns?
            px = float(part_px[i_part])
            py = float(part_py[i_part])
            pz = float(part_pz[i_part])

            mass = decay0ToMass_MeV[decay0Pdg]
            energy = math.sqrt(px**2 + py**2 + pz**2 + mass**2)
            # if i_part==0 and decay0Pdg == 3:
            #     beta_ke += [energy - mass]
            # e = energy - mass
            # total_ke += e
            # p += e

            stdHepPdg[i_part] = decay0ToPdgId[decay0Pdg]
            # stdHepStatus[i_part] = 1
            # stdHepRescat[i_part] = 304896457

            stdHepP4[i_part*4+0] = px / 1000  # Convert to GeV
            stdHepP4[i_part*4+1] = py / 1000  # Convert to GeV
            stdHepP4[i_part*4+2] = pz / 1000  # Convert to GeV
            stdHepP4[i_part*4+3] = energy / 1000  # Convert to GeV

            stdHepX4[i_part*4+0] = evtVtx[0]
            stdHepX4[i_part*4+1] = evtVtx[1]
            stdHepX4[i_part*4+2] = evtVtx[2]
            stdHepX4[i_part*4+3] = t # NOTE: This is not used as far as I can tell nor is it stored except in DECAY0.root StdHepX4 FALSE IT STORED
        # Fill the tree for this event.
        tree.Fill()
        # Debug printout of total momentum
        # P+= [p]
        # Total_ke += [total_ke]
        # print(np.sum(stdHepP4[3::4]))
    
    # Write out the tree and close the file.
    tree.Write()
    # print(P)
    outfile.Close()

    # Debug: plot histogram of Pb212 total kinetic energy per event
    # fig = plt.figure()
    # plt.hist(Total_ke, bins=100, histtype='step', label='Total kinetic energy per event (N={})'.format(len(Total_ke)))
    # plt.xlabel("Total kinetic energy (MeV)")
    # plt.ylabel("Counts")
    # plt.title("Histogram of total kinetic energy per Pb212 event")
    # plt.legend()
    # plt.savefig("total_kinetic_energy_hist.png")
    # plt.close(fig)

    # # Debug: plot histogram of Bi->Po beta spectrum
    # if beta_ke:
    #     fig = plt.figure()
    #     plt.hist(beta_ke, bins=100, histtype='step', label='Bi->Po beta spectrum (N={})'.format(len(beta_ke)))
    #     plt.xlabel("Beta kinetic energy (MeV)")
    #     plt.ylabel("Counts")
    #     plt.title("Histogram of Bi->Po beta spectrum")
    #     plt.legend()
    #     plt.savefig("bi_po_beta_spectrum_hist.png")
    #     plt.close(fig)
    
if __name__ == "__main__":
    fire.Fire(convert)