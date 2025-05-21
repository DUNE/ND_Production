#include "TG4Event.h"
#include "gRooTracker.h"


void convertEvtToSpillBased(std::string inFileName, std::string outFileName){

    TG4Event* edep_evt = nullptr;
    TG4Event* spill = nullptr;

    // input file
    std::unique_ptr<TFile> inFile(TFile::Open(inFileName.c_str()));
    // input tree
    std::unique_ptr<TTree> edep_tree(inFile->Get<TTree>("EDepSimEvents"));
    edep_tree->SetBranchAddress("Event", &edep_evt);

    // output file
    std::unique_ptr<TFile> outFile(TFile::Open(outFileName.c_str(), "RECREATE"));
    // output tree
    auto outTree = edep_tree->CloneTree(0);
    outTree->SetBranchAddress("Event", &spill);
    
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

    // ofstream myfile4;
    // myfile4.open("particles_size.txt", std::ios::app);

    // ofstream myfile5;
    // myfile5.open("points.txt", std::ios::app);

    int entry = 0;

    for (auto &pair : spill_event_map){
        auto spillId = pair.first;
        auto eventIds = pair.second;
        std::cout<<"spillId: "<<spillId<<std::endl;

        spill = new TG4Event();

        std::map<std::string, std::vector<TG4HitSegment>> SegmentDetectors;

        for (int i = 0; i < eventIds.size(); i++){
            std::cout<<"evId: "<<eventIds[i]<<std::endl;
            edep_tree->GetEntry(entry + i);
            spill->RunId = edep_evt->RunId;
            spill->EventId = spillId;

            // interaction vertex
            auto& v = edep_evt->Primaries[0];
            // myfile4<<"evId: "<<eventIds[i]<<" "<<edep_evt->EventId<<std::endl;
            // myfile4<<"edepsim size: "<<edep_evt->Primaries[0].Particles.size()<<std::endl;
            spill->Primaries.push_back(v);
            // myfile4<<"spill nr: "<<spillId<<" "<<"event nr: "<<i<<std::endl;
            // myfile4<<"overlay size: "<<spill->Primaries[i].Particles.size()<<std::endl;

            // trajectories
            // myfile5<<"evId: "<<eventIds[i]<<" "<<edep_evt->EventId<<std::endl;
            // myfile5<<"edepsim size: "<<edep_evt->Trajectories.size()<<std::endl;
            for (auto &t : edep_evt->Trajectories){
                // myfile5<<"edepsim point X: "<<t.Points[0].Position.X()<<std::endl;
                spill->Trajectories.push_back(t);
                // myfile5<<"overlay size: "<<spill->Trajectories[j].Points[0].Position.X()<<std::endl;
            }

            // myfile5<<"spill nr: "<<spillId<<" "<<"event nr: "<<i<<std::endl;
            // for (int j=0; j < spill->Trajectories.size(); j++){
            //     myfile5<<"overlay size: "<<spill->Trajectories[j].Points[0].Position.X()<<std::endl;
            // }

            // energy depositions
            for (auto &d : edep_evt->SegmentDetectors){
                for (auto &h : d.second){
                    SegmentDetectors[d.first].push_back(h);
                }
            }
        }// loop over events of the same spillId
    entry += eventIds.size();
    spill->SegmentDetectors = std::vector<std::pair<std::string, std::vector<TG4HitSegment>>>(SegmentDetectors.begin(), SegmentDetectors.end());
    outTree->Fill();
    delete spill;
    }// loop over spills
    outFile->cd();
    outTree->Write();
}