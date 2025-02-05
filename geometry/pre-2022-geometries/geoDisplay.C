void geoDisplay(TString filename, Int_t VisLevel=5)
{
	TGeoManager *geo = new TGeoManager();
	geo->Import(filename);
	geo->DefaultColors();


	geo->CheckOverlaps(1e-5,"d");
 	geo->PrintOverlaps();
	geo->SetVisOption(1);
	geo->SetVisLevel(VisLevel);
	geo->GetTopVolume()->Print();
	geo->GetTopVolume()->Draw("ogl");
	
	TGLViewer * v = (TGLViewer *)gPad->GetViewer3D();
	v->SetStyle(TGLRnrCtx::kOutline);
	v->SetSmoothPoints(kTRUE);
	v->SetLineScale(0.5);
	//	v->UseDarkColorSet();
	v->UpdateScene();
}
