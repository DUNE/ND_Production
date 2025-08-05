#include "TG4Event.h"
#include "gRooTracker.h"


// A root macro to overlay single neutrino interactions, usually of special 
// interest (nu-on-e for example), into existing nominal spills. It takes an 
// output file from the nomimal spill building step (overlaySinglesIntoSpillsSorted.C) 
// and an output file from raw edep-sim with single neutrino interactions.


// returns a random time for a neutrino interaction to take place within
// a LBNF/NuMI spill, given the beam's micro timing structure
double getInteractionTime_LBNF() {

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


struct TaggedTime {
  double time;
  int tag;
  TaggedTime(double time, int tag) :
    time(time), tag(tag) {}
  TaggedTime() : time(0), tag(0) {}
};


void overlaySinglesIntoExistingSpillsSorted(std::string inFileNameSpills,
                                            std::string inFileNameSingles,
                                            std::string outFileName,
                                            unsigned int n_singles_overlaid_per_spill = 1) {

  // Maximum number of single interactions that can be added to
  // one spill. Choice of this number here is somewhat arbitrary.
  unsigned int n_singles_overlaid_per_spill_max = 10;


  // Grab "non-tree" info from spill file to put directly in the new out file.
  auto inFileSpills = new TFile(inFileNameSpills.c_str());
  auto geom = (TGeoManager*) inFileSpills->Get("EDepSimGeometry");
  auto sp = (TParameter<double>*) inFileSpills->Get("spillPeriod_s");
  auto event_spill_map = (TMap*) inFileSpills->Get("event_spill_map");
  auto potps = (TParameter<double>*) inFileSpills->Get("pot_per_spill");
  auto pot1 = (TParameter<double>*) inFileSpills->Get("pot1");
  auto pot2 = (TParameter<double>*) inFileSpills->Get("pot2");
  inFileSpills->Close();

  // Lift all other information from spill file.
  TChain* edep_evts_1 = new TChain("EDepSimEvents");
  TChain* genie_evts_1 = new TChain("DetSimPassThru/gRooTracker");
  edep_evts_1->Add(inFileNameSpills.c_str());
  genie_evts_1->Add(inFileNameSpills.c_str());

  gRooTracker genie_evts_1_data(genie_evts_1);

  // Get input from singles file.
  TChain* edep_evts_2 = new TChain("EDepSimEvents");
  TChain* genie_evts_2 = new TChain("DetSimPassThru/gRooTracker");
  edep_evts_2->Add(inFileNameSingles.c_str());
  genie_evts_2->Add(inFileNameSingles.c_str());

  gRooTracker genie_evts_2_data(genie_evts_2);

  // Make output file and write what we can immediately.
  TFile* outFile = new TFile(outFileName.c_str(),"RECREATE");
  outFile->cd();
  sp->Write();
  geom->Write(); delete geom;
  potps->Write(); delete potps;
  pot1->Write(); delete pot1;
  pot2->Write(); delete pot2;


  // Set up output trees.
  TTree* new_tree;
  TTree* genie_tree;
  new_tree = edep_evts_1->CloneTree();
  genie_tree = genie_evts_1->CloneTree();

  gRooTracker genie_tree_data(genie_tree);
  TBranch* out_branch = new_tree->GetBranch("Event");


  // Get a list of unique spill IDs.
  std::set<std::string> spill_ids;
  TObject *key = 0;
  TMapIter it_esm(event_spill_map);
  while((key = it_esm.Next())) {
    spill_ids.insert((std::string)(((TObjString*)event_spill_map->GetValue(key))->GetString()));
  }
  unsigned int n_spills = spill_ids.size();

  // Determine the number of singles in the singles file.
  unsigned int n_singles = edep_evts_2->GetEntries();
  if (n_spills*n_singles_overlaid_per_spill > n_singles) {
    std::cerr << "[ERROR] there are not enough singles to overlay into all spills in the spill file" << std::endl;
    throw;
  }
  unsigned int N_evts_2 = 0;

  std::cout << "File: " << inFileNameSpills << std::endl;
  std::cout << "    Number of spills: "<< n_spills << std::endl; 

  std::cout << "File: " << inFileNameSingles << std::endl;
  std::cout << "    Number of singles: "<< n_singles << std::endl;

  std::cout << "That's enough singles to overlay the requested " << n_singles_overlaid_per_spill << " singles per spill!" << std::endl;


  TG4Event* edep_evt_1 = NULL;
  edep_evts_1->SetBranchAddress("Event",&edep_evt_1);

  TG4Event* edep_evt_2 = NULL;
  edep_evts_2->SetBranchAddress("Event",&edep_evt_2);


  unsigned int single = 0;
  unsigned int spill = 0;
  unsigned int n_evts_1 = edep_evts_1->GetEntries();
  for (std::string spill_id : spill_ids) {

    std::cout << "working on spill ID " << spill_id << std::endl;

    std::vector<TaggedTime> times(n_singles_overlaid_per_spill);
    std::generate(times.begin(),
                  times.begin() + n_singles_overlaid_per_spill,
                  []() { return TaggedTime(getInteractionTime_LBNF(), 3); });
    std::sort(times.begin(),
              times.end(),
              [](const auto& lhs, const auto& rhs) { return lhs.time < rhs.time; });

    for (const auto& ttime : times) {

      edep_evts_2->GetEntry(single);
      genie_evts_2->GetEntry(single);

      out_branch->SetAddress(&edep_evt_2);

      std::string event_string = std::to_string(edep_evt_2->RunId) + " "
        + std::to_string(edep_evt_2->EventId);
      std::string spill_string = spill_id;
      TObjString* event_tobj = new TObjString(event_string.c_str());
      TObjString* spill_tobj = new TObjString(spill_string.c_str());

      if (event_spill_map->FindObject(event_string.c_str()) == 0)
        event_spill_map->Add(event_tobj, spill_tobj);
      else {
        std::cerr << "[ERROR] redundant event ID " << event_string.c_str() << std::endl;
        std::cerr << "event_spill_map entries = " << event_spill_map->GetEntries() << std::endl;
        throw;
      }

      double event_time = ttime.time + 1e9*sp->GetVal()*spill;
      double old_event_time = 0.;

      genie_tree_data.CopyFrom(genie_evts_2_data);
      genie_tree_data.EvtNum = edep_evt_2->EventId;
      genie_tree_data.EvtVtx[3] = event_time;

      // ... interaction vertex
      for (std::vector<TG4PrimaryVertex>::iterator v = edep_evt_2->Primaries.begin(); v != edep_evt_2->Primaries.end(); ++v) {
        old_event_time = v->Position.T();
        v->Position.SetT(event_time);
        v->InteractionNumber = n_evts_1 + single;
      }

      // ... trajectories
      for (std::vector<TG4Trajectory>::iterator t = edep_evt_2->Trajectories.begin(); t != edep_evt_2->Trajectories.end(); ++t) {
        // loop over all points in the trajectory
        for (std::vector<TG4TrajectoryPoint>::iterator p = t->Points.begin(); p != t->Points.end(); ++p) {
          double offset = p->Position.T() - old_event_time;
          p->Position.SetT(event_time + offset);
        }
      }

      // ... and, finally, energy depositions
      for (auto d = edep_evt_2->SegmentDetectors.begin(); d != edep_evt_2->SegmentDetectors.end(); ++d) {
        for (std::vector<TG4HitSegment>::iterator h = d->second.begin(); h != d->second.end(); ++h) {
          double start_offset = h->Start.T() - old_event_time;
          double stop_offset = h->Stop.T() - old_event_time;
          h->Start.SetT(event_time + start_offset);
          h->Stop.SetT(event_time + stop_offset);
        }
      }

      new_tree->Fill();
      genie_tree->Fill();
      single++;
    } // loop over singles in spill
    spill++;
  } // loop over spills


  // Write everything that's left and clean up.
  new_tree->SetName("EDepSimEvents");
  genie_tree->SetName("gRooTracker");

  outFile->cd();
  new_tree->Write();
  event_spill_map->Write("event_spill_map", 1);

  outFile->mkdir("DetSimPassThru");
  outFile->cd("DetSimPassThru");
  genie_tree->Write();

  outFile->Close();

  delete outFile;
}
