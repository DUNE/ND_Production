// #include "TG4Event.h"
#include "gRooTracker.h"
#include "TLorentzVector.h"
// #include "NuChoice.h"

// Beam2UserNuOrigin_dk2nu

std::ostream& operator<<(std::ostream& os, const TLorentzVector& v){
    os << "( " << v.X() << ", " << v.Y() << ", " << v.Z() << ", " << v.T() << ")";
    return os; 
}

std::ostream& operator<<(std::ostream& os, const TVector3& v){
    os << "( " << v.X() << ", " << v.Y() << ", " << v.Z() << ")";
    return os; 
}

void convert2User(std::string ghep_fname){

    bsim::Dk2Nu* dk2nu = nullptr;
    bsim::NuChoice* nuchoice = nullptr;
    TLorentzVector userNuOrigin;
    TLorentzVector beamNuOrigin;
    TVector3 userNuMomentum;
    TLorentzVector p4NuBeam;
    TLorentzVector p4NuUser;
    TLorentzVector x4NuBeam;
    TLorentzVector x4NuUser;

    std::cout<<"ghep file name: "<<ghep_fname<<std::endl;

    // input GHEP file
    std::unique_ptr<TFile> ghep_file(TFile::Open(ghep_fname.c_str(), "UPDATE"));
    // input tree
    std::unique_ptr<TTree> gtree(ghep_file->Get<TTree>("gtree"));
    gtree->SetBranchAddress("dk2nu", &dk2nu);
    gtree->SetBranchAddress("nuchoice", &nuchoice);

    // output tree
    std::unique_ptr<TTree> outTree = std::make_unique<TTree>("tNuInfo", "nu Info in User and Beam Coordinates");
    outTree->Branch("userNuOrigin", &userNuOrigin);
    outTree->Branch("beamNuOrigin", &beamNuOrigin);
    outTree->Branch("userNuMomentum", &userNuMomentum);
    outTree->Branch("p4NuBeam", &p4NuBeam);
    outTree->Branch("p4NuUser", &p4NuUser);
    outTree->Branch("x4NuBeam", &x4NuBeam);
    outTree->Branch("x4NuUser", &x4NuUser);

    double beamNuOriginX;
    double beamNuOriginY;
    double beamNuOriginZ;
    double beamNuOriginT;

    double beamNuMomentumX;
    double beamNuMomentumY;
    double beamNuMomentumZ;

    std::vector<TLorentzVector> beamNuOrigins;
    std::vector<TLorentzVector> userNuOrigins;
    std::vector<TVector3> beamNuMomenta;
    std::vector<TVector3> userNuMomenta;

    std::cout<<"entries: "<<gtree->GetEntries()<<std::endl;

    // **********BEAM-USER TRANSFORMATION************
    // define rotation
    TRotation r;
    // N.B. in GNuMIFlux.xml the beamdir is -0.101 but the GDk2Nu script takes as fBeamRot its inverse, so +0.101. Thus, fBeamRotInv will be -0.101. 
    // To be consistent with this formalism, we keep as fBeamRot = +0.101 and fBeamRotInv = -0.101.
    double a = +0.101; //[rad] 
    TRotation fBeamRot = r.RotateX(a);
    TRotation fBeamRotInv = r.RotateX(-0.101);
    
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

        p4NuBeam.SetXYZT(nuchoice->p4NuBeam.X(), nuchoice->p4NuBeam.Y(), nuchoice->p4NuBeam.Z(), nuchoice->p4NuBeam.T());
        p4NuUser.SetXYZT(nuchoice->p4NuUser.X(), nuchoice->p4NuUser.Y(), nuchoice->p4NuUser.Z(), nuchoice->p4NuUser.T());

        x4NuBeam.SetXYZT(nuchoice->x4NuBeam.X(), nuchoice->x4NuBeam.Y(), nuchoice->x4NuBeam.Z(), nuchoice->x4NuBeam.T());
        x4NuUser.SetXYZT(nuchoice->x4NuUser.X(), nuchoice->x4NuUser.Y(), nuchoice->x4NuUser.Z(), nuchoice->x4NuUser.T());

        // ****************POSITION
        // some are outside the decay pipe (z > 221 m), but they are nu produced by muon decay
        // std::cout<<" z origin in beam coord: "<<nuOriginBeamZ[i]<<std::endl;
        // std::cout<<" t origin in beam coord: "<<nuOriginBeamT[i]<<std::endl;
        beamNuOriginX = ancestor[ancestor.size()-1].startx;
        beamNuOriginY = ancestor[ancestor.size()-1].starty;
        beamNuOriginZ = ancestor[ancestor.size()-1].startz;
        beamNuOriginT = ancestor[ancestor.size()-1].startt;

        beamNuOrigin.SetXYZT(beamNuOriginX, beamNuOriginY, beamNuOriginZ, beamNuOriginT);
        beamNuOrigins.push_back(beamNuOrigin);
        std::cout<<"neutrino origin in beam coord "<<beamNuOrigins[i]<<std::endl;

        // transformation
        userNuOrigin = fLengthScaleB2U*(TLorentzRotation(fBeamRot)*beamNuOrigin) + fBeamZero;
        userNuOrigin.SetT(beamNuOrigin.T()*fLengthTimeB2U);

        std::cout << "userNuOrigin (x,y,z,t) = ("
          << userNuOrigin.X() << ", "
          << userNuOrigin.Y() << ", "
          << userNuOrigin.Z() << ", "
          << userNuOrigin.T() << ")" << std::endl;
        
        userNuOrigins.push_back(userNuOrigin);

        // *************** MOMENTUM (start momentum, so I know the direction of nu)
        beamNuMomentumX = ancestor[ancestor.size()-1].startpx;
        beamNuMomentumY = ancestor[ancestor.size()-1].startpy;
        beamNuMomentumZ = ancestor[ancestor.size()-1].startpz;

        TVector3 beamNuMomentum(beamNuMomentumX, beamNuMomentumY, beamNuMomentumZ);
        beamNuMomenta.push_back(beamNuMomentum);
        // std::cout<<"neutrino start momentum in beam coord "<<beamNuMomenta[i]<<std::endl;
        
        // transformation
        userNuMomentum = fBeamRot*beamNuMomentum;

        // std::cout << "userNuMomentum = ("
        //   << userNuMomentum.X() << ", "
        //   << userNuMomentum.Y() << ", "
        //   << userNuMomentum.Z() << ") " << std::endl;
        
        userNuMomenta.push_back(userNuMomentum);

        outTree->Fill();
    }
    
    // ghep_file->cd();
    // ghep_file->Delete("tNuOriginUser;*");
    // ghep_file->Delete("tNuInfo;*");
    outTree->Write("", TObject::kOverwrite);

    // std::cout<<"neutrino origin in beam coord "<<beamNuOrigins[0]<<std::endl;
    // nuOriginUser = fLengthScaleB2U*(TLorentzRotation(fBeamRot)*beamNuOrigins[0]) + fBeamZero;
    // nuOriginUser.SetT(beamNuOrigins[0].T()*fLengthTimeB2U);
    // std::cout<<"neutrino origin in user coord "<<userNuOrigins<<std::endl;

    
    // check
    double const c = 29.9792458; // cm/ns
    double time = 56211.79/c; // ns
    TLorentzVector NDHallBeam(0, 0, 56211.79, time);
    TLorentzVector NDHallUser;
    std::cout<<"NDHallBeam "<<NDHallBeam<<std::endl;
    NDHallUser = fLengthScaleB2U*(TLorentzRotation(fBeamRot)*NDHallBeam) + fBeamZero;
    NDHallUser.SetT(NDHallBeam.T()*fLengthTimeB2U);
    std::cout<<"NDHallUser "<<NDHallUser<<std::endl;
    
}