import json
import os
import subprocess

base_dir = os.environ.get('BASE_DIR')
nd_prod_dir = os.environ.get('ND_PRODUCTION_DIR')

nd_prod_out_dir_base = os.environ.get('ND_PRODUCTION_OUTDIR_BASE')
relative_out_dir_path = os.path.relpath(nd_prod_out_dir_base, base_dir)

nd_prod_log_dir_base = os.environ.get('ND_PRODUCTION_LOGDIR_BASE')
relative_log_dir_path = os.path.relpath(nd_prod_log_dir_base, base_dir)

nd_prod_in_name = os.environ.get('ND_PRODUCTION_IN_NAME')
sub_dir = os.environ.get('subDir')
in_file_name = os.environ.get('overlayName')

nd_prod_out_name = os.environ.get('ND_PRODUCTION_OUT_NAME')
out_file_name = os.environ.get('outName')

cfg_json_file = os.environ.get('CONFIG_JSON_FILE')

# physics parameters
energy_resolution_gauss = os.environ.get('ENERGY_RESOLUTION')
momentum_resolution_gauss = os.environ.get('MOMENTUM_RESOLUTION')
pos_resolution_gauss = os.environ.get('POS_RESOLUTION')

pos_res_transverse_gluckstern = os.environ.get('POS_RES_TRANSVERSE_GLUCKSTERN')
pos_res_longitudinal_gluckstern = os.environ.get('POS_RES_LONGITUDINAL_GLUCKSTERN')
hit_energy_threshold = os.environ.get('HIT_ENERGY_THRESHOLD')
b_field_magnitude = os.environ.get('B_FIELD_MAGNITUDE')

# count the number of input entries, since I want to process all of them
in_file = f"{nd_prod_out_dir_base}/run-convert2edepsim-spill-format/{nd_prod_in_name}/OVERLAY/{sub_dir}/{in_file_name}.OVERLAY.root"
tree = "EDepSimEvents"
root_cmd = f'TFile f("{in_file}"); auto* t = static_cast<TTree*>(f.Get("{tree}")); if(t) std::cout << t->GetEntries() << std::endl;'

result = subprocess.run(
    ["root", "-l", "-b", "-q", "-e", root_cmd],
    capture_output=True,
    text=True
)

output = result.stdout.strip()
if not output:
    raise RuntimeError(f"ROOT returned no output.\nSTDERR:\n{result.stderr}")

nr_input_spills = int(output.splitlines()[-1])
print("nr input spills ", nr_input_spills)

# open and configure the json file
with open(f"{nd_prod_dir}/run-sandreco/config/sandreco_v1.0.x.template.json") as f:
  config_sandreco = json.load(f)


config_sandreco['ufw']['ufw-basepath'] = base_dir
config_sandreco['globals']['sand::root_tgeomanager']['geometry'] = f"{relative_out_dir_path}/run-convert2edepsim-spill-format/{nd_prod_in_name}/OVERLAY/{sub_dir}/{in_file_name}.OVERLAY.root"
config_sandreco['contexts']['keys'] = nr_input_spills
config_sandreco['contexts']['locals']['sand::edep_reader']['uri'] = f"{relative_out_dir_path}/run-convert2edepsim-spill-format/{nd_prod_in_name}/OVERLAY/{sub_dir}/{in_file_name}.OVERLAY.root"
config_sandreco['contexts']['locals']['sand::genie_reader']['uri'] = f"{relative_out_dir_path}/run-convert2edepsim-spill-format/{nd_prod_in_name}/OVERLAY/{sub_dir}/{in_file_name}.OVERLAY.root"
config_sandreco['run'][3]['sand::common::gauss_smearing']['energy_resolution'] = float(energy_resolution_gauss)
config_sandreco['run'][3]['sand::common::gauss_smearing']['momentum_resolution'] = float(momentum_resolution_gauss)
config_sandreco['run'][3]['sand::common::gauss_smearing']['x_resolution'] = float(pos_resolution_gauss)
config_sandreco['run'][3]['sand::common::gauss_smearing']['y_resolution'] = float(pos_resolution_gauss)
config_sandreco['run'][3]['sand::common::gauss_smearing']['z_resolution'] = float(pos_resolution_gauss)
config_sandreco['run'][4]['sand::common::gluckstern_smearing']['intrinsic_pos_res_t'] = float(pos_res_transverse_gluckstern)
config_sandreco['run'][4]['sand::common::gluckstern_smearing']['intrinsic_pos_res_l'] = float(pos_res_longitudinal_gluckstern)
config_sandreco['run'][4]['sand::common::gluckstern_smearing']['hit_energy_thr'] = float(hit_energy_threshold)
config_sandreco['run'][4]['sand::common::gluckstern_smearing']['b_field_magnitude'] = float(b_field_magnitude)
config_sandreco['run'][5]['sand::caf::caf_streamer']['uri'] = f"{relative_out_dir_path}/tmp/run-sandreco/{nd_prod_out_name}/{out_file_name}.SANDRECO.root"


with open(f"{cfg_json_file}", mode="w", encoding="utf-8") as write_file:
    json.dump(config_sandreco, write_file, indent=2)


