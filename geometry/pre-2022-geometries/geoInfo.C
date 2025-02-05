void geoInfo(TString filename, TString volumeName)
{
        TGeoManager *geom = new TGeoManager();
        geom->Import(filename);

        int n_volumes = geom -> GetListOfVolumes()->GetEntries();
        for(int i=0; i<n_volumes; i++){
		TGeoIterator next(geom->GetVolume(i));
		if (geom->GetVolume(i)->GetName() != volumeName) continue;
		cout<<"name : "<<geom->GetVolume(i)->GetName()<<" "<<endl;
        	//<<"shape : "<<geom->GetVolume(i)->GetShape();
		TGeoNode*current; TGeoVolume *vol;
		TString path;
		while ((current=next())) {
			vol = current->GetVolume();
  			next.GetPath(path);
  			const TGeoMatrix *global = next.GetCurrentMatrix();
  			// if you want to see where is the center (origin) of this object in TOP coordinates:
  			const double *local_bbox_orig = ((TGeoBBox*)vol->GetShape())->GetOrigin(); 
  			double master_orig[3];
  			global->LocalToMaster(local_bbox_orig, master_orig);
  			std::cout << path << ": volume=" << vol->GetName() << "   material: "<< vol->GetMaterial()->GetName()<<"  position: (" << master_orig[0] <<   ", " << master_orig[1] << ", " << master_orig[2] << ")\n";
		}
	}
}
