#include "gRooTracker.h"
#include "TG4Event.h"
#include <cmath>
// #include <Vector3D.h>
// #include <TCanvas.h>
// #include <TView3D.h>
// #include <TPolyLine3D.h>
// #include <TPolyMarker3D.h>

double dotProduct(const TVector3& vector1, const TVector3& vector2){
    double p = vector1.X()*vector2.X() + vector1.Y()*vector2.Y() + vector1.Z()*vector2.Z();
    return p;
}

std::ostream& operator<<(std::ostream& os, const TVector3& v){
    os << "( " << v.X() << ", " << v.Y() << ", " << v.Z() << ")";
    return os; 
}

double norm(const TVector3& v){
    return sqrt(v.X()*v.X() + v.Y()*v.Y() + v.Z()*v.Z());
}


void validate_transformation(std::string ghep_fname, std::string gtrac_fname){

    TVector3* nuMomentum = nullptr;
    TLorentzVector* nuOrigin = nullptr;
    TVector3* nuDistance = new TVector3();
    double EvtVtx[4];

    // input ghep file
    std::unique_ptr<TFile> ghep_file(TFile::Open(ghep_fname.c_str(), "UPDATE"));
    // input ghep tree
    std::unique_ptr<TTree> userNuTree(ghep_file->Get<TTree>("tNuInfo"));
    userNuTree->SetBranchAddress("userNuMomentum", &nuMomentum);
    userNuTree->SetBranchAddress("userNuOrigin", &nuOrigin);

    TBranch* branchDistance = userNuTree->GetBranch("nuDistance");
    if (!branchDistance) {
        branchDistance = userNuTree->Branch("nuDistance", "TVector3", &nuDistance);
    } else {
        userNuTree->SetBranchAddress("nuDistance", &nuDistance);
    }

    // input gtrac file
    std::unique_ptr<TFile> gtrac_file(TFile::Open(gtrac_fname.c_str(), "READ"));
    // input gtrac tree
    std::unique_ptr<TTree> gRooTrk(gtrac_file->Get<TTree>("gRooTracker"));
    gRooTrk->SetBranchAddress("EvtVtx", &EvtVtx);

    std::cout<<"nr total entries: "<<userNuTree->GetEntries()<<std::endl;
    int nr_aligned = 0;

    for (int i = 0; i < userNuTree->GetEntries(); i++){ 

        std::cout<<"*****EVENT NR******* "<<i<<std::endl;
        
        userNuTree->GetEntry(i);
        gRooTrk->GetEntry(i);

        // take the distance between neutrino origin (nuOrigin) and neutrino interaction vertex (EvtVtx)
        long double x_nuDistance = EvtVtx[0] - nuOrigin->X();
        long double y_nuDistance = EvtVtx[1] - nuOrigin->Y();
        long double z_nuDistance = EvtVtx[2] - nuOrigin->Z();
        *nuDistance = TVector3(x_nuDistance, y_nuDistance, z_nuDistance);

        std::cout<<"X "<<EvtVtx[0]<<" - "<<nuOrigin->X()<<std::endl;
        std::cout<<"Y "<<EvtVtx[1]<<" - "<<nuOrigin->Y()<<std::endl;
        std::cout<<"Z "<<EvtVtx[2]<<" - "<<nuOrigin->Z()<<std::endl;

        // print the two vectors: distance and momentum
        // std::cout<<"Vector distance: "<<nuDistance<<std::endl;
        // std::cout<<"Momentum: "<<*nuMomentum<<std::endl;
        // std::cout<<"Distance (norm): "<<norm(*nuDistance)<<std::endl;

        // compute dot product
        double product = dotProduct(*nuDistance, *nuMomentum);

        double cosine = abs(product / (norm(*nuDistance)*norm(*nuMomentum)));

        // std::cout<<"cosine "<<cosine<<std::endl;

        // if (cosine >= 0.9) {
        //     nr_aligned++;
        //     std::cout<<"Ok, the product is: "<<product<<" and the cosine is "<<cosine<<std::endl;
        // }
        // else {
        //     std::cout<<"Not aligned! The product is: "<<product<<" and the cosine is "<<cosine<<std::endl;
        //     std::cout<<"Theta is "<<acos(cosine)<<std::endl;
        // }

        branchDistance->Fill();

        // TCanvas *c = new TCanvas("c", "nu TOF", 800, 600);
        // TView *view = TView::CreateView(1);
        // view->SetRange(-1, -1, -1, 2, 2, 2);

        // // start and end points
        // TPolyMarker3D *pm = new TPolyMarker3D(2);
        // pm->SetPoint(0, nuOrigin->X(), nuOrigin->Y(), nuOrigin->Z());
        // pm->SetPoint(1, EvtVtx[0], EvtVtx[1], EvtVtx[2]);
        // pm->SetMarkerStyle(20);
        // pm->SetMarkerSize(1);
        // pm->SetMarkerColor(kRed);
        // pm->Draw();

        // // distance between start and end points
        // TPolyLine3D *line = new TPolyLine3D(2);
        // line->SetPoint(0, nuOrigin->X(), nuOrigin->Y(), nuOrigin->Z());
        // line->SetPoint(1, EvtVtx[0], EvtVtx[1], EvtVtx[2]);
        // line->SetLineColor(kBlue);
        // line->SetLineWidth(2);
        // // line->Draw();

        // // momentum direction
        // TPolyLine3D *direction = new TPolyLine3D(2);
        // direction->SetPoint(0, nuOrigin->X(), nuOrigin->Y(), nuOrigin->Z());
        // direction->SetPoint(1, nuOrigin->X() + nuMomentum->X(), nuOrigin->Y()+ nuMomentum->Y(), nuOrigin->Z()+ nuMomentum->Z());
        // direction->SetLineColor(kGreen);
        // direction->SetLineWidth(2);
        // direction->Draw();

        // c->SaveAs("nu_tof.root");
    }
    ghep_file->cd();
    userNuTree->Write("", TObject::kOverwrite);

    std::cout<<"nr aligned "<<nr_aligned<<std::endl;
    std::cout<<"nr not aligned "<<userNuTree->GetEntries() - nr_aligned<<std::endl;
}