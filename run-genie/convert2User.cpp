// #include "TG4Event.h"
#include "gRooTracker.h"
// #include "Dk2Nu.h"

// Beam2UserNuOrigin_dk2nu

std::ostream& operator<<(std::ostream& os, const TLorentzVector& v){
    os << "( " << v.X() << ", " << v.Y() << ", " << v.Z() << ", " << v.T() << ")";
    return os; 
}

void convert2User(std::string ghep_fname){

    bsim::Dk2Nu* dk2nu = nullptr;
    TLorentzVector userNuOrigin;

    std::cout<<"ghep file name: "<<ghep_fname<<std::endl;

    // input GHEP file
    std::unique_ptr<TFile> ghep_file(TFile::Open(ghep_fname.c_str(), "UPDATE"));
    // input tree
    std::unique_ptr<TTree> gtree(ghep_file->Get<TTree>("gtree"));
    gtree->SetBranchAddress("dk2nu", &dk2nu);

    // output tree
    std::unique_ptr<TTree> outTree = std::make_unique<TTree>("tNuOriginUser", "nu Origin User Coordinates");
    outTree->Branch("userNuOrigin", &userNuOrigin);

    double beamNuOriginX;
    double beamNuOriginY;
    double beamNuOriginZ;
    double beamNuOriginT;
    std::vector<TLorentzVector> beamNuOrigins;
    std::vector<TLorentzVector> userNuOrigins;

    std::cout<<"entries: "<<gtree->GetEntries()<<std::endl;


    // **********BEAM-USER TRANSFORMATION************
    // define rotation
    TRotation r;
    double a = -0.101; //[rad]
    TRotation fBeamRot = r.RotateX(a);

    // define fBeamZero
    TVector3 userpos(0.0, 0.05387, 6.66); //[m]
    TVector3 beampos(0, 0, 562.1179); //[m]
    TVector3 beam0 = userpos - fBeamRot*beampos;
    TLorentzVector fBeamZero(beam0, 0);

    // conversion factors
    double fLengthScaleB2U = 1./100.;
    double fLengthTimeB2U = 1./1E9;
    // **********BEAM-USER TRANSFORMATION************


    // extract the info about neutrino origin in beam coordinates
    for (int i = 0; i < gtree->GetEntries(); i++){ 

        gtree->GetEntry(i);
        auto ancestor = dk2nu->ancestor;
        // some are outside the decay pipe (z > 221 m), but they are nu produced by muon decay
        // std::cout<<" z origin in beam coord: "<<nuOriginBeamZ[i]<<std::endl;
        // std::cout<<" t origin in beam coord: "<<nuOriginBeamT[i]<<std::endl;
        beamNuOriginX = ancestor[ancestor.size()-1].startx;
        beamNuOriginY = ancestor[ancestor.size()-1].starty;
        beamNuOriginZ = ancestor[ancestor.size()-1].startz;
        beamNuOriginT = ancestor[ancestor.size()-1].startt;

        TLorentzVector beamNuOrigin(beamNuOriginX, beamNuOriginY, beamNuOriginZ, beamNuOriginT);
        beamNuOrigins.push_back(beamNuOrigin);
        std::cout<<"neutrino origin in beam coord "<<beamNuOrigins[i]<<std::endl;

        // transformation
        userNuOrigin = fLengthScaleB2U*(TLorentzRotation(fBeamRot)*beamNuOrigin) + fBeamZero;
        userNuOrigin.SetT(beamNuOrigin.T()*fLengthTimeB2U);

        std::cout<<" nu origin in user coord "<<userNuOrigin<<std::endl;

        outTree->Fill();
        userNuOrigins.push_back(userNuOrigin);
    }

    outTree->Write();

    // std::cout<<"neutrino origin in beam coord "<<beamNuOrigins[0]<<std::endl;
    // nuOriginUser = fLengthScaleB2U*(TLorentzRotation(fBeamRot)*beamNuOrigins[0]) + fBeamZero;
    // nuOriginUser.SetT(beamNuOrigins[0].T()*fLengthTimeB2U);
    // std::cout<<"neutrino origin in user coord "<<userNuOrigins<<std::endl;

    
    // check
    // double const c = 29.9792458; // cm/ns
    // double time = 56211.79/c; // ns
    // TLorentzVector NDHallBeam(0, 0, 56211.79, time);
    // TLorentzVector NDHallUser;
    // std::cout<<"NDHallBeam "<<NDHallBeam<<std::endl;
    // NDHallUser = fLengthScaleB2U*(TLorentzRotation(fBeamRot)*NDHallBeam) + fBeamZero;
    // NDHallUser.SetT(NDHallBeam.T()*fLengthTimeB2U);
    // std::cout<<"NDHallUser "<<NDHallUser<<std::endl;
    
}