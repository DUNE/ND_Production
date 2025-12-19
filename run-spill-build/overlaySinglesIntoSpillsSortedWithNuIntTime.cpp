#include "TG4Event.h"
#include "gRooTracker.h"

// Simple ROOT macro meant to take in an output file from edep-sim
// containing single neutrino interactions (from some flux) in the
// event tree and overlay these events into full spills.
//
// The macro can build sample_A only spills (setting inFileBPOT to 0),
// sample_B only spills (setting inFileAPOT to 0) or sample_A + sample_B spills
// (setting both inFileAPOT and inFileBPOT to be greater than 0).
//
// When building sample_A only spills, one can run in "N Interaction" mode
// by specifying a number less than or equal to 10000 as spillPOT. Useful,
// for example, for studying single neutrino spills.
//
// The output will still have one single neutrino interaction per entry, 
// but with three changes with respect to the input:
//
//   (1) The EventId for sample_B events is set by ND_PRODUCTION_RUN_OFFSET.
//
//   (2) The timing information is edited to impose the timing microstructure of
//       the LBNF beamline, the neutrino parent time of flight, the neutrino time of flight 
//       and the "macrostructure" (spill period).
//   
//   (3) The TrackId follows the edep-sim convention: first all primaries, and all the primaries
//       trajectories; then the secondaries, and the secondaries trajectories

constexpr long double conversionTo_ns = 1.E9; 
constexpr long double c = TMath::C() / conversionTo_ns; // [m/ns]

// The following two methods are inspired by the ones present in run-cafmaker
// Needed to read GHEP files to take into account the "misalignment" 
// between GHEP files and EDEPSIM file due to the hadd step
std::string getPath(std::string const& base_outdir, std::string const& step, std::string const& ghep_fname, std::string const& ftype, std::string const& ext, int file_id){
  int subdir_num = (file_id / 1000) *1000;
  std::ostringstream oss;
  oss << std::setw(7) << std::setfill('0') << subdir_num;
  std::string subdir = oss.str();

  std::ostringstream oss_fileid;
  oss_fileid << std::setw(7) << std::setfill('0') << file_id;
  std::string fileid_str = oss_fileid.str();

  std::string path = base_outdir + "/" + step + "/" + ghep_fname + "/" + ftype + "/" + subdir +
                      "/" + ghep_fname + "." + fileid_str + "." + ftype + "." + ext;

  if (!std::ifstream(path)) { 
      std::cerr << "WHERE THE HECKING HECK IS " << path << std::endl;
      throw std::runtime_error("Path does not exist: " + path);
  }

  return path;
}

std::vector<std::string> getGHEPfiles(std::string const& base_outdir,  std::string const& ghep_fname, int const& hadd_factor,  int file_id) {
  std::vector<std::string> ghep_files;
  for (int ghep_id = file_id * hadd_factor; ghep_id < (file_id + 1) * hadd_factor; ++ghep_id) {
    std::string path = getPath(base_outdir, "run-genie", ghep_fname, "GHEP", "root", ghep_id);
    ghep_files.push_back(path);
  }
  return ghep_files;
}


// Get neutrino interaction time, with the following 4 methods:

// This function returns a random time for a neutrino interaction to take place within
// a LBNF spill, given the beam's micro timing structure
double getLBNFProtonTime() {

  // time unit is nanoseconds
  double t;
  bool finding_time = true;

  while(finding_time) {
    unsigned int batch = gRandom->Integer(6); // batch number between 0 and 5 (6 total)
    unsigned int bunch = gRandom->Integer(84); // bunch number between 0 and 83 (84 total)
    if((bunch==0||bunch==1||bunch==82||bunch==83)&&gRandom->Uniform(1.)<0.5) continue;
    else {
      t = gRandom->Uniform(1.)+bunch*19.+batch*1680;
      finding_time = false;
    }
  }

  return t;

}

