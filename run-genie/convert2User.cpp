// #include "TG4Event.h"
#include "gRooTracker.h"
// #include "Dk2Nu.h"

// Beam2UserNuOrigin_dk2nu

TLorentzVector convert2User(std::string ghep_fname){

    bsim::Dk2Nu* dk2nu = nullptr;

    std::cout<<"ghep file name: "<<ghep_fname<<std::endl;

    // input GHEP file
    std::unique_ptr<TFile> ghep_file(TFile::Open(ghep_fname.c_str()));
    // input tree
    std::unique_ptr<TTree> gtree(ghep_file->Get<TTree>("gtree"));
    gtree->SetBranchAddress("dk2nu", &dk2nu);

    std::vector<double> nuOriginBeamZ; 

    std::cout<<"entries: "<<gtree->GetEntries()<<std::endl;

    for (int i = 0; i < gtree->GetEntries(); i++){
        gtree->GetEntry(i);
        auto ancestor = dk2nu->ancestor;
        std::cout<<"ancestor: "<<dk2nu->ancestor[ancestor.size()-1].startz<<std::endl;
        nuOriginBeamZ.push_back(ancestor[ancestor.size()-1].startz);
        std::cout<<" z origin in beam coord: "<<nuOriginBeamZ[i]<<std::endl;
    }

    // TLorentzVector nuOriginBeam(nuOriginBeamX[0], nuOriginBeamY[0], nuOriginBeamZ[0], nuOriginBeamT[0]);
    TLorentzVector nuOriginUser;

    // // define rotation
    // TRotation r;
    // double a = -0.101; //rad
    // TLorentzRotation fBeamRot = r.RotateX(a);

    // // define fBeamZero
    // TVector3 userpos(0.0, 0.05387, 6.66); //m
    // TVector3 beampos(0, 0, 562.1179); //m
    // TVector3 beam0 = userpos - fBeamRot*beampos;
    // TLorentzVector fBeamZero(beam0, 0);

    // double fLengthScaleB2U = 1/100;

    // nuOriginUser = fLengthScaleB2U*(fBeamRot*nuOriginBeam) + fBeamZero;
    
    return nuOriginUser;
}

// void GDk2NuFlux::Beam2UserPos(const TLorentzVector& beamxyz,
//                                    TLorentzVector& usrxyz) const
// {
//   usrxyz = fLengthScaleB2U*(fBeamRot*beamxyz) + fBeamZero;
//   // above assumed T=0
//   usrxyz.SetT(beamxyz.T()*fTimeScaleB2U);
// }

// ROOT::RDataFrame df("gtree", ghep_fname);
// auto df2 = df.Define("nu_ancestor_startx", 
// [](const std::vector<double>& v) { return v.back(); }, 
// {"ancestor.startx"}).Define("nu_ancestor_starty", 
// [](const std::vector<double>& v) { return v.back(); }, 
// {"ancestor.starty"}).Define("nu_ancestor_startz", 
// [](const std::vector<double>& v) { return v.back(); }, 
// {"ancestor.startz"}).Define("nu_ancestor_startt", 
// [](const std::vector<double>& v) { return v.back(); }, 
// {"ancestor.startt"});

// auto nuOriginBeamX = df.Take<Double_t>("ancestor.startx");
// auto nuOriginBeamY = df.Take<Double_t>("ancestor.starty");
// auto nuOriginBeamZ = df.Take<Double_t>("ancestor.startz");
// auto nuOriginBeamT = df.Take<Double_t>("ancestor.startt");