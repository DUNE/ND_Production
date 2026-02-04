import json
import os 

base_dir = os.environ.get('BASE_DIR')
nd_prod_dir = os.environ.get('ND_PRODUCTION_DIR')

nd_prod_out_dir_base = os.environ.get('ND_PRODUCTION_OUTDIR_BASE')
relative_out_dir_path = 'workspace/' + nd_prod_out_dir_base.split('/workspace/', 1)[1]

nd_prod_log_dir_base = os.environ.get('ND_PRODUCTION_LOGDIR_BASE')
relative_log_dir_path = 'workspace/' + nd_prod_log_dir_base.split('/workspace/', 1)[1]

nd_prod_in_name = os.environ.get('ND_PRODUCTION_IN_NAME')
nd_prod_out_name = os.environ.get('ND_PRODUCTION_OUT_NAME')

in_file_name = os.environ.get('overlayName')
global_idx = os.environ.get('globalIdx')
out_file_name = os.environ.get('outName')
print("out file name is ", out_file_name)



with open(f"{nd_prod_dir}/run-sandreco/config/fast_reco_v0.template.json") as f:
  config_sandreco = json.load(f)


config_sandreco['ufw']['ufw-basepath'] = base_dir
config_sandreco['globals']['sand::root_tgeomanager']['geometry'] = f"{relative_out_dir_path}/run-convert2edepsim-spill-format/{nd_prod_in_name}/OVERLAY/{global_idx}/{in_file_name}.OVERLAY.root"
config_sandreco['contexts']['keys'] = 2
config_sandreco['contexts']['locals']['sand::edep_reader']['uri'] = f"{relative_out_dir_path}/run-convert2edepsim-spill-format/{nd_prod_in_name}/OVERLAY/{global_idx}/{in_file_name}.OVERLAY.root"
config_sandreco['contexts']['locals']['sand::genie_reader']['uri'] = f"{relative_out_dir_path}/run-convert2edepsim-spill-format/{nd_prod_in_name}/OVERLAY/{global_idx}/{in_file_name}.OVERLAY.root"
config_sandreco['run'][1]['sand::caf::caf_streamer']['uri'] = f"{relative_out_dir_path}/tmp/run-sandreco/{nd_prod_out_name}/{out_file_name}.CAF.root"


with open(f"{nd_prod_dir}/run-sandreco/config/config_sandreco.json", mode="w", encoding="utf-8") as write_file:
    json.dump(config_sandreco, write_file, indent=2)


