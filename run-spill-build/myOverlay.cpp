// 16/06/2025
// this macro is a copy of overlaySinglesIntoSpillsSorted.C, with the following modifications:
// - Added neutrino TOF with the function getInteractionTime_LBNF. But this computation is just a first order approximation, it needs to be improved
// - The output structure follows the edep-sim convention, i.e., first come all primary trajectories, then secondaries ones.

#include "TG4Event.h"
#include "gRooTracker.h"

// Simple root macro meant to take in an output file from edep-sim
// containing single neutrino interactions (from some flux) in the
// event tree and overlay these events into full spills.
//
// The macro can build LAr only spills (setting inFile2POT to 0),
// rock only spills (setting inFile1POT to 0) or LAr + rock spills
// (setting both inFile1POT and inFile2POT to be greater than 0).
//
// When building LAr only spills one can run in "N Interaction" mode
// by specifying a number less than or equal to 10000 as spillPOT. Useful,
// for example, for studying single neutrino spills.
//
// The output will have two changes with respect to the input:
//
//   (1) The EventId for rock events starts from -1 and counts backward.
//
//   (2) The timing information is edited to impose the timing microstructure of
//       the numi/lbnf beamline, as well as the "macrostructure" (spill period).

const double nuSpeed = 299.792458; // mm/ns

