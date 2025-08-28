#include "gRooTracker.h"
#include "TG4Event.h"
#include<cmath>
#include <TCanvas.h>
#include <TView3D.h>
#include <TPolyLine3D.h>
#include <TPolyMarker3D.h>

TVector3 crossProduct(const TVector3& vector1, const TVector3& vector2){

    TVector3 p;

    p.SetX(vector1.Y() * vector2.Z() - vector1.Z() * vector2.Y());
    p.SetY(vector1.Z() * vector2.X() - vector1.X() * vector2.Z());
    p.SetZ(vector1.X() * vector2.Y() - vector1.Y() * vector2.X());

    return p;
}

std::ostream& operator<<(std::ostream& os, const TVector3& v){
    os << "( " << v.X() << ", " << v.Y() << ", " << v.Z() << ")";
    return os; 
}

double norm(const TVector3& v){
    return std::sqrt(v.X()*v.X() + v.Y()*v.Y() + v.Z()*v.Z());
}


// bool operator<(const TVector3& v1){
//    return (v1.X() < v2.X() && v1.Y() < v1.Y() && v1.Z() < v2.Z()) return true;
//    else return false;
// }   


void validate_transformation(std::string ghep_fname, std::string gtrac_fname){

    TVector3* nuMomentum = nullptr;
    TLorentzVector* nuOrigin = nullptr;
    double EvtVtx[4];

    // input ghep file
    std::unique_ptr<TFile> ghep_file(TFile::Open(ghep_fname.c_str(), "READ"));
    // input ghep tree
    std::unique_ptr<TTree> userNuTree(ghep_file->Get<TTree>("tNuUser"));
    userNuTree->SetBranchAddress("userNuMomentum", &nuMomentum);
    userNuTree->SetBranchAddress("userNuOrigin", &nuOrigin);

    // input gtrac file
    std::unique_ptr<TFile> gtrac_file(TFile::Open(gtrac_fname.c_str(), "READ"));
    // input gtrac tree
    std::unique_ptr<TTree> gRooTrk(gtrac_file->Get<TTree>("gRooTracker"));
    gRooTrk->SetBranchAddress("EvtVtx", &EvtVtx);

    std::cout<<"nr total entries: "<<userNuTree->GetEntries()<<std::endl;
    int nr_aligned = 0;

    for (int i = 0; i < 1; i++){ //userNuTree->GetEntries()

        gRooTrk->GetEntry(0);
        userNuTree->GetEntry(0);

        // take the neutrino momentum (the direction)

        // take the distance between neutrino origin (nuOrigin) and neutrino interaction vertex (EvtVtx)
        
        double x_nuDistance = EvtVtx[0] - nuOrigin->X();
        double y_nuDistance = EvtVtx[1] - nuOrigin->Y();
        double z_nuDistance = EvtVtx[2] - nuOrigin->Z();

        TVector3 nuDistance(x_nuDistance, y_nuDistance, z_nuDistance);

        nuDistance.SetX(x_nuDistance/norm(nuDistance));
        nuDistance.SetY(y_nuDistance/norm(nuDistance));
        nuDistance.SetZ(z_nuDistance/norm(nuDistance));

        std::cout<<"Vector distance "<<nuDistance<<std::endl;
        std::cout<<"Momentum "<<*nuMomentum<<std::endl;


        std::cout<<"Distance: "<<norm(nuDistance)<<std::endl;

        // compute cross product
        TVector3 product = crossProduct(nuDistance, *nuMomentum);
        double norm_p = norm(product);

        if (norm_p < 25) {
            nr_aligned++;
            std::cout<<"Ok, the product is: "<<product<<std::endl;
            std::cout<<"Ok, the norm is: "<<norm_p<<std::endl;

        }
        else {
            std::cout<<"Not aligned! The product is: "<<product<<std::endl;
            std::cout<<"Not aligned! The norm is: "<<norm_p<<std::endl;
        }


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

    std::cout<<"nr aligned "<<nr_aligned<<std::endl;
    std::cout<<"nr not aligned "<<userNuTree->GetEntries() - nr_aligned<<std::endl;
}