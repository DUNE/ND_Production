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

long double c = 0.299792458; // [m/ns]
long double conversionTo_ns = 1.E9; 

// overload << for vectors
template <typename T>
std::ostream& operator<<(std::ostream& os, std::vector<T> const& c)
{
  os << "{ ";
  std::copy(
            std::begin(c),
            std::end(c),
            std::ostream_iterator<T>{os, "\n"}
            );
  os << '}';

  return os;
}

// *************************************READ GHEP FILES************************************************
// We need to read GHEP files, hence we need these two methods
std::string getPath(std::string const& base_dir, std::string const& step, std::string const& ghep_fname, std::string const& ftype, std::string const& ext, int file_id){
  int subdir_num = (file_id / 1000) *1000;
  std::ostringstream oss;
  oss << std::setw(7) << std::setfill('0') << subdir_num;
  std::string subdir = oss.str();

  std::string ftype2 = ftype;
  if (ftype == "DST") ftype2 = "dst";
  else if (ftype == "MLRECO_ANALYSIS") ftype2 = "SPINE";
 
  std::ostringstream oss_fileid;
  oss_fileid << std::setw(7) << std::setfill('0') << file_id;
  std::string fileid_str = oss_fileid.str();

  std::string path = base_dir + "/" + step + "/" + ghep_fname + "/" + ftype + "/" + subdir +
                      "/" + ghep_fname + "." + fileid_str + "." + ftype2 + "." + ext;

  if (!std::ifstream(path)) { // in the original function there is std::filesystem::exists but it doesn't work since this script uses c++14 by default when calling ROOT
      std::cerr << "WHERE THE HECKING HECK IS " << path << std::endl;
      throw std::runtime_error("Path does not exist: " + path);
  }

  return path;
}

std::vector<std::string> getGHEPfiles(std::string const& base_dir,  std::string const& ghep_fname, int const& hadd_factor,  int const& file_id) {
  std::vector<std::string> ghep_files;
  for (int ghep_id = file_id * hadd_factor; ghep_id < (file_id + 1) * hadd_factor; ++ghep_id) {
    std::string path = getPath(base_dir, "run-genie", ghep_fname, "GHEP", "root", ghep_id);
    ghep_files.push_back(path);
  }
  return ghep_files;
}
// ***************************************************************************************************


// *************************************GET NEUTRINO INTERACTION TIME*********************************
// returns a random time for a neutrino interaction to take place within
// a LBNF/NuMI spill, given the beam's micro timing structure
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

long double getNuTOF(const bsim::Ancestor& nu_orig,  double const nu_int[4]){ //const EventRecord& event

  // take the neutrino origin in beam coordinate and convert it to user coordinates
  std::unique_ptr<genie::flux::GDk2NuFlux> flux = std::make_unique<genie::flux::GDk2NuFlux>();  
  //read the GNuMIFlux.xml configuration
  flux->LoadConfig("DUNEND");
  //conversion
  TLorentzVector beamNuOrigin(nu_orig.startx, nu_orig.starty, nu_orig.startz, nu_orig.startt);
  TLorentzVector userNuOrigin(0.,0.,0.,0.);
  flux->Beam2UserPos(beamNuOrigin, userNuOrigin);

  // take the neutrino interaction point (already in user coordinates)
  // TLorentzVector userNuInteraction(event.Vertex()->X(), event.Vertex()->Y(), event.Vertex()->Z(), event.Vertex()->T());
  TLorentzVector userNuInteraction(nu_int[0], nu_int[1], nu_int[2], nu_int[3]);

  // compute the nu tof
  long double distance_x = userNuInteraction.X() - userNuOrigin.X();
  long double distance_y = userNuInteraction.Y() - userNuOrigin.Y();
  long double distance_z = userNuInteraction.Z() - userNuOrigin.Z();
  //TVector3 distance_vector = TVector3(distance_x, distance_y, distance_z);

  long double distance = sqrt(distance_x*distance_x + distance_y*distance_y + distance_z*distance_z);

  std::cout << "Distance " << distance << '\n';

  long double tof = distance / c;

  std::cout << "TOF " << tof << '\n';

  return tof;
}

