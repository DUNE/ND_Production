#include "TG4Event.h"
#include "gRooTracker.h"


void convertEvtToSpill(std::string inFileName, std::string outFileName){

    TG4Event* edep_evt = nullptr;
    TG4Event* spill = nullptr;

    // input file
    std::unique_ptr<TFile> inFile(TFile::Open(inFileName.c_str()));
    // input tree
    std::unique_ptr<TTree> edep_tree(inFile->Get<TTree>("EDepSimEvents"));
    edep_tree->SetBranchAddress("Event", &edep_evt);
    // input geom
    auto geom = (TGeoManager*) inFile->Get("EDepSimGeometry");

    // output file
    std::unique_ptr<TFile> outFile(TFile::Open(outFileName.c_str(), "RECREATE"));
    // output tree
    auto outTree = edep_tree->CloneTree(0);
    outTree->SetBranchAddress("Event", &spill);
    
    // import the TMap created in run-spill-build
    TMap* input_map = (TMap*)inFile->Get("event_spill_map");

    // create a map to match the eventIds with the corresponding spillId
    std::map<int, std::vector<int>> spill_event_map;

    // loop over the entries to read the spillId from the TMap
    for (int i = 0; i < edep_tree->GetEntries(); i++){ 

        edep_tree->GetEntry(i);

        // take the map and get the spillId
        std::string event_string = std::to_string(edep_evt->RunId) + " "
        + std::to_string(edep_evt->EventId); 
        TObjString* event_tobj = new TObjString(event_string.c_str());

        auto spillId_obj = input_map->GetValue(event_tobj);
        auto* spillIdStr = dynamic_cast<TObjString*>(spillId_obj);
        auto spillId = std::atoi(spillIdStr->GetString());

        // fill the map assigning the eventIds to the corresponding spillId
        spill_event_map[spillId].push_back(edep_evt->EventId);
  
    }

    // useful to keep track of the number of the entry I have to take from the edep_tree
    int entry = 0;

    // loop over the map: for each spillId I loop over all the events
    for (auto &pair : spill_event_map){
        auto spillId = pair.first;
        auto eventIds = pair.second;
        std::cout<<"spillId: "<<spillId<<std::endl;

        spill = new TG4Event();

        std::map<std::string, std::vector<TG4HitSegment>> SegmentDetectors;

        // loop over each event in a single spill
        for (int i = 0; i < eventIds.size(); i++){
            std::cout<<"evId: "<<eventIds[i]<<std::endl;
            edep_tree->GetEntry(entry + i);
            spill->RunId = edep_evt->RunId;
            spill->EventId = spillId;

            // interaction vertex
            auto& v = edep_evt->Primaries[0];
            spill->Primaries.push_back(v);

            // trajectories
            for (auto &t : edep_evt->Trajectories){
                spill->Trajectories.push_back(t);
            }

            // energy depositions
            for (auto &d : edep_evt->SegmentDetectors){
                for (auto &h : d.second){
                    SegmentDetectors[d.first].push_back(h);
                }
            }
        }// end loop over events of the same spillId
    entry += eventIds.size();
    spill->SegmentDetectors = std::vector<std::pair<std::string, std::vector<TG4HitSegment>>>(SegmentDetectors.begin(), SegmentDetectors.end());
    outTree->Fill();
    delete spill;
    }// end loop over spills

    outFile->cd();
    outTree->Write();
    geom->Write();

    outFile->Close();

}

/****************************************************************/

void takeInitialSpillTime(std::string inFileName){

    TG4Event* spill = nullptr;
    double t0_spill;

    // input file (which is the output of the previous function) - .OVERLAY.root
    std::unique_ptr<TFile> inFile(TFile::Open(inFileName.c_str(), "UPDATE"));
    // input tree
    std::unique_ptr<TTree> spill_tree(inFile->Get<TTree>("EDepSimEvents"));
    spill_tree->SetBranchAddress("Event", &spill);

    // output tree
    std::unique_ptr<TTree> outTree = std::make_unique<TTree>("tSpillTime", "Initial Spill Time");
    outTree->Branch("t0_spill", &t0_spill);

    int spillN = spill_tree->GetEntries();
    std::cout<<" number of spills: "<<spillN<<std::endl;

    std::ofstream ofs("t0_spill.txt");

    // I need to store the spill initial time
    for (int i = 0; i < spill_tree->GetEntries(); i++){
        spill_tree->GetEntry(i);

        // if (ofs.is_open()){
        //     ofs << "spill "<<i<<" initial time: "<<std::fixed << std::setprecision(1) << spill->Primaries[0].Position.T()<<std::endl;
        // }

        // if (i == 0) t0_spill = 0.;
        // else t0_spill = spill->Primaries[0].Position.T();

        t0_spill = i*1.2E9;
        std::cout<<t0_spill<<std::endl;

        outTree->Fill();
    }

    outTree->Write();
}

void convert4sandreco(std::string inFileName, std::string outFileName){
    
    convertEvtToSpill(inFileName, outFileName);
    takeInitialSpillTime(outFileName);

}

