#include "TG4Event.h"
#include "gRooTracker.h"

//std::string inFileName = "sand-events.0000000.EDEPSIM_SPILLS.root";



void convertEvtToSpillBased2(std::string inFileName, std::string outFileName){

    TG4Event* edep_evt = nullptr;
    TG4Event* spill = nullptr;

    // input file
    std::unique_ptr<TFile> inFile(TFile::Open(inFileName.c_str()));
    // input tree
    std::unique_ptr<TTree> edep_tree(inFile->Get<TTree>("EDepSimEvents"));
    // // input RDF
    // ROOT::RDataFrame edep_df("EDepSimEvents", inFileName.c_str());
    edep_tree->SetBranchAddress("Event", &edep_evt);

    // output file
    std::unique_ptr<TFile> outFile(TFile::Open(outFileName.c_str(), "RECREATE"));
    // output tree
    auto outTree = edep_tree->CloneTree(0);
    outTree->SetBranchAddress("Event", &spill);
    // // output RDF
    // ROOT::RDataFrame out_df("EDepSimEvents", outFileName.c_str());
    
    TMap* input_map = (TMap*)inFile->Get("event_spill_map");

    std::map<int, std::vector<int>> spill_event_map;

    for (int i = 0; i < edep_tree->GetEntries(); i++){ 

        edep_tree->GetEntry(i);

        // take the map and get the spillId
        std::string event_string = std::to_string(edep_evt->RunId) + " "
        + std::to_string(edep_evt->EventId); 
        TObjString* event_tobj = new TObjString(event_string.c_str());

        auto spillId_obj = input_map->GetValue(event_tobj);
        auto* spillIdStr = dynamic_cast<TObjString*>(spillId_obj);
        auto spillId = std::atoi(spillIdStr->GetString());

        // ofstream myfile2;
        // myfile2.open("event_list.txt", std::ios::app);
        // myfile2<<"runId "<<edep_evt->RunId<<std::endl;
        // myfile2<<"eventId "<<edep_evt->EventId<<std::endl;
        // myfile2<<"spillId "<<spillIdStr->GetString()<<std::endl;

        spill_event_map[spillId].push_back(edep_evt->EventId);

        // ofstream myfile;
        // myfile.open("spill_list.txt", std::ios::app);
        // myfile<<"runId "<<edep_evt->RunId<<std::endl;
        // myfile<<"eventId "<<edep_evt->EventId<<std::endl;
        // myfile<<"spillId "<<spillId<<std::endl;
  
    }

    // ofstream myfile3;
    // myfile3.open("spill_event_map.txt", std::ios::app);
    // for (int spillId = 0; spillId < 199; spillId++){
    //     myfile3<<"spillId "<<spillId<<std::endl;
    //     myfile3<<"eventIds ";
    //     for (auto spillId : spill_event_map.at(spillId)){
    //         myfile3<<spillId<<" ";
    //     }
    //     myfile3<<'\n';
    // }

    for (auto &pair : spill_event_map){
        auto spillId = pair.first;
        auto eventIds = pair.second;

        spill = new TG4Event();

        for (auto &evId : eventIds){
            edep_tree->GetEntry(evId);
            spill->RunId = edep_evt->RunId;
            spill->EventId = spillId;
        }
    outTree->Fill();
    delete spill;
    }
    outFile->cd();
    outTree->Write();
}

    // TIterator* it = event_spill_map.MakeIterator();
    // TObject* event_tobj;
    // while ((event_tobj = it->Next())) {
    //     TObject* spillId = event_spill_map.GetValue(event_tobj)
    // }