// This function returns the neutrino's creation time relative to a specific reference frame. Assumptions and reference system definition:
//
// - GENIE/GHEP files contain `dk2nu` information, which includes the 4-position (space-time coordinates) of the neutrino's ancestor at the moment of creation.
// - The spatial reference frame is defined as follows:
//     - Origin: Center of the upstream face of the neutrino target.
//     - Z-axis: Aligned with the neutrino beam direction.
//     - Y-axis: Vertical, pointing upward.
//     - X-axis: Completes a right-handed coordinate system.
// - The time origin is defined as the moment when the parent beam proton crosses z = -360 cm.
//
// Therefore, this function computes the neutrino's creation time with respect to that time origin.
long double getNuCreationTime(const bsim::Dk2Nu& dk2nu_event){
  auto nu = dk2nu_event.ancestor[dk2nu_event.ancestor.size()-1];
  return static_cast<long double>(nu.startt);
}

// This function returns the neutrino time of flight
long double getNuTOF(const bsim::Dk2Nu& dk2nu_event, const gRooTracker& genie_event, const genie::flux::GDk2NuFlux& flux){ 
  
  auto nu_orig = dk2nu_event.ancestor[dk2nu_event.ancestor.size()-1];
  auto nu_int = genie_event.EvtVtx;

  // Neutrino origin in beam coordinates
  TLorentzVector beamNuOrigin(nu_orig.startx, nu_orig.starty, nu_orig.startz, nu_orig.startt);
  // Neutrino origin in user coordinates
  TLorentzVector userNuOrigin;
  // Neutrino interaction point in user coordinates
  TLorentzVector userNuInteraction(nu_int[0], nu_int[1], nu_int[2], nu_int[3]);

  // conversion
  flux.Beam2UserPos(beamNuOrigin, userNuOrigin);

  // compute the nu tof
  long double tof = (userNuInteraction - userNuOrigin).Vect().Mag() / c;

  return tof;
}

// This function returns the total sum of all the contributions to the interaction time (in nanoseconds)
long double getInteractionTime_LBNF(const bsim::Dk2Nu& dk2nu_event, const gRooTracker& genie_event, const genie::flux::GDk2NuFlux& flux) { 

  long double proton_production_time = getLBNFProtonTime();
  long double nu_creation_time = getNuCreationTime(dk2nu_event);
  long double nu_tof = getNuTOF(dk2nu_event, genie_event, flux);

  return proton_production_time + nu_creation_time + nu_tof;
}
// ******************************************************************************************************

struct TaggedTime {
  long double time;
  bool tag;
  int evId; // added evId because we need to keep track of it together with time
  TaggedTime(double time, int tag, int evId) :
    time(time), tag(tag), evId(evId) {}
  TaggedTime() : time(0), tag(0), evId(0) {}
};

