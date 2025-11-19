#include "TG4Event.h"
#include "gRooTracker.h"

// Simple root macro meant to take in an output file from edep-sim
// containing single neutrino interactions (from some flux) in the
// event tree and overlay these events into full spills.
//
// The macro can build detector only spills (setting inFile2POT to 0),
// rock only spills (setting inFile1POT to 0) or detector + rock spills
// (setting both inFile1POT and inFile2POT to be greater than 0).
//
// When building detector only spills one can run in "N Interaction" mode
// by specifying a number less than or equal to 10000 as spillPOT. Useful,
// for example, for studying single neutrino spills.
//
// The output will have two changes with respect to the input:
//
//   (1) The EventId for rock events is set by ND_PRODUCTION_RUN_OFFSET.
//
//   (2) The timing information is edited to impose the timing microstructure of
//       the LBNF beamline, the neutrino parent time of flight, the neutrino time of flight 
//       and the "macrostructure" (spill period).
//   
//   (3) The TrackId follows the edep-sim convention: first all primaries, and all the primaries
//       trajectories; then the secondaries, and the secondaries trajectories

constexpr long double conversionTo_ns = 1.E9; 
constexpr long double c = TMath::C() / conversionTo_ns; // [m/ns]

// *************************************READ GHEP FILES************************************************
// We need to read GHEP files, hence we need these two methods
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
// ***************************************************************************************************


// *************************************GET NEUTRINO INTERACTION TIME*********************************
// returns a random time for a neutrino interaction to take place within
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

// This function returns the total sum of all the contributions to the interaction time
long double getInteractionTime_LBNF(const bsim::Dk2Nu& dk2nu_event, const gRooTracker& genie_event, const genie::flux::GDk2NuFlux& flux) { 

  long double nu_production_time = getLBNFProtonTime();
  long double nu_parent_tof = getNuCreationTime(dk2nu_event);
  long double nu_tof = getNuTOF(dk2nu_event, genie_event, flux);

  return nu_production_time + nu_parent_tof + nu_tof;
}
// ******************************************************************************************************

struct TaggedTime {
  long double time;
  int tag;
  int evId; // add evId because we need to keep track of it together with time
  TaggedTime(double time, int tag, int evId) :
    time(time), tag(tag), evId(evId) {}
  TaggedTime() : time(0), tag(0), evId(0) {}
};

