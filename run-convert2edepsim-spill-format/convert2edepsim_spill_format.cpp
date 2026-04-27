#include "TG4Event.h"

// ROOT macro meant to take in input edep-sim files organized as 1 single nu interaction per entry
// and convert them into edep-sim files organized as spills. 
// The TrackId assignment is changed following the edep-sim convention: 
//  - first all primaries, and all the primaries trajectories; then the secondaries, and the secondaries trajectories. 
//  - TrackIds always increase, i.e. 1st entry 0, 1, 2; 2nd entry 3, 4, 5, etc.

void convert2edepsim_spill_format(std::string const& inFileName, std::string const& outFileName, int runOffset){

    TG4Event* edep_evt = nullptr;
    TG4Event* spill = nullptr;

    // input files and geometry
    std::unique_ptr<TFile> inFile(TFile::Open(inFileName.c_str()));
    std::unique_ptr<TTree> edep_tree(inFile->Get<TTree>("EDepSimEvents"));
    edep_tree->SetBranchAddress("Event", &edep_evt);
    std::unique_ptr<TTree> in_genie_tree(inFile->Get<TTree>("DetSimPassThru/gRooTracker"));
    auto geom = (TGeoManager*) inFile->Get("EDepSimGeometry");

    // output files (GENIE tree is just a copy of the input)
    std::unique_ptr<TFile> outFile(TFile::Open(outFileName.c_str(), "RECREATE"));
    auto outTree = edep_tree->CloneTree(0);
    outTree->SetBranchAddress("Event", &spill);
    TTree* out_genie_tree = nullptr;
    if (in_genie_tree) {
        outFile->cd();
        out_genie_tree = in_genie_tree->CloneTree(-1, "fast");
    }
    
    TMap* input_map = (TMap*)inFile->Get("event_spill_map");

    // create a map to match the eventIds with the corresponding spillId
    std::map<int, std::vector<int>> spill_event_map;

    // loop over the entries to read the spillId from the TMap
    for (int i = 0; i < edep_tree->GetEntries(); i++){ 

        edep_tree->GetEntry(i);

        // take the map and get the spillId
        std::string event_string = std::to_string(edep_evt->RunId) + " "
        + std::to_string(edep_evt->EventId); 
        TObjString event_tobj(event_string.c_str());

        auto spillId_obj = input_map->GetValue(&event_tobj);
        if (!spillId_obj){
            std::cerr << "Warning: No spill ID found for event " << event_string << std::endl;
            continue;
        }

        auto* spillIdStr = dynamic_cast<TObjString*>(spillId_obj);
        if (!spillIdStr) {
            std::cerr << "Error: Invalid spill ID object for event " << event_string << std::endl;
            continue;
        }

        auto spillId = std::atoi(spillIdStr->GetString());

        // fill the map assigning the eventIds to the corresponding spillId
        spill_event_map[spillId].push_back(edep_evt->EventId);
    }

    // useful to keep track of the number of the entry 
    // I need from the edep_tree
    int entry = 0;

    // loop over the map: for each spillId I loop over all the events
    for (auto &pair : spill_event_map){
        auto spillId = pair.first;
        auto eventIds = pair.second;

        int nPrimaryPart = 0;
        int nTrajectories = 0;
        inFile->cd();
        for (int i = 0; i < eventIds.size(); i++){
            edep_tree->GetEntry(entry + i);
            // here (and afterwards) we assume there is just one primary
            assert(edep_evt->Primaries.size() != 0u && "Multiple interaction vertices in the same event not supported!!");

            auto v = edep_evt->Primaries[0];
            nPrimaryPart += v.Particles.size();
            nTrajectories += edep_evt->Trajectories.size();
        }

        int lastPriTrajId = 0;
        int lastSecTrajId = nPrimaryPart;

        spill = new TG4Event();

        std::map<std::string, std::vector<TG4HitSegment>> SegmentDetectors;

        // loop over each event in a single spill
        for (size_t i = 0; i < eventIds.size(); i++){
            edep_tree->GetEntry(entry + i);
            spill->RunId = (edep_evt->RunId) % runOffset;
            spill->EventId = spillId;

            // count the number of primaries, secondaries and trajectories
            int nPrimaryPartThisEvent = 0;
            nPrimaryPartThisEvent += edep_evt->Primaries[0].Particles.size();
            int nTrajectoriesThisEvent = edep_evt->Trajectories.size();
            int nSecondaryPartThisEvent = nTrajectoriesThisEvent - nPrimaryPartThisEvent;

            // function to update the TrackId as explained in the point (3) at the beginning
            auto updateTrackId = [lastPriTrajId, lastSecTrajId, nPrimaryPartThisEvent](int &trkId)
            { trkId = trkId < nPrimaryPartThisEvent ? lastPriTrajId + trkId : lastSecTrajId + trkId - nPrimaryPartThisEvent; };

            // interaction vertex
            if (!edep_evt->Primaries.empty()){
                auto& v = edep_evt->Primaries[0];
                spill->Primaries.push_back(v);
                // for (auto &p : spill->Primaries[i].Particles){
                //     updateTrackId(p.TrackId);
                // }
            }

            // trajectories
            for (auto &t : edep_evt->Trajectories){
                spill->Trajectories.push_back(t);
                //updateTrackId(spill->Trajectories.back().TrackId);
                if (spill->Trajectories.back().ParentId != -1){
                  //  updateTrackId(spill->Trajectories.back().ParentId);
                }
            }

            // energy depositions
            for (auto &d : edep_evt->SegmentDetectors){
                for (auto &h : d.second){
                    SegmentDetectors[d.first].push_back(h);
                    //updateTrackId(SegmentDetectors[d.first].back().PrimaryId);
                    for (auto &trkId : SegmentDetectors[d.first].back().Contrib){
                      //  updateTrackId(trkId);
                    }
                }
            }
            
            lastPriTrajId += nPrimaryPartThisEvent;
            lastSecTrajId += nSecondaryPartThisEvent;
    }// end loop over events of the same spillId
    entry += eventIds.size();
    spill->SegmentDetectors = std::vector<std::pair<std::string, std::vector<TG4HitSegment>>>(SegmentDetectors.begin(), SegmentDetectors.end());
    outTree->Fill();
    delete spill;
    }// end loop over spills

    outFile->cd();
    outTree->Write();
    geom->Write();

    outFile->mkdir("DetSimPassThru");
    outFile->cd("DetSimPassThru");
    if (out_genie_tree){
        out_genie_tree->Write();
    }

    outFile->Close();
}