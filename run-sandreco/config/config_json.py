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

# physics pars
min_en_dep_trk = os.environ.get('MIN_EN_DEPOSIT_TRK')
min_en_dep_grain = os.environ.get('MIN_EN_DEPOSIT_GRAIN')
min_en_dep_ecal = os.environ.get('MIN_EN_DEPOSIT_ECAL')
b_field_magnitude = os.environ.get('B_FIELD_MAGNITUDE')

# smearing
apply_gauss = os.environ.get("APPLY_GAUSS_SMEARING", "0") == "1"
apply_gluck = os.environ.get("APPLY_GLUCK_SMEARING", "0") == "1"

# gauss smearing pars
if apply_gauss:
    energy_resolution_gauss = os.environ.get('ENERGY_RESOLUTION')
    momentum_resolution_gauss = os.environ.get('MOMENTUM_RESOLUTION')
    pos_resolution_gauss = os.environ.get('POS_RESOLUTION')

# gluckstern smearing pars
if apply_gluck:
    pos_res_transverse_gluckstern = os.environ.get('POS_RES_TRANSVERSE_GLUCKSTERN')
    pos_res_longitudinal_gluckstern = os.environ.get('POS_RES_LONGITUDINAL_GLUCKSTERN')
    hit_energy_threshold = os.environ.get('HIT_ENERGY_THRESHOLD')

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

# global configuration
config_sandreco['ufw']['ufw-basepath'] = base_dir
config_sandreco['globals']['sand::root_tgeomanager']['geometry'] = f"{relative_out_dir_path}/run-convert2edepsim-spill-format/{nd_prod_in_name}/OVERLAY/{sub_dir}/{in_file_name}.OVERLAY.root"
config_sandreco['contexts']['keys'] = nr_input_spills
config_sandreco['contexts']['locals']['sand::edep_reader']['uri'] = f"{relative_out_dir_path}/run-convert2edepsim-spill-format/{nd_prod_in_name}/OVERLAY/{sub_dir}/{in_file_name}.OVERLAY.root"
config_sandreco['contexts']['locals']['sand::genie_reader']['uri'] = f"{relative_out_dir_path}/run-convert2edepsim-spill-format/{nd_prod_in_name}/OVERLAY/{sub_dir}/{in_file_name}.OVERLAY.root"
# tracker reco pars
config_sandreco['run'][1]['sand::fast::tracker::reco']['min_energy_deposit'] = float(min_en_dep_trk)
config_sandreco['run'][1]['sand::fast::tracker::reco']['b_field_magnitude'] = float(b_field_magnitude)
# grain reco pars
config_sandreco['run'][2]['sand::fast::grain::reco']['min_energy_deposit'] = float(min_en_dep_grain)
config_sandreco['run'][2]['sand::fast::grain::reco']['b_field_magnitude'] = float(b_field_magnitude)
# ecal reco pars
config_sandreco['run'][3]['sand::fast::ecal::reco']['min_energy_deposit'] = float(min_en_dep_ecal)
config_sandreco['run'][3]['sand::fast::ecal::reco']['b_field_magnitude'] = float(b_field_magnitude)
# test
config_sandreco['run'][8]['sand::test::fast_reco_test']['tracker_min_energy_deposit'] = float(min_en_dep_trk)
config_sandreco['run'][8]['sand::test::fast_reco_test']['grain_min_energy_deposit'] = float(min_en_dep_grain)
config_sandreco['run'][8]['sand::test::fast_reco_test']['ecal_min_energy_deposit'] = float(min_en_dep_ecal)
config_sandreco['run'][8]['sand::test::fast_reco_test']['b_field_magnitude'] = float(b_field_magnitude)

# gauss smearing pars
if apply_gauss: 
    config_sandreco['run'][9]['sand::common::gauss_smearing']['energy_resolution'] = float(energy_resolution_gauss)
    config_sandreco['run'][9]['sand::common::gauss_smearing']['momentum_resolution'] = float(momentum_resolution_gauss)
    config_sandreco['run'][9]['sand::common::gauss_smearing']['x_resolution'] = float(pos_resolution_gauss)
    config_sandreco['run'][9]['sand::common::gauss_smearing']['y_resolution'] = float(pos_resolution_gauss)
    config_sandreco['run'][9]['sand::common::gauss_smearing']['z_resolution'] = float(pos_resolution_gauss)
# gluckstern smearing pars
if apply_gluck:
    config_sandreco['run'][10]['sand::common::gluckstern_smearing']['intrinsic_pos_res_t'] = float(pos_res_transverse_gluckstern)
    config_sandreco['run'][10]['sand::common::gluckstern_smearing']['intrinsic_pos_res_l'] = float(pos_res_longitudinal_gluckstern)
    config_sandreco['run'][10]['sand::common::gluckstern_smearing']['hit_energy_thr'] = float(hit_energy_threshold)

# caf output
config_sandreco['run'][11]['sand::caf::caf_streamer']['uri'] = f"{relative_out_dir_path}/tmp/run-sandreco/{nd_prod_out_name}/{out_file_name}.SANDRECO.root"


with open(f"{cfg_json_file}", mode="w", encoding="utf-8") as write_file:
    json.dump(config_sandreco, write_file, indent=2)