void overlaySinglesIntoSpillsSortedWithNuIntTime(
                                    std::string inFileName1,            // first edep filepath, usually fiducial events file
                                    std::string inFileName2,            // second edep filepath, usually anti-fiducial + rock events file
                                    std::string ghepName1,              // first ghep filename, set by ND_PRODUCTION_NU_NAME
                                    std::string ghepName2,              // second ghep filename, set by ND_PRODUCTION_ROCK_NAME
                                    std::string prodBaseDir,            // production base dir
                                    std::string outFileName,            // output edep file
                                    int spillFileId,                    // file id
                                    double inFile1POT = 1.024E19,       // #POT first edep file
                                    double inFile2POT = 1.024E19,       // #POT second edep file
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
  // upper limit on the number of nu-det events we'd want to 
  // simulate ever in a single spill (for stress testing).
  int n_int_max = 10000;
  // Check that we are considering, nu-det only, nu-rock only or both.
  if (inFile1POT==0. && inFile2POT==0.) {
    throw std::invalid_argument("nu-det POT and nu-rock POT cannot both be zero!");
  }
  // "N Interaction" mode only supported in nu-det mode.
  else if (spillPOT <= (double)n_int_max && inFile2POT>0.) {
    throw std::invalid_argument("N Interaction mode does not support nu-rock POT input");
  }

  // Useful bools for keeping track of event types being considered.
  bool have_nu_det = false;
  bool have_nu_rock = false;
  bool is_n_int_mode = false;

  // ************************get input GHEP files***********
  auto ghepFiles_1 = getGHEPfiles(prodBaseDir.c_str(), ghepName1.c_str(), hadd_factor, spillFileId);
  TChain* ghep_evts_1 = new TChain("gtree");
  std::for_each(ghepFiles_1.begin(), ghepFiles_1.end(), [&](std::string const& fname){
                                                          ghep_evts_1->Add(fname.c_str());
                                                          });

  auto ghepFiles_2 = getGHEPfiles(prodBaseDir.c_str(), ghepName2.c_str(), hadd_factor, spillFileId);
  TChain* ghep_evts_2 = new TChain("gtree");
  std::for_each(ghepFiles_2.begin(), ghepFiles_2.end(), [&](std::string const& fname){
                                                          ghep_evts_2->Add(fname.c_str());
                                                          });

// **********************************************************

  // get input nu-det files
  TChain* edep_evts_1 = new TChain("EDepSimEvents");
  TChain* genie_evts_1 = new TChain("DetSimPassThru/gRooTracker");
  if(inFile1POT > 0.) {
    edep_evts_1->Add(inFileName1.c_str());
    genie_evts_1->Add(inFileName1.c_str());
    have_nu_det = true;
    if(spillPOT <= (double)n_int_max) is_n_int_mode = true;
  }
  gRooTracker genie_evts_1_data(genie_evts_1);

  // get input nu-rock files
  TChain* edep_evts_2 = new TChain("EDepSimEvents");
  TChain* genie_evts_2 = new TChain("DetSimPassThru/gRooTracker");
  if(inFile2POT > 0.) {
    edep_evts_2->Add(inFileName2.c_str());
    genie_evts_2->Add(inFileName2.c_str());
    have_nu_rock = true;
  }
  gRooTracker genie_evts_2_data(genie_evts_2);

  // Dump some useful information about the running mode.
  if(have_nu_det && !have_nu_rock){
    std::cout << "nu-rock file POT stated to be zero, spills will be detector only" << std::endl;
    if(is_n_int_mode) {
      std::cout << "Running in N Interaction mode with " << spillPOT << " interactions per spill" << std::endl;
    }
  }
  else if(!have_nu_det && have_nu_rock){
    std::cout << "nu-det file POT stated to be zero, spills will be rock only" << std::endl;
  }
  else if(have_nu_det && have_nu_rock){
    std::cout << "nu-det and nu-rock file POTs stated to be non-zero, spills will be det+rock" << std::endl;
  }

  // make output file
  TFile* outFile = new TFile(outFileName.c_str(),"RECREATE");
  TTree* new_tree;
  TTree* genie_tree;
  if(have_nu_det) {
    new_tree = edep_evts_1->CloneTree(0);
    genie_tree = genie_evts_1->CloneTree(0);
  }
  else {
    new_tree = edep_evts_2->CloneTree(0);
    genie_tree = genie_evts_2->CloneTree(0);
  }
  gRooTracker genie_tree_data(genie_tree);
  TBranch* out_branch = new_tree->GetBranch("Event");

  // determine events per spill
  unsigned int N_evts_1 = 0;
  double evts_per_spill_1 = 0.;
  if(have_nu_det) {
    N_evts_1 = edep_evts_1->GetEntries();
    evts_per_spill_1 = ((double)N_evts_1)/(inFile1POT/spillPOT);
    if (is_n_int_mode) {
      evts_per_spill_1 = spillPOT;
    }
  }

  unsigned int N_evts_2 = 0;
  double evts_per_spill_2 = 0.;
  std::vector<int> evt_it_2_sequence;
  if(have_nu_rock) {
    N_evts_2 = edep_evts_2->GetEntries();
    evts_per_spill_2 = ((double)N_evts_2)/(inFile2POT/spillPOT);
    // Create a vector of sequential integers with length equal to the number
    // of entries in the rock tree to act as rock tree entry indices.
    for (int idx = 0; idx < N_evts_2; idx++) evt_it_2_sequence.push_back(idx);

    // Now shuffle it with the spillFileId for a seed for reproducibility if we
    // are reusing rock.
    if (reuseRock) {
      std::mt19937 g(spillFileId);
      std::shuffle(evt_it_2_sequence.begin(), evt_it_2_sequence.end(), g);
    }
  }

  std::cout << "File: " << inFileName1 << std::endl;
  std::cout << "    Number of spills: "<< (is_n_int_mode ? 
    std::floor((double)N_evts_1/evts_per_spill_1) : inFile1POT/spillPOT) << std::endl;
  std::cout << "    Events per spill: "<< evts_per_spill_1 << std::endl;

  std::cout << "File: " << inFileName2 << std::endl;
  std::cout << "    Number of spills: "<< inFile2POT/spillPOT << std::endl;
  std::cout << "    Events per spill: "<< evts_per_spill_2 << std::endl;

  // **********get dk2nu branch******
  bsim::Dk2Nu* dk2nu_evt_1 = nullptr; 
  bsim::Dk2Nu* dk2nu_evt_2 = nullptr; 

  ghep_evts_1->SetBranchAddress("dk2nu",&dk2nu_evt_1);
  ghep_evts_2->SetBranchAddress("dk2nu",&dk2nu_evt_2);
  // ********************************

  TG4Event* edep_evt_1 = NULL;
  if(have_nu_det) edep_evts_1->SetBranchAddress("Event",&edep_evt_1);

  TG4Event* edep_evt_2 = NULL;
  if(have_nu_rock) edep_evts_2->SetBranchAddress("Event",&edep_evt_2);

  TMap* event_spill_map = new TMap(N_evts_1+N_evts_2);

  int evt_it_1 = 0;
  int evt_it_2 = 0;

  for (int spillN = 0; ; ++spillN) {
    std::cout << "SPILL N " << spillN << '\n';
    int Nevts_this_spill_1 = 0;
    if(have_nu_det) {
      Nevts_this_spill_1 = gRandom->Poisson(evts_per_spill_1);
      // In N Interaction mode, fixed number of events 
      // per spill.
      if(is_n_int_mode) Nevts_this_spill_1 = spillPOT;
    }
    int Nevts_this_spill_2 = 0;
    if(have_nu_rock) {
      Nevts_this_spill_2 = gRandom->Poisson(evts_per_spill_2);
    }

    if (evt_it_1 + Nevts_this_spill_1 > N_evts_1 ||
        evt_it_2 + Nevts_this_spill_2 > N_evts_2)
      break;

    std::cout << "working on spill # " << spillN << std::endl;

    int Nevts_this_spill = Nevts_this_spill_1 + Nevts_this_spill_2;
    std::vector<TaggedTime> times(Nevts_this_spill);

    // loop on the events within a spill, to take into account also the neutrino TOF before reaching SAND:
    // so for each event I need to get the interaction point and compute the interaction time
    // fill a vector with these times, and then sort it
    int nPrimaryPart = 0;
    int nTrajectories = 0;
    for (int i = 0; i < Nevts_this_spill; ++i){
      std::cout << "EVENT " << i << '\n';
      bool is_nu = i < Nevts_this_spill_1;
      int& evt_it = is_nu ? evt_it_1 : evt_it_2;

      if (is_nu) {std::cout << "FIDUCIALE " << '\n';}
      else {std::cout << "ROCCIA " << '\n';
      }

      TTree* in_tree = is_nu ? edep_evts_1 : edep_evts_2;
      TTree* gn_tree = is_nu ? genie_evts_1 : genie_evts_2;
      TTree* ghep_tree = is_nu ? ghep_evts_1 : ghep_evts_2;

      std::cout << "EVT IT " << evt_it << '\n';
      std::cout << "Sto prendendo la entry: " << (is_nu ? evt_it + i : evt_it_2_sequence.at(evt_it + i - Nevts_this_spill_1)) << '\n';
      
      in_tree->GetEntry(is_nu ? evt_it + i : evt_it_2_sequence.at(evt_it + i - Nevts_this_spill_1));
      gn_tree->GetEntry(is_nu ? evt_it + i : evt_it_2_sequence.at(evt_it + i - Nevts_this_spill_1));
      ghep_tree->GetEntry(is_nu ? evt_it + i : evt_it_2_sequence.at(evt_it + i - Nevts_this_spill_1));

      bsim::Dk2Nu* dk2nu_evt = is_nu ? dk2nu_evt_1 : dk2nu_evt_2;
      TG4Event* edep_evt = is_nu ? edep_evt_1 : edep_evt_2;
      gRooTracker genie_evt = is_nu ? genie_evts_1_data : genie_evts_2_data; 

      std::cout << "EDEP ID " << edep_evt->EventId << '\n';

      // I am considering just 1 primary vertex!!
      assert(edep_evt->Primaries.size() != 0u && "Multiple interaction vertices in the same event not supported!!");

      times[i] = TaggedTime(getInteractionTime_LBNF(*dk2nu_evt, genie_evt, flux), is_nu ? 1 : 2, is_nu ? evt_it + i : evt_it_2_sequence.at(evt_it + i - Nevts_this_spill_1));
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

    // loop on times vector: different from ND-LAr version!
    // they associate first time with first event
    // instead we do: first time -> corresponding event 
    for (const auto& ttime : times) {
      bool is_nu = ttime.tag == 1;

      TTree* in_tree = is_nu ? edep_evts_1 : edep_evts_2;
      TTree* gn_tree = is_nu ? genie_evts_1 : genie_evts_2;

      int& evt_it = is_nu ? evt_it_1 : evt_it_2;

      in_tree->GetEntry(ttime.evId);
      gn_tree->GetEntry(ttime.evId);

      TG4Event* edep_evt = is_nu ? edep_evt_1 : edep_evt_2;
      // out_branch->ResetAddress();
      out_branch->SetAddress(&edep_evt); // why the &? what is meaning of life
      // new_tree->SetBranchAddress("Event", &edep_evt);

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

      gRooTracker& genie_evts_data = is_nu ? genie_evts_1_data : genie_evts_2_data;
      genie_tree_data.CopyFrom(genie_evts_data);
      genie_tree_data.EvtNum = edep_evt->EventId;
      genie_tree_data.EvtVtx[3] = event_time;

      int nPrimaryPartThisEvent = 0;
      for (auto &v : edep_evt->Primaries)
        nPrimaryPartThisEvent += v.Particles.size();
      int nTrajectoriesThisEvent = edep_evt->Trajectories.size();
      int nSecondaryPartThisEvent = nTrajectoriesThisEvent - nPrimaryPartThisEvent;

      auto updateTrackId = [lastPriTrajId, lastSecTrajId, nPrimaryPartThisEvent](int &trkId)
      { trkId = trkId < nPrimaryPartThisEvent ? lastPriTrajId + trkId : lastSecTrajId + trkId - nPrimaryPartThisEvent; };

      // ... interaction vertex
      for (std::vector<TG4PrimaryVertex>::iterator v = edep_evt->Primaries.begin(); v != edep_evt->Primaries.end(); ++v) {
        old_event_time = v->Position.T();
        v->Position.SetT(event_time);
        // TMS reco wants the InteractionNumber to be the entry number of the
        // vertex in DetSimPassThru/gRooTracker. Since, by construction, our
        // EDepSimEvents and gRooTracker trees are aligned one-to-one, we just
        // trivially set InteractionNumber to be the current entry number.
        // https://github.com/DUNE/2x2_sim/issues/54
        v->InteractionNumber = evt_it_1 + evt_it_2;
        for (auto &p : v->Particles){
          updateTrackId(p.TrackId);
        }
      }

      std::cout << "This event: " << edep_evt->EventId << " of " << Nevts_this_spill << std::endl;
      std::cout << "  - Primary particles: " << nPrimaryPartThisEvent << std::endl;
      std::cout << "  - Secondary particles: " << nSecondaryPartThisEvent << std::endl;
      std::cout << "  - Trajectories      : " << nTrajectoriesThisEvent << std::endl;
      std::cout << "  - Last Pri. Part. Id: " << lastPriTrajId << std::endl;
      std::cout << "  - Last Sec. Part. Id: " << lastSecTrajId << std::endl;

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

  // Pass on the geometry from the nu-det file by default.
  auto inFileForGeom = new TFile(have_nu_det ? inFileName1.c_str() : inFileName2.c_str());
  auto geom = (TGeoManager*) inFileForGeom->Get("EDepSimGeometry");

  outFile->cd();
  geom->Write();
  new_tree->Write();
  event_spill_map->Write("event_spill_map", 1);
  auto p = new TParameter<double>("spillPeriod_s", spillPeriod_s);
  p->Write();
  auto potps = new TParameter<double>("pot_per_spill", is_n_int_mode ? -1 : spillPOT);
  potps->Write();
  const auto inFile1POT_used = N_evts_1 ? (inFile1POT * evt_it_1 / N_evts_1) : 0;
  auto pot1 = new TParameter<double>("pot1", inFile1POT_used);
  pot1->Write();
  const auto inFile2POT_used = N_evts_2 ? (inFile2POT * evt_it_2 / N_evts_2) : 0;
  auto pot2 = new TParameter<double>("pot2", inFile2POT_used);
  pot2->Write();

  outFile->mkdir("DetSimPassThru");
  outFile->cd("DetSimPassThru");
  genie_tree->Write();

  outFile->Close();
  inFileForGeom->Close();
  delete outFile;
}