void overlaySinglesIntoSpillsSortedWithNuIntTime(
                                    std::string inFileNameA,            // first edepsim filepath, usually fiducial events file
                                    std::string inFileNameB,            // second edepsim filepath, usually anti-fiducial + rock events file
                                    std::string ghepNameA,              // first ghep filename, set by ND_PRODUCTION_NU_NAME
                                    std::string ghepNameB,              // second ghep filename, set by ND_PRODUCTION_ROCK_NAME
                                    std::string prodBaseDir,            // production base dir
                                    std::string outFileName,            // output edep file
                                    int spillFileId,                    // file id
                                    double inFileAPOT = 1.024E19,       // #POT first edep file, set by ND_PRODUCTION_NU_POT or ND_PRODUCTION_USE_GHEP_POT
                                    double inFileBPOT = 1.024E19,       // #POT second edep file, set by ND_PRODUCTION_ROCK_POT or ND_PRODUCTION_USE_GHEP_POT
                                    double spillPOT = 5E13,             // #POT per spill
                                    long double spillPeriod_s = 1.2,    // spill period
                                    int hadd_factor = 10,               // number of GHEP files merged together with hadd, set by ND_PRODUCTION_HADD_FACTOR
                                    int reuse_sampleB = 0,              // 0: not reuse sampleB, 1: reuse sampleB
                                    std::string det_location = "DUNEND" // detector location in GNuMIFlux file, needed for the coord system conversion
                                  ) { 

  // Tools from GDk2NuFlux used for reference frame conversion 
  genie::flux::GDk2NuFlux flux;
  // read the GNuMIFlux.xml configuration
  flux.LoadConfig(det_location.c_str());

  // Maximum number of interactions that can be simulated in
  // one spill in "N Interaction" mode. Choice of this number
  // here is somewhat arbitrary, seemed like a very safe
  // upper limit on the number of sampleA-nu events we'd want to 
  // simulate ever in a single spill (for stress testing).
  int n_int_max = 10000;
  // Check that we are considering, sampleA-nu only, sampleB-nu only or both.
  if (inFileAPOT==0. && inFileBPOT==0.) {
    throw std::invalid_argument("sampleA-nu POT and sampleB-nu POT cannot both be zero!");
  }
  // "N Interaction" mode only supported in sampleA-nu mode.
  else if (spillPOT <= (double)n_int_max && inFileBPOT>0.) {
    throw std::invalid_argument("N Interaction mode does not support sampleB-nu POT input");
  }

  // Useful bools for keeping track of event types being considered.
  bool have_nu_sampleA = false;
  bool have_nu_sampleB = false;
  bool is_n_int_mode = false;


  // get input sampleA-nu GHEP and EDEPSIM (with edep and genie trees) files 
  TChain* ghep_evts_A = new TChain("gtree");
  TChain* edep_evts_A = new TChain("EDepSimEvents");
  TChain* genie_evts_A = new TChain("DetSimPassThru/gRooTracker");
  if(inFileAPOT > 0.) {
    auto ghepFilesA = getGHEPfiles(prodBaseDir.c_str(), ghepNameA.c_str(), hadd_factor, spillFileId);
    edep_evts_A->Add(inFileNameA.c_str());
    genie_evts_A->Add(inFileNameA.c_str());
    std::for_each(ghepFilesA.begin(), ghepFilesA.end(), [&](std::string const& fname){
      ghep_evts_A->Add(fname.c_str());
    });
    have_nu_sampleA = true;
    if(spillPOT <= (double)n_int_max) is_n_int_mode = true;
  }
  gRooTracker genie_evts_A_data(genie_evts_A);
  
  // get input sampleB-nu GHEP and EDEPSIM (with edep and genie trees) files
  TChain* ghep_evts_B = new TChain("gtree");
  TChain* edep_evts_B = new TChain("EDepSimEvents");
  TChain* genie_evts_B = new TChain("DetSimPassThru/gRooTracker");
  if(inFileBPOT > 0.) {
    int sampleBFileId = spillFileId;
    if (reuse_sampleB){
      std::string hadd_sampleB_dir = prodBaseDir + "/run-hadd/" + ghepNameB + "/EDEPSIM";
      int n_hadd_sampleB_files = 0;
      auto pipe = std::unique_ptr<FILE, decltype(&pclose)>{popen(("find " + hadd_sampleB_dir + " -type f | wc -l").c_str(), "r"), pclose};
      fscanf(pipe.get(), "%d", &n_hadd_sampleB_files);
      int sampleBFileId = spillFileId % n_hadd_sampleB_files;
    }
    auto ghepFilesB = getGHEPfiles(prodBaseDir.c_str(), ghepNameB.c_str(), hadd_factor, sampleBFileId);
    edep_evts_B->Add(inFileNameB.c_str());
    genie_evts_B->Add(inFileNameB.c_str());
    std::for_each(ghepFilesB.begin(), ghepFilesB.end(), [&](std::string const& fname){
      ghep_evts_B->Add(fname.c_str());
    });
    have_nu_sampleB = true;
  }
  gRooTracker genie_evts_B_data(genie_evts_B);

  // Dump some useful information about the running mode.
  if(have_nu_sampleA && !have_nu_sampleB){
    std::cout << "sampleB-nu file POT stated to be zero, spills will be sampleA-nu only" << std::endl;
    if(is_n_int_mode) {
      std::cout << "Running in N Interaction mode with " << spillPOT << " interactions per spill" << std::endl;
    }
  }
  else if(!have_nu_sampleA && have_nu_sampleB){
    std::cout << "sampleA-nu file POT stated to be zero, spills will be sample_B only" << std::endl;
  }
  else if(have_nu_sampleA && have_nu_sampleB){
    std::cout << "sampleA-nu and sampleB-nu file POTs stated to be non-zero, spills will be sample_A+sample_B" << std::endl;
  }

  // make output file
  TFile* outFile = new TFile(outFileName.c_str(),"RECREATE");
  TTree* new_tree;
  TTree* genie_tree;
  if(have_nu_sampleA) {
    new_tree = edep_evts_A->CloneTree(0);
    genie_tree = genie_evts_A->CloneTree(0);
  }
  else {
    new_tree = edep_evts_B->CloneTree(0);
    genie_tree = genie_evts_B->CloneTree(0);
  }
  gRooTracker genie_tree_data(genie_tree);
  TBranch* out_branch = new_tree->GetBranch("Event");

  // determine events per spill
  unsigned int N_evts_A = 0;
  double evts_per_spill_A = 0.;
  if(have_nu_sampleA) {
    N_evts_A = edep_evts_A->GetEntries();
    evts_per_spill_A = ((double)N_evts_A)/(inFileAPOT/spillPOT);
    if (is_n_int_mode) {
      evts_per_spill_A = spillPOT;
    }
  }

  unsigned int N_evts_B = 0;
  double evts_per_spill_B = 0.;
  std::vector<int> evt_it_B_sequence;
  if(have_nu_sampleB) {
    N_evts_B = edep_evts_B->GetEntries();
    evts_per_spill_B = ((double)N_evts_B)/(inFileBPOT/spillPOT);
    // Create a vector of sequential integers with length equal to the number
    // of entries in the sample_B tree to act as sample_B tree entry indices.
    for (int idx = 0; idx < N_evts_B; idx++) evt_it_B_sequence.push_back(idx);

    // Now shuffle it with the spillFileId for a seed for reproducibility if we
    // are reusing sample_B.
    if (reuse_sampleB) {
      std::mt19937 g(spillFileId);
      std::shuffle(evt_it_B_sequence.begin(), evt_it_B_sequence.end(), g);
    }
  }

  std::cout << "File: " << inFileNameA << std::endl;
  std::cout << "    Number of spills: "<< (is_n_int_mode ? 
    std::floor((double)N_evts_A/evts_per_spill_A) : inFileAPOT/spillPOT) << std::endl;
  std::cout << "    Events per spill: "<< evts_per_spill_A << std::endl;

  std::cout << "File: " << inFileNameB << std::endl;
  std::cout << "    Number of spills: "<< inFileBPOT/spillPOT << std::endl;
  std::cout << "    Events per spill: "<< evts_per_spill_B << std::endl;

  bsim::Dk2Nu* dk2nu_evt = nullptr;
  TG4Event* edep_evt = nullptr;
  if(have_nu_sampleA) {
    ghep_evts_A->SetBranchAddress("dk2nu",&dk2nu_evt);
    edep_evts_A->SetBranchAddress("Event",&edep_evt);
  }
  if(have_nu_sampleB) {
    ghep_evts_B->SetBranchAddress("dk2nu",&dk2nu_evt);
    edep_evts_B->SetBranchAddress("Event",&edep_evt);
  }

  TMap* event_spill_map = new TMap(N_evts_A+N_evts_B);

  int evt_it_A = 0;
  int evt_it_B = 0;

  for (int spillN = 0; ; ++spillN) {
    int Nevts_this_spill_A = 0;
    if(have_nu_sampleA) {
      Nevts_this_spill_A = gRandom->Poisson(evts_per_spill_A);
      // In N Interaction mode, fixed number of events 
      // per spill.
      if(is_n_int_mode) Nevts_this_spill_A = spillPOT;
    }
    int Nevts_this_spill_B = 0;
    if(have_nu_sampleB) {
      Nevts_this_spill_B = gRandom->Poisson(evts_per_spill_B);
    }

    if (evt_it_A + Nevts_this_spill_A > N_evts_A ||
        evt_it_B + Nevts_this_spill_B > N_evts_B)
      break;

    std::cout << "working on spill # " << spillN << std::endl;

    int Nevts_this_spill = Nevts_this_spill_A + Nevts_this_spill_B;
    std::vector<TaggedTime> times(Nevts_this_spill);

    // loop over the events within a spill, in order to account for all 
    // the time contributions from the proton production to the neutrino interaction:
    // for each event I need to compute the interaction time
    // then fill a vector with these times, and sort it
    int nPrimaryPart = 0;
    int nTrajectories = 0;
    for (int i = 0; i < Nevts_this_spill; ++i){
      // consider as sampleA events the first Nevts_this_spill_A events
      bool is_sampleA = i < Nevts_this_spill_A;
      
      int& evt_it = is_sampleA ? evt_it_A : evt_it_B;

      TTree* in_tree = is_sampleA ? edep_evts_A : edep_evts_B;
      TTree* gn_tree = is_sampleA ? genie_evts_A : genie_evts_B;
      TTree* ghep_tree = is_sampleA ? ghep_evts_A : ghep_evts_B;

      auto entry = is_sampleA ? evt_it + i : evt_it_B_sequence.at(evt_it + i - Nevts_this_spill_A);
      in_tree->GetEntry(entry);
      gn_tree->GetEntry(entry);
      ghep_tree->GetEntry(entry);

      gRooTracker& genie_evt = is_sampleA ? genie_evts_A_data : genie_evts_B_data;

      times[i] = TaggedTime(getInteractionTime_LBNF(*dk2nu_evt, genie_evt, flux), is_sampleA, is_sampleA ? evt_it + i : evt_it_B_sequence.at(evt_it + i - Nevts_this_spill_A));

      // needed to count the the number of primary particles and trajectories, 
      // (referred to point (3) at the beginning). We select just the first entry since
      // we have always a single interaction (one interaction vertex)
      auto v = edep_evt->Primaries[0];
      nPrimaryPart += v.Particles.size();
      nTrajectories += edep_evt->Trajectories.size();
    }
    
    std::sort(times.begin(),
              times.end(),
              [](const auto& lhs, const auto& rhs) { return lhs.time < rhs.time; });

    std::cout << "This spill: " << std::endl;
    std::cout << "  - Primary particle: " << nPrimaryPart << std::endl;
    std::cout << "  - Trajectories    : " << nTrajectories << std::endl;

    int lastPriTrajId = 0;
    int lastSecTrajId = nPrimaryPart;

    // loop on times vector: different from overlaySingleIntoSpillsSorted.cpp!
    // there, the first time is associated with the first event
    // instead here: first time -> corresponding event 
    for (const auto& ttime : times) {
      bool is_sampleA = ttime.tag;

      TTree* in_tree = is_sampleA ? edep_evts_A : edep_evts_B;
      TTree* gn_tree = is_sampleA ? genie_evts_A : genie_evts_B;

      int& evt_it = is_sampleA ? evt_it_A : evt_it_B;

      in_tree->GetEntry(ttime.evId);
      gn_tree->GetEntry(ttime.evId);

      out_branch->SetAddress(&edep_evt);

      int globalSpillId = int(1E3)*spillFileId + spillN;

      std::string event_string = std::to_string(edep_evt->RunId) + " "
        + std::to_string(edep_evt->EventId);
      std::string spill_string = std::to_string(globalSpillId);
      TObjString* event_tobj = new TObjString(event_string.c_str());
      TObjString* spill_tobj = new TObjString(spill_string.c_str());

      if (event_spill_map->FindObject(event_string.c_str()) == 0)
        event_spill_map->Add(event_tobj, spill_tobj);
      else {
        std::cerr << "[ERROR] redundant event ID " << event_string.c_str() << std::endl;
        std::cerr << "event_spill_map entries = " << event_spill_map->GetEntries() << std::endl;
        throw;
      }

      double event_time = ttime.time + conversionTo_ns*spillPeriod_s*spillN;
      double old_event_time = 0.;

      gRooTracker& genie_evt = is_sampleA ? genie_evts_A_data : genie_evts_B_data;
      genie_tree_data.CopyFrom(genie_evt);
      genie_tree_data.EvtNum = edep_evt->EventId;
      genie_tree_data.EvtVtx[3] = event_time;

      // count the number of primaries, secondaries and trajectories
      int nPrimaryPartThisEvent = 0;
      nPrimaryPartThisEvent += edep_evt->Primaries[0].Particles.size();
      int nTrajectoriesThisEvent = edep_evt->Trajectories.size();
      int nSecondaryPartThisEvent = nTrajectoriesThisEvent - nPrimaryPartThisEvent;

      // function to update the TrackId as explained in the point (3) at the beginning
      auto updateTrackId = [lastPriTrajId, lastSecTrajId, nPrimaryPartThisEvent](int &trkId)
      { trkId = trkId < nPrimaryPartThisEvent ? lastPriTrajId + trkId : lastSecTrajId + trkId - nPrimaryPartThisEvent; };

      // assign the correct time to the vertex, the trajectories and the energy depositions
      // ... interaction vertex
      auto& v = edep_evt->Primaries[0];
      old_event_time = v.Position.T();
      v.Position.SetT(event_time);
      // TMS reco wants the InteractionNumber to be the entry number of the
      // vertex in DetSimPassThru/gRooTracker. Since, by construction, our
      // EDepSimEvents and gRooTracker trees are aligned one-to-one, we just
      // trivially set InteractionNumber to be the current entry number.
      // https://github.com/DUNE/2x2_sim/issues/54
      v.InteractionNumber = evt_it_A + evt_it_B;
      for (auto &p : v.Particles){
        updateTrackId(p.TrackId);
      }


      // ... trajectories
      for (std::vector<TG4Trajectory>::iterator t = edep_evt->Trajectories.begin(); t != edep_evt->Trajectories.end(); ++t) {
        // loop over all points in the trajectory
        for (std::vector<TG4TrajectoryPoint>::iterator p = t->Points.begin(); p != t->Points.end(); ++p) {
          double offset = p->Position.T() - old_event_time;
          p->Position.SetT(event_time + offset);
        }
        updateTrackId(t->TrackId);
        if (t->ParentId != -1){
          updateTrackId(t->ParentId);
        }
      }

      // ... and, finally, energy depositions
      for (auto d = edep_evt->SegmentDetectors.begin(); d != edep_evt->SegmentDetectors.end(); ++d) {
        for (std::vector<TG4HitSegment>::iterator h = d->second.begin(); h != d->second.end(); ++h) {
          double start_offset = h->Start.T() - old_event_time;
          double stop_offset = h->Stop.T() - old_event_time;
          h->Start.SetT(event_time + start_offset);
          h->Stop.SetT(event_time + stop_offset);
          updateTrackId(h->PrimaryId);
          for (auto &trkId : h->Contrib){
            updateTrackId(trkId);
          }
        }
      }

      lastPriTrajId += nPrimaryPartThisEvent;
      lastSecTrajId += nSecondaryPartThisEvent;

      new_tree->Fill();
      genie_tree->Fill();
      evt_it++;
    } // loop over events in spill
  } // loop over spills

  new_tree->SetName("EDepSimEvents");
  genie_tree->SetName("gRooTracker");

  // Pass on the geometry from the have_nu_sampleA file by default.
  auto inFileForGeom = new TFile(have_nu_sampleA ? inFileNameA.c_str() : inFileNameB.c_str());
  auto geom = (TGeoManager*) inFileForGeom->Get("EDepSimGeometry");

  outFile->cd();
  geom->Write();
  new_tree->Write();
  event_spill_map->Write("event_spill_map", 1);
  auto p = new TParameter<double>("spillPeriod_s", spillPeriod_s);
  p->Write();
  auto potps = new TParameter<double>("pot_per_spill", is_n_int_mode ? -1 : spillPOT);
  potps->Write();
  const auto inFileAPOT_used = N_evts_A ? (inFileAPOT * evt_it_A / N_evts_A) : 0;
  auto potA = new TParameter<double>("potA", inFileAPOT_used);
  potA->Write();
  const auto inFileBPOT_used = N_evts_B ? (inFileBPOT * evt_it_B / N_evts_B) : 0;
  auto potB = new TParameter<double>("potB", inFileBPOT_used);
  potB->Write();

  outFile->mkdir("DetSimPassThru");
  outFile->cd("DetSimPassThru");
  genie_tree->Write();

  outFile->Close();
  inFileForGeom->Close();

  delete outFile;
}
