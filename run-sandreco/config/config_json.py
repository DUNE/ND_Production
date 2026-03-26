import json
import os
import subprocess

base_dir = os.environ.get('BASE_DIR')
nd_prod_dir = os.environ.get('ND_PRODUCTION_DIR')

nd_prod_out_dir_base = os.environ.get('ND_PRODUCTION_OUTDIR_BASE')
relative_out_dir_path = 'workspace/' + nd_prod_out_dir_base.split('/workspace/', 1)[1]

nd_prod_log_dir_base = os.environ.get('ND_PRODUCTION_LOGDIR_BASE')
relative_log_dir_path = 'workspace/' + nd_prod_log_dir_base.split('/workspace/', 1)[1]

nd_prod_in_name = os.environ.get('ND_PRODUCTION_IN_NAME')
sub_dir = os.environ.get('subDir')
in_file_name = os.environ.get('overlayName')

nd_prod_out_name = os.environ.get('ND_PRODUCTION_OUT_NAME')
out_file_name = os.environ.get('outName')

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
with open(f"{nd_prod_dir}/run-sandreco/config/fast_reco_v0.template.json") as f:
  config_sandreco = json.load(f)


config_sandreco['ufw']['ufw-basepath'] = base_dir
config_sandreco['globals']['sand::root_tgeomanager']['geometry'] = f"{relative_out_dir_path}/run-convert2edepsim-spill-format/{nd_prod_in_name}/OVERLAY/{sub_dir}/{in_file_name}.OVERLAY.root"
config_sandreco['contexts']['keys'] = nr_input_spills
config_sandreco['contexts']['locals']['sand::edep_reader']['uri'] = f"{relative_out_dir_path}/run-convert2edepsim-spill-format/{nd_prod_in_name}/OVERLAY/{sub_dir}/{in_file_name}.OVERLAY.root"
config_sandreco['contexts']['locals']['sand::genie_reader']['uri'] = f"{relative_out_dir_path}/run-convert2edepsim-spill-format/{nd_prod_in_name}/OVERLAY/{sub_dir}/{in_file_name}.OVERLAY.root"
config_sandreco['run'][1]['sand::caf::caf_streamer']['uri'] = f"{relative_out_dir_path}/tmp/run-sandreco/{nd_prod_out_name}/{out_file_name}.SANDRECO.root"


with open(f"{nd_prod_dir}/run-sandreco/config/config_sandreco.json", mode="w", encoding="utf-8") as write_file:
    json.dump(config_sandreco, write_file, indent=2)


