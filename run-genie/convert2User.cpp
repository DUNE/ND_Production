// #include "TG4Event.h"
#include "gRooTracker.h"
// #include "Dk2Nu.h"

// Beam2UserNuOrigin_dk2nu

std::ostream& operator<<(std::ostream& os, const TLorentzVector& v){
    os << "( " << v.X() << ", " << v.Y() << ", " << v.Z() << ", " << v.T() << ")";
    return os; 
}

TLorentzVector convert2User(std::string ghep_fname){

    bsim::Dk2Nu* dk2nu = nullptr;

    std::cout<<"ghep file name: "<<ghep_fname<<std::endl;

    // input GHEP file
    std::unique_ptr<TFile> ghep_file(TFile::Open(ghep_fname.c_str()));
    // input tree
    std::unique_ptr<TTree> gtree(ghep_file->Get<TTree>("gtree"));
    gtree->SetBranchAddress("dk2nu", &dk2nu);

    // std::vector<double> nuOriginBeamX; 
    // std::vector<double> nuOriginBeamY; 
    // std::vector<double> nuOriginBeamZ; 
    // std::vector<double> nuOriginBeamT;
    double nuOriginBeamX;
    double nuOriginBeamY;
    double nuOriginBeamZ;
    double nuOriginBeamT;

    std::vector<TLorentzVector> nuOriginBeam;

    std::cout<<"entries: "<<gtree->GetEntries()<<std::endl;

    for (int i = 0; i < 1; i++){ // gtree->GetEntries()
        
        gtree->GetEntry(i);
        auto ancestor = dk2nu->ancestor;
        // some are outside the decay pipe (z > 221 m), but they are nu produced by muon decay
        // std::cout<<" z origin in beam coord: "<<nuOriginBeamZ[i]<<std::endl;
        // std::cout<<" t origin in beam coord: "<<nuOriginBeamT[i]<<std::endl;
        nuOriginBeamX = ancestor[ancestor.size()-1].startx;
        nuOriginBeamY = ancestor[ancestor.size()-1].starty;
        nuOriginBeamZ = ancestor[ancestor.size()-1].startz;
        nuOriginBeamT = ancestor[ancestor.size()-1].startt;

        TLorentzVector nuOriginBeam_tmp(nuOriginBeamX, nuOriginBeamY, nuOriginBeamZ, nuOriginBeamT);
        nuOriginBeam.push_back(nuOriginBeam_tmp);

        std::cout<<"nuOriginBeam "<<nuOriginBeam[i]<<std::endl;
    }

    TLorentzVector nuOriginUser;

    // define rotation
    TRotation r;
    double a = -0.101; // rad
    TRotation fBeamRot = r.RotateX(a);

    // define fBeamZero
    TVector3 userpos(0.0, 0.05387, 6.66); // m
    TVector3 beampos(0, 0, 562.1179); // m
    TVector3 beam0 = userpos - fBeamRot*beampos;
    TLorentzVector fBeamZero(beam0, 0);

    // conversion factors
    double fLengthScaleB2U = 1./100.;
    double fLengthTimeB2U = 1./1E9;

    std::cout<<"nuOriginBeam "<<nuOriginBeam[0]<<std::endl;
    nuOriginUser = fLengthScaleB2U*(TLorentzRotation(fBeamRot)*nuOriginBeam[0]) + fBeamZero;
    nuOriginUser.SetT(nuOriginBeam[0].T()*fLengthTimeB2U);
    std::cout<<"nuOriginUser "<<nuOriginUser<<std::endl;

    
    // check
    // double const c = 29.9792458; // cm/ns
    // double time = 56211.79/c; // ns
    // TLorentzVector NDHallBeam(0, 0, 56211.79, time);
    // TLorentzVector NDHallUser;
    // std::cout<<"NDHallBeam "<<NDHallBeam<<std::endl;
    // NDHallUser = fLengthScaleB2U*(TLorentzRotation(fBeamRot)*NDHallBeam) + fBeamZero;
    // NDHallUser.SetT(NDHallBeam.T()*fLengthTimeB2U);
    // std::cout<<"NDHallUser "<<NDHallUser<<std::endl;
    
    return nuOriginUser;
}