long double getInteractionTime_LBNF(const bsim::Ancestor& nu_orig, double const nu_int[4]) { 
  std::cout << "Production time: " << getProductionTime_LBNF() << '\n';
  std::cout << "Nu origin time: " << nu_orig.startt << '\n';
  long double nu_tof = getNuTOF(nu_orig, nu_int);
  std::cout << "nu TOF time: " << nu_tof << '\n';
  long double interactionTime = getProductionTime_LBNF() +  static_cast<long double>(nu_orig.startt) + nu_tof;

  return interactionTime;
}
// ******************************************************************************************************

struct TaggedTime {
  long double time;
  int tag;
  int evId;
  TaggedTime(double time, int tag, int evId) :
    time(time), tag(tag), evId(evId) {}
  TaggedTime() : time(0), tag(0), evId(0) {}
};

void overlayWithNuIntTime(std::string inFileName1,
                                    std::string inFileName2,
                                    std::string outFileName,
                                    std::string ghepFileName, // added
                                    int spillFileId,
                                    double inFile1POT = 1.024E19,
                                    double inFile2POT = 1.024E19,
                                    double spillPOT = 5E13,
                                    long double spillPeriod_s = 1.2,
                                    int hadd_factor = 10) { // added

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

  // ************************get input GHEP files***********
  // get base directory from inFileName1
  const char* base_dir = std::getenv("ND_PRODUCTION_OUTDIR_BASE");
  if (base_dir) {
        std::cout << "BASE DIR: " << base_dir << std::endl;
    } else {
        std::cout << "ND_PRODUCTION_OUTDIR_BASE not set!" << std::endl;
    }

  auto ghepFiles = getGHEPfiles(base_dir, ghepFileName, hadd_factor, spillFileId);
  std::cout << "GHEP FILES: " << ghepFiles << '\n';
  std::unique_ptr<TChain> ghep_evts_1 = std::make_unique<TChain>("gtree");
  std::for_each(ghepFiles.begin(), ghepFiles.end(), [&](std::string const& fname){
                                                          ghep_evts_1->Add(fname.c_str());
                                                          });
// **********************************************************

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

  // std::cout << "File: " << inFileName1 << std::endl;
  // std::cout << "    Number of spills: "<< (is_n_int_mode ? 
  //   std::floor((double)N_evts_1/evts_per_spill_1) : inFile1POT/spillPOT) << std::endl;
  // std::cout << "    Events per spill: "<< evts_per_spill_1 << std::endl;

  // std::cout << "File: " << inFileName2 << std::endl;
  // std::cout << "    Number of spills: "<< inFile2POT/spillPOT << std::endl;
  // std::cout << "    Events per spill: "<< evts_per_spill_2 << std::endl;

  std::ofstream ofs("spills_info.txt");
  if (ofs.is_open()){
    ofs << "File: " << inFileName1 << std::endl;
    ofs << "    Number of spills: "<< (is_n_int_mode ? 
      std::floor((double)N_evts_1/evts_per_spill_1) : inFile1POT/spillPOT) << std::endl;
    ofs << "    Events per spill: "<< evts_per_spill_1 << std::endl;

    ofs << "File: " << inFileName2 << std::endl;
    ofs << "    Number of spills: "<< inFile2POT/spillPOT << std::endl;
    ofs << "    Events per spill: "<< evts_per_spill_2 << std::endl;
  }

  // **********get dk2nu branch******
  bsim::Dk2Nu* dk2nu_evt_1 = nullptr;
  ghep_evts_1->SetBranchAddress("dk2nu",&dk2nu_evt_1);
  // ********************************

  TG4Event* edep_evt_1 = NULL;
  if(have_nu_lar) edep_evts_1->SetBranchAddress("Event",&edep_evt_1);

  TG4Event* edep_evt_2 = NULL;
  if(have_nu_rock) edep_evts_2->SetBranchAddress("Event",&edep_evt_2);

  TMap* event_spill_map = new TMap(N_evts_1+N_evts_2);

  int evt_it_1 = 0;
  int evt_it_2 = 0;

  for (int spillN = 0; ; ++spillN) {
    std::cout << "SPILL N " << spillN << '\n';
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
    std::vector<TaggedTime> times(Nevts_this_spill);

    // loop on the events within a spill, to take into account also the neutrino TOF before reaching SAND:
    // so for each event I need to get the interaction position (z coordinate) and compute the interaction time
    // fill a vector with these times, and then sorted
    int nPrimaryPart = 0;
    int nTrajectories = 0;
    for (int i = 0; i < Nevts_this_spill; ++i){
      std::cout << "EVENT " << i << '\n';
      bool is_fidvol = i < Nevts_this_spill_1;
      int& evt_it = is_fidvol ? evt_it_1 : evt_it_2;

      TTree* in_tree = is_fidvol ? edep_evts_1 : edep_evts_2;
      TTree* gn_tree = is_fidvol ? genie_evts_1 : genie_evts_2;
      // std::unique_ptr<TTree> ghep_tree;
      // std::swap(&ghep_tree, &ghep_evts_1);
      in_tree->GetEntry(evt_it + i);
      gn_tree->GetEntry(evt_it + i);
      ghep_evts_1->GetEntry(evt_it + i);

      // 
      bsim::Dk2Nu* dk2nu_evt = dk2nu_evt_1;
      gRooTracker genie_data(gn_tree);
      TG4Event* edep_evt = is_fidvol ? edep_evt_1 : edep_evt_2;

      // I am considering just 1 primary vertex!!
      assert(edep_evt->Primaries.size() != 0u && "Multiple interaction vertices in the same event not supported!!");

      auto ancestor = dk2nu_evt->ancestor;
      auto vertex = genie_data.EvtVtx;
      times[i] = TaggedTime(getInteractionTime_LBNF(ancestor[ancestor.size()-1], vertex), 1, evt_it + i);
      std::cout<< "time " << times[i].time <<'\n';
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

      std::cout<<"evt_it: "<<evt_it<<std::endl;

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

      // ... interaction vertex
      for (std::vector<TG4PrimaryVertex>::iterator v = edep_evt->Primaries.begin(); v != edep_evt->Primaries.end(); ++v) {
        //v->Position.T() = event_time;
        old_event_time = v->Position.T();
        //std::cout<<"OLD EV TIME: "<<old_event_time<<std::endl;
        //std::cout<<"NEW EV TIME: "<<event_time<<std::endl;
        v->Position.SetT(event_time);
        // TMS reco wants the InteractionNumber to be the entry number of the
        // vertex in DetSimPassThru/gRooTracker. Since, by construction, our
        // EDepSimEvents and gRooTracker trees are aligned one-to-one, we just
        // trivially set InteractionNumber to be the current entry number.
        // https://github.com/DUNE/2x2_sim/issues/54
        v->InteractionNumber = evt_it_1 + evt_it_2;
      }

      //std::cout<<"EVENT: "<<edep_evt->EventId<<std::endl;
      //std::cout<<"TIME: "<<edep_evt->Primaries[0].Position.T()<<std::endl;

      // ... trajectories
      int tr = 0;
      for (std::vector<TG4Trajectory>::iterator t = edep_evt->Trajectories.begin(); t != edep_evt->Trajectories.end(); ++t) {
        //std::cout<<"loop trj number "<<tr<<std::endl;
        // loop over all points in the trajectory
        int pt = 0;
        for (std::vector<TG4TrajectoryPoint>::iterator p = t->Points.begin(); p != t->Points.end(); ++p) {
          //std::cout<<"loop points number "<<pt<<std::endl;
          double offset = p->Position.T() - old_event_time;
          //std::cout<<"Position.T() "<<p->Position.T()<<std::endl;
          //std::cout<<"old_event_time "<<old_event_time<<std::endl;
          //std::cout<<"OFFSET: "<<offset<<std::endl;
          p->Position.SetT(event_time + offset);
          // std::cout<<"NEW POS TIME "<<p->Position.T()<<std::endl;
          pt++;
        }
        tr++;
      }

      // ... and, finally, energy depositions
      for (auto d = edep_evt->SegmentDetectors.begin(); d != edep_evt->SegmentDetectors.end(); ++d) {
        for (std::vector<TG4HitSegment>::iterator h = d->second.begin(); h != d->second.end(); ++h) {
          double start_offset = h->Start.T() - old_event_time;
          double stop_offset = h->Stop.T() - old_event_time;
          h->Start.SetT(event_time + start_offset);
          h->Stop.SetT(event_time + stop_offset);
        }
      }

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