// returns a random time for a neutrino interaction to take place within
// a LBNF/NuMI spill, given the beam's micro timing structure
// this is the time of neutrino production
double getProductionTime_LBNF() {

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

// this is the time of neutrino interaction with the detector
// Z_coord is taken from GENIE and it's in detector coordinates, where 0 corresponds to the start of ND
double getInteractionTime_LBNF(TG4Event const& event) {

  auto v = event.Primaries[0];
  double z_coord = v.Position.Z();

  return getProductionTime_LBNF() + z_coord / nuSpeed;
  
}


struct TaggedTime {
  double time;
  int tag;
  int evId;
  TaggedTime(double time, int tag, int evId) :
    time(time), tag(tag), evId(evId) {}
  TaggedTime() : time(0), tag(0), evId(0) {}
};

void myOverlay(std::string inFileName1,
                                    std::string inFileName2,
                                    std::string outFileName,
                                    int spillFileId,
                                    double inFile1POT = 1.024E19,
                                    double inFile2POT = 1.024E19,
                                    double spillPOT = 7.5E15,
                                    double spillPeriod_s = 1.2) {

  // Maximum number of interactions that can be simulated in
  // one spill in "N Interaction" mode. Choice of this number
  // here is somewhat arbitrary, seemed like a very safe
  // upper limit on the number of nu-LAr events we'd want to 
  // simulate ever in a single spill (for stress testing).
  int n_int_max = 10000;
  // Check that we are considering, nu-LAr only, nu-rock only or both.
  if (inFile1POT==0. && inFile2POT==0.) {
    throw std::invalid_argument("nu-LAr POT and nu-rock POT cannot both be zero!");
  }
  // "N Interaction" mode only supported in nu-LAr mode.
  else if (spillPOT <= (double)n_int_max && inFile2POT>0.) {
    throw std::invalid_argument("N Interaction mode does not support nu-rock POT input");
  }

  // Useful bools for keeping track of event types being considered.
  bool have_nu_lar = false;
  bool have_nu_rock = false;
  bool is_n_int_mode = false;

  // get input nu-LAr files
  TChain* edep_evts_1 = new TChain("EDepSimEvents");
  TChain* genie_evts_1 = new TChain("DetSimPassThru/gRooTracker");
  if(inFile1POT > 0.) {
    edep_evts_1->Add(inFileName1.c_str());
    genie_evts_1->Add(inFileName1.c_str());
    have_nu_lar = true;
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
  if(have_nu_lar && !have_nu_rock){
    std::cout << "nu-rock file POT stated to be zero, spills will be LAr only" << std::endl;
    if(is_n_int_mode) {
      std::cout << "Running in N Interaction mode with " << spillPOT << " interactions per spill" << std::endl;
    }
  }
  else if(!have_nu_lar && have_nu_rock){
    std::cout << "nu-LAr file POT stated to be zero, spills will be rock only" << std::endl;
  }
  else if(have_nu_lar && have_nu_rock){
    std::cout << "nu-LAr and nu-rock file POTs stated to be non-zero, spills will be LAr+rock" << std::endl;
  }

  // make output file
  TFile* outFile = new TFile(outFileName.c_str(),"RECREATE");
  TTree* new_tree;
  TTree* genie_tree;
  if(have_nu_lar) {
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
  if(have_nu_lar) {
    N_evts_1 = edep_evts_1->GetEntries();
    evts_per_spill_1 = ((double)N_evts_1)/(inFile1POT/spillPOT);
    if (is_n_int_mode) {
      evts_per_spill_1 = spillPOT;
    }
  }

  unsigned int N_evts_2 = 0;
  double evts_per_spill_2 = 0.;
  if(have_nu_rock) {
    N_evts_2 = edep_evts_2->GetEntries();
    evts_per_spill_2 = ((double)N_evts_2)/(inFile2POT/spillPOT);
  }

  std::cout << "File: " << inFileName1 << std::endl;
  std::cout << "    Number of spills: "<< (is_n_int_mode ? 
    std::floor((double)N_evts_1/evts_per_spill_1) : inFile1POT/spillPOT) << std::endl;
  std::cout << "    Events per spill: "<< evts_per_spill_1 << std::endl;

  std::cout << "File: " << inFileName2 << std::endl;
  std::cout << "    Number of spills: "<< inFile2POT/spillPOT << std::endl;
  std::cout << "    Events per spill: "<< evts_per_spill_2 << std::endl;

  TG4Event* edep_evt_1 = NULL;
  if(have_nu_lar) edep_evts_1->SetBranchAddress("Event",&edep_evt_1);

  TG4Event* edep_evt_2 = NULL;
  if(have_nu_rock) edep_evts_2->SetBranchAddress("Event",&edep_evt_2);

  TMap* event_spill_map = new TMap(N_evts_1+N_evts_2);

  int evt_it_1 = 0;
  int evt_it_2 = 0;

  // **************************************************************
  // **************************************************************
  // modified from here!!
  for (int spillN = 0; ; ++spillN) {
    int Nevts_this_spill_1 = 0;
    if(have_nu_lar) {
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
    
    std::vector<TaggedTime> times;

    // std::cout<<"nr ev 1 "<<Nevts_this_spill_1<<std::endl;
    // std::cout<<"nr ev 2 "<<Nevts_this_spill_2<<std::endl;

    // loop on the events within a spill, to take into account also the neutrino TOF before reaching SAND:
    // so for each event I need to get the interaction position (z coordinate) and compute the interaction time
    // fill a vector with these times, and then sorted
    int nPrimaryPart = 0;
    int nTrajectories = 0;
    for (int i = 0; i < Nevts_this_spill; i++)
    {
      bool is_fidvol = i < Nevts_this_spill_1;
      int& evt_it = is_fidvol ? evt_it_1 : evt_it_2;

      TTree* in_tree = is_fidvol ? edep_evts_1 : edep_evts_2;
      TTree* gn_tree = is_fidvol ? genie_evts_1 : genie_evts_2;
      in_tree->GetEntry(evt_it + i);
      gn_tree->GetEntry(evt_it + i);

      TG4Event* edep_evt = is_fidvol ? edep_evt_1 : edep_evt_2;

      // I am considering just 1 primary vertex!!
      assert(edep_evt->Primaries.size() != 0u && "Multiple interaction vertices in the same event not supported!!");

      auto v = edep_evt->Primaries[0];
      nPrimaryPart += v.Particles.size();
      // double z_1 = v.Position.Z();
      times.push_back(TaggedTime(getInteractionTime_LBNF(*edep_evt), 1, evt_it + i));
      nTrajectories += edep_evt->Trajectories.size();
    }

    std::sort(times.begin(),
              times.end(),
              [](const auto& lhs, const auto& rhs) { return lhs.time < rhs.time; });

    // for (const auto& ttime : times){
    //   std::cout<<"times ev "<<ttime.time<<" "<<ttime.evId<<std::endl;
    // }

    std::cout << "This spill: " << std::endl;
    std::cout << "  - Primary particle: " << nPrimaryPart << std::endl;
    std::cout << "  - Trajectories    : " << nTrajectories << std::endl;

    int lastPriTrajId = 0;
    int lastSecTrajId = nPrimaryPart;

    // loop on times vector: different from ND-LAr version!
    // they associate first time with first event
    // instead we do: first time -> corresponding event 
    for (const auto& ttime : times) {
      bool is_fidvol = ttime.tag == 1;

      int& evt_it = is_fidvol ? evt_it_1 : evt_it_2;

      TTree* in_tree = is_fidvol ? edep_evts_1 : edep_evts_2;
      TTree* gn_tree = is_fidvol ? genie_evts_1 : genie_evts_2;

      in_tree->GetEntry(ttime.evId);
      gn_tree->GetEntry(ttime.evId);

      TG4Event* edep_evt = is_fidvol ? edep_evt_1 : edep_evt_2;
      // out_branch->ResetAddress();
      out_branch->SetAddress(&edep_evt); // why the &? what is meaning of life
      // new_tree->SetBranchAddress("Event", &edep_evt);

      int globalSpillId = int(1E3)*spillFileId + spillN;

      // this was to have eventId always increasing also among files. But since for different files I have different RunId, it's ok that EventId restarts from 0 for each new file
      // edep_evt->EventId = ttime.evId;

      std::string event_string = std::to_string(edep_evt->RunId) + " "
        + std::to_string(edep_evt->EventId); 
      std::string spill_string = std::to_string(globalSpillId);
      TObjString* event_tobj = new TObjString(event_string.c_str());
      TObjString* spill_tobj = new TObjString(spill_string.c_str());

      // if (ttime.evId != edep_evt->EventId) {
      //   std::cout<<"ttime EVENT ID: "<<ttime.evId<<std::endl;
      //   std::cout<<"edep_evt EVENT ID: "<<edep_evt->EventId<<std::endl;
      // }

      if (event_spill_map->FindObject(event_string.c_str()) == 0)
        event_spill_map->Add(event_tobj, spill_tobj);
      else {
        std::cerr << "[ERROR] redundant event ID " << event_string.c_str() << std::endl;
        std::cerr << "event_spill_map entries = " << event_spill_map->GetEntries() << std::endl;
        throw;
      }

      double event_time = ttime.time + 1e9*spillPeriod_s*spillN;
      double old_event_time = 0.;

      gRooTracker& genie_evts_data = is_fidvol ? genie_evts_1_data : genie_evts_2_data;
      genie_tree_data.CopyFrom(genie_evts_data);
      genie_tree_data.EvtNum = ttime.evId;
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
        //v->Position.T() = event_time;
        old_event_time = v->Position.T();
        v->Position.SetT(event_time);
        // TMS reco wants the InteractionNumber to be the entry number of the
        // vertex in DetSimPassThru/gRooTracker. Since, by construction, our
        // EDepSimEvents and gRooTracker trees are aligned one-to-one, we just
        // trivially set InteractionNumber to be the current entry number.
        // https://github.com/DUNE/2x2_sim/issues/54
        // *****TBD!!!*****
        v->InteractionNumber = evt_it; //evt_it_1 + evt_it_2;
        std::cout<<"Interaction number "<<v->InteractionNumber<<std::endl;
        for (auto &p : v->Particles){
          // std::cout<<"p0 TRACKID pre update: "<<p.TrackId<<std::endl;
          updateTrackId(p.TrackId);
          // std::cout<<"p0 TRACKID post update: "<<p.TrackId<<std::endl;
        }
      }

      std::cout<<"EVENT: "<<edep_evt->EventId<<std::endl;
      printf("TIME: %.2f", edep_evt->Primaries[0].Position.T(), "\n");
      //std::cout<<"TIME: "<<edep_evt->Primaries[0].Position.T()<<std::endl;

      std::cout << "This event: " << edep_evt->EventId << " of " << Nevts_this_spill << std::endl;
      std::cout << "  - Primary particle  : " << nPrimaryPartThisEvent << std::endl;
      std::cout << "  - Secondary particle: " << nSecondaryPartThisEvent << std::endl;
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
        // std::cout<<"t TRACKID pre update: "<<t->TrackId<<std::endl;
        updateTrackId(t->TrackId);
        // std::cout<<"t TRACKID post update: "<<t->TrackId<<std::endl;
        if (t->ParentId != -1){
          // std::cout<<"t PARENTID pre update: "<<t->ParentId<<std::endl;
          updateTrackId(t->ParentId);
          // std::cout<<"t PARENTID post update: "<<t->ParentId<<std::endl;
        }
      }

      // ... and, finally, energy depositions
      for (auto d = edep_evt->SegmentDetectors.begin(); d != edep_evt->SegmentDetectors.end(); ++d) {
        for (std::vector<TG4HitSegment>::iterator h = d->second.begin(); h != d->second.end(); ++h) {
          double start_offset = h->Start.T() - old_event_time;
          double stop_offset = h->Stop.T() - old_event_time;
          h->Start.SetT(event_time + start_offset);
          h->Stop.SetT(event_time + stop_offset);
          // std::cout<<"h PRIMARYID pre update: "<<h->PrimaryId<<std::endl;
          updateTrackId(h->PrimaryId);
          // std::cout<<"h PRIMARYID post update: "<<h->PrimaryId<<std::endl;
          for (auto &trkId : h->Contrib){
            // std::cout<<"h TRACKID pre update: "<<trkId<<std::endl;
            updateTrackId(trkId);
            // std::cout<<"h TRACKID post update: "<<trkId<<std::endl;
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

  // Pass on the geometry from the nu-LAr file by default.
  auto inFileForGeom = new TFile(have_nu_lar ? inFileName1.c_str() : inFileName2.c_str());
  auto geom = (TGeoManager*) inFileForGeom->Get("EDepSimGeometry");

  outFile->cd();
  geom->Write();
  new_tree->Write();
  event_spill_map->Write("event_spill_map", 1);
  auto p = new TParameter<double>("spillPeriod_s", spillPeriod_s);
  p->Write();

  outFile->mkdir("DetSimPassThru");
  outFile->cd("DetSimPassThru");
  genie_tree->Write();

  outFile->Close();
  inFileForGeom->Close();
  delete outFile;
  }
