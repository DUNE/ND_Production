#include "TG4Event.h"
#include "gRooTracker.h"

// Simple root macro meant to take in an output file from edep-sim
// containing single neutrino interactions (from some flux) in the
// event tree and overlay these events into full spills.
//
// The macro can build signal only spills (setting inFileBkgPOT to 0),
// bkg only spills (setting inFileSignalPOT to 0) or signal + bkg spills
// (setting both inFileSignalPOT and inFileBkgPOT to be greater than 0).
//
// When building signal only spills one can run in "N Interaction" mode
// by specifying a number less than or equal to 10000 as spillPOT. Useful,
// for example, for studying single neutrino spills.
//
// The output will have two changes with respect to the input:
//
//   (1) The EventId for bkg events is set by ND_PRODUCTION_RUN_OFFSET.
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

  long double nu_production_time = getLBNFProtonTime();
  long double nu_parent_tof = getNuCreationTime(dk2nu_event);
  long double nu_tof = getNuTOF(dk2nu_event, genie_event, flux);

  return nu_production_time + nu_parent_tof + nu_tof;
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
                                    std::string inFileNameSignal,       // first edep filepath, usually fiducial events file
                                    std::string inFileNameBkg,          // second edep filepath, usually anti-fiducial + rock events file
                                    std::string ghepNameSignal,         // first ghep filename, set by ND_PRODUCTION_NU_NAME
                                    std::string ghepNameBkg,            // second ghep filename, set by ND_PRODUCTION_ROCK_NAME
                                    std::string prodBaseDir,            // production base dir
                                    std::string outFileName,            // output edep file
                                    int spillFileId,                    // file id
                                    double inFileSignalPOT = 1.024E19,  // #POT first edep file, set by ND_PRODUCTION_NU_POT or ND_PRODUCTION_USE_GHEP_POT
                                    double inFileBkgPOT = 1.024E19,     // #POT second edep file, set by ND_PRODUCTION_ROCK_POT or ND_PRODUCTION_USE_GHEP_POT
                                    double spillPOT = 5E13,             // #POT per spill
                                    long double spillPeriod_s = 1.2,    // spill period
                                    int hadd_factor = 10,               // number of GHEP files merged together with hadd, set by ND_PRODUCTION_HADD_FACTOR
                                    int reuseRock = 0,                  // 0: not reuse rock, 1: reuse rock
                                    std::string det_location = "DUNEND" // detector location in GNuMIFlux file, needed for the coord system conversion
                                  ) { 

  // Tools from GDk2NuFlux used for reference frame conversion 
  genie::flux::GDk2NuFlux flux;
  // read the GNuMIFlux.xml configuration
  flux.LoadConfig(det_location.c_str());

  // Maximum number of interactions that can be simulated in
  // one spill in "N Interaction" mode. Choice of this number
  // here is somewhat arbitrary, seemed like a very safe
  // upper limit on the number of nu-signal events we'd want to 
  // simulate ever in a single spill (for stress testing).
  int n_int_max = 10000;
  // Check that we are considering, nu-signal only, nu-bkg only or both.
  if (inFileSignalPOT==0. && inFileBkgPOT==0.) {
    throw std::invalid_argument("nu-signal POT and nu-bkg POT cannot both be zero!");
  }
  // "N Interaction" mode only supported in nu-signal mode.
  else if (spillPOT <= (double)n_int_max && inFileBkgPOT>0.) {
    throw std::invalid_argument("N Interaction mode does not support nu-bkg POT input");
  }

  // Useful bools for keeping track of event types being considered.
  bool have_nu_signal = false;
  bool have_nu_bkg = false;
  bool is_n_int_mode = false;


  // get input nu-signal GHEP and EDEPSIM (with edep and genie trees) files 
  TChain* ghep_evts_signal = new TChain("gtree");
  TChain* edep_evts_signal = new TChain("EDepSimEvents");
  TChain* genie_evts_signal = new TChain("DetSimPassThru/gRooTracker");
  if(inFileSignalPOT > 0.) {
    auto ghepFilesSignal = getGHEPfiles(prodBaseDir.c_str(), ghepNameSignal.c_str(), hadd_factor, spillFileId);
    edep_evts_signal->Add(inFileNameSignal.c_str());
    genie_evts_signal->Add(inFileNameSignal.c_str());
    std::for_each(ghepFilesSignal.begin(), ghepFilesSignal.end(), [&](std::string const& fname){
      ghep_evts_signal->Add(fname.c_str());
    });
    have_nu_signal = true;
    if(spillPOT <= (double)n_int_max) is_n_int_mode = true;
  }
  gRooTracker genie_evts_signal_data(genie_evts_signal);
  
  // get input nu-bkg GHEP and EDEPSIM (with edep and genie trees) files
  TChain* ghep_evts_bkg = new TChain("gtree");
  TChain* edep_evts_bkg = new TChain("EDepSimEvents");
  TChain* genie_evts_bkg = new TChain("DetSimPassThru/gRooTracker");
  if(inFileBkgPOT > 0.) {
    auto ghepFilesBkg = getGHEPfiles(prodBaseDir.c_str(), ghepNameBkg.c_str(), hadd_factor, spillFileId);
    edep_evts_bkg->Add(inFileNameBkg.c_str());
    genie_evts_bkg->Add(inFileNameBkg.c_str());
    std::for_each(ghepFilesBkg.begin(), ghepFilesBkg.end(), [&](std::string const& fname){
      ghep_evts_bkg->Add(fname.c_str());
    });
    have_nu_bkg = true;
  }
  gRooTracker genie_evts_bkg_data(genie_evts_bkg);

  // Dump some useful information about the running mode.
  if(have_nu_signal && !have_nu_bkg){
    std::cout << "nu-bkg file POT stated to be zero, spills will be signal only" << std::endl;
    if(is_n_int_mode) {
      std::cout << "Running in N Interaction mode with " << spillPOT << " interactions per spill" << std::endl;
    }
  }
  else if(!have_nu_signal && have_nu_bkg){
    std::cout << "nu-signal file POT stated to be zero, spills will be bkg only" << std::endl;
  }
  else if(have_nu_signal && have_nu_bkg){
    std::cout << "nu-signal and nu-bkg file POTs stated to be non-zero, spills will be signal+bkg" << std::endl;
  }

  // make output file
  TFile* outFile = new TFile(outFileName.c_str(),"RECREATE");
  TTree* new_tree;
  TTree* genie_tree;
  if(have_nu_signal) {
    new_tree = edep_evts_signal->CloneTree(0);
    genie_tree = genie_evts_signal->CloneTree(0);
  }
  else {
    new_tree = edep_evts_bkg->CloneTree(0);
    genie_tree = genie_evts_bkg->CloneTree(0);
  }
  gRooTracker genie_tree_data(genie_tree);
  TBranch* out_branch = new_tree->GetBranch("Event");

  // determine events per spill
  unsigned int N_evts_signal = 0;
  double evts_per_spill_signal = 0.;
  if(have_nu_signal) {
    N_evts_signal = edep_evts_signal->GetEntries();
    evts_per_spill_signal = ((double)N_evts_signal)/(inFileSignalPOT/spillPOT);
    if (is_n_int_mode) {
      evts_per_spill_signal = spillPOT;
    }
  }

  unsigned int N_evts_bkg = 0;
  double evts_per_spill_bkg = 0.;
  std::vector<int> evt_it_bkg_sequence;
  if(have_nu_bkg) {
    N_evts_bkg = edep_evts_bkg->GetEntries();
    evts_per_spill_bkg = ((double)N_evts_bkg)/(inFileBkgPOT/spillPOT);
    // Create a vector of sequential integers with length equal to the number
    // of entries in the bkg tree to act as bkg tree entry indices.
    for (int idx = 0; idx < N_evts_bkg; idx++) evt_it_bkg_sequence.push_back(idx);

    // Now shuffle it with the spillFileId for a seed for reproducibility if we
    // are reusing bkg.
    if (reuseRock) {
      std::mt19937 g(spillFileId);
      std::shuffle(evt_it_bkg_sequence.begin(), evt_it_bkg_sequence.end(), g);
    }
  }

  std::cout << "File: " << inFileNameSignal << std::endl;
  std::cout << "    Number of spills: "<< (is_n_int_mode ? 
    std::floor((double)N_evts_signal/evts_per_spill_signal) : inFileSignalPOT/spillPOT) << std::endl;
  std::cout << "    Events per spill: "<< evts_per_spill_signal << std::endl;

  std::cout << "File: " << inFileNameBkg << std::endl;
  std::cout << "    Number of spills: "<< inFileBkgPOT/spillPOT << std::endl;
  std::cout << "    Events per spill: "<< evts_per_spill_bkg << std::endl;

  bsim::Dk2Nu* dk2nu_evt = nullptr;
  TG4Event* edep_evt = nullptr;
  if(have_nu_signal) {
    ghep_evts_signal->SetBranchAddress("dk2nu",&dk2nu_evt);
    edep_evts_signal->SetBranchAddress("Event",&edep_evt);
  }
  if(have_nu_bkg) {
    ghep_evts_bkg->SetBranchAddress("dk2nu",&dk2nu_evt);
    edep_evts_bkg->SetBranchAddress("Event",&edep_evt);
  }

  TMap* event_spill_map = new TMap(N_evts_signal+N_evts_bkg);

  int evt_it_signal = 0;
  int evt_it_bkg = 0;

  for (int spillN = 0; ; ++spillN) {
    int Nevts_this_spill_signal = 0;
    if(have_nu_signal) {
      Nevts_this_spill_signal = gRandom->Poisson(evts_per_spill_signal);
      // In N Interaction mode, fixed number of events 
      // per spill.
      if(is_n_int_mode) Nevts_this_spill_signal = spillPOT;
    }
    int Nevts_this_spill_bkg = 0;
    if(have_nu_bkg) {
      Nevts_this_spill_bkg = gRandom->Poisson(evts_per_spill_bkg);
    }

    if (evt_it_signal + Nevts_this_spill_signal > N_evts_signal ||
        evt_it_bkg + Nevts_this_spill_bkg > N_evts_bkg)
      break;

    std::cout << "working on spill # " << spillN << std::endl;

    int Nevts_this_spill = Nevts_this_spill_signal + Nevts_this_spill_bkg;
    std::vector<TaggedTime> times(Nevts_this_spill);

    // loop on the events within a spill, to take into account also the neutrino TOF before reaching the detector:
    // so for each event I need to compute the interaction time
    // then fill a vector with these times, and sort it
    int nPrimaryPart = 0;
    int nTrajectories = 0;
    for (int i = 0; i < Nevts_this_spill; ++i){
      // consider as signal events the first Nevts_this_spill_signal events
      bool is_nu = i < Nevts_this_spill_signal;
      
      int& evt_it = is_nu ? evt_it_signal : evt_it_bkg;

      TTree* in_tree = is_nu ? edep_evts_signal : edep_evts_bkg;
      TTree* gn_tree = is_nu ? genie_evts_signal : genie_evts_bkg;
      TTree* ghep_tree = is_nu ? ghep_evts_signal : ghep_evts_bkg;

      auto entry = is_nu ? evt_it + i : evt_it_bkg_sequence.at(evt_it + i - Nevts_this_spill_signal);
      in_tree->GetEntry(entry);
      gn_tree->GetEntry(entry);
      ghep_tree->GetEntry(entry);

      gRooTracker& genie_evt = is_nu ? genie_evts_signal_data : genie_evts_bkg_data;

      times[i] = TaggedTime(getInteractionTime_LBNF(*dk2nu_evt, genie_evt, flux), is_nu, is_nu ? evt_it + i : evt_it_bkg_sequence.at(evt_it + i - Nevts_this_spill_signal));

      // needed to count the the number of primary particles and trajectories, 
      // (referred to point (3) at the beginning). We select just the first entry since
      // we have always 1 interaction vertex
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
    // there first time is associated with first event
    // instead here: first time -> corresponding event 
    for (const auto& ttime : times) {
      bool is_nu = ttime.tag;

      TTree* in_tree = is_nu ? edep_evts_signal : edep_evts_bkg;
      TTree* gn_tree = is_nu ? genie_evts_signal : genie_evts_bkg;

      int& evt_it = is_nu ? evt_it_signal : evt_it_bkg;

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

      gRooTracker& genie_evt = is_nu ? genie_evts_signal_data : genie_evts_bkg_data;
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
      auto v = edep_evt->Primaries[0];
      old_event_time = v.Position.T();
      v.Position.SetT(event_time);
      // TMS reco wants the InteractionNumber to be the entry number of the
      // vertex in DetSimPassThru/gRooTracker. Since, by construction, our
      // EDepSimEvents and gRooTracker trees are aligned one-to-one, we just
      // trivially set InteractionNumber to be the current entry number.
      // https://github.com/DUNE/2x2_sim/issues/54
      v.InteractionNumber = evt_it_signal + evt_it_bkg;
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

  // Pass on the geometry from the nu-signal file by default.
  auto inFileForGeom = new TFile(have_nu_signal ? inFileNameSignal.c_str() : inFileNameBkg.c_str());
  auto geom = (TGeoManager*) inFileForGeom->Get("EDepSimGeometry");

  outFile->cd();
  geom->Write();
  new_tree->Write();
  event_spill_map->Write("event_spill_map", 1);
  auto p = new TParameter<double>("spillPeriod_s", spillPeriod_s);
  p->Write();
  auto potps = new TParameter<double>("pot_per_spill", is_n_int_mode ? -1 : spillPOT);
  potps->Write();
  const auto inFileSignalPOT_used = N_evts_signal ? (inFileSignalPOT * evt_it_signal / N_evts_signal) : 0;
  auto potSignal = new TParameter<double>("potSignal", inFileSignalPOT_used);
  potSignal->Write();
  const auto inFileBkgPOT_used = N_evts_bkg ? (inFileBkgPOT * evt_it_bkg / N_evts_bkg) : 0;
  auto potBkg = new TParameter<double>("potBkg", inFileBkgPOT_used);
  potBkg->Write();

  outFile->mkdir("DetSimPassThru");
  outFile->cd("DetSimPassThru");
  genie_tree->Write();

  inFileForGeom->Close();
  delete inFileForGeom;
  delete event_spill_map;
  outFile->Close();
  delete outFile;
}
