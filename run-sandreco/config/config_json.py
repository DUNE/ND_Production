import json
import os
import re
import subprocess

def require_env(name):
    """Return the value of a required environment variable, or fail with its name."""
    try:
        return os.environ[name]
    except KeyError:
        raise KeyError(f"required environment variable '{name}' is not set") from None

def get_module(cfg, name):
    """Return the parameter dict of the module `name` in the template 'run' list."""
    matches = [entry[name] for entry in cfg['run'] if name in entry]
    if not matches:
        raise KeyError(f"module '{name}' not found in template 'run' list")
    if len(matches) > 1:
        raise KeyError(f"module '{name}' appears {len(matches)} times in template 'run' list")
    return matches[0]

def remove_module(cfg, name):
    """Remove the module 'name' from the 'run' list (error if it is not there)."""
    get_module(cfg, name)  # validates presence and uniqueness
    cfg['run'] = [entry for entry in cfg['run'] if name not in entry]

def set_params(section, label, **params):
    """Set existing keys of `section`; refuse to create new ones (catches typos/renames)."""
    for key, value in params.items():
        if key not in section:
            raise KeyError(f"parameter '{key}' not found in '{label}'")
        section[key] = value

# read all the environment variables from the configuration sh script
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
input_file = (f"{relative_out_dir_path}/run-convert2edepsim-spill-format/{nd_prod_in_name}/OVERLAY/{sub_dir}/{in_file_name}.OVERLAY.root")
in_file_abs = os.path.normpath(os.path.join(base_dir, input_file))

tree = "EDepSimEvents"
root_cmd = f'TFile f("{in_file_abs}"); auto* t = static_cast<TTree*>(f.Get("{tree}")); if(t) std::cout << t->GetEntries() << std::endl;'

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
with open(f"{nd_prod_dir}/run-sandreco/config/sandreco_v1.2.x.template.json") as f:
  config_sandreco = json.load(f)

# global configuration
set_params(config_sandreco['ufw'], 'ufw', **{'ufw-basepath': base_dir})
set_params(config_sandreco['globals']['sand::root_tgeomanager'],
           'globals/sand::root_tgeomanager', geometry=input_file)
set_params(config_sandreco['contexts'], 'contexts', keys=nr_input_spills)
set_params(config_sandreco['contexts']['locals']['sand::edep_reader'],
           'contexts/locals/sand::edep_reader', uri=input_file)
set_params(config_sandreco['contexts']['locals']['sand::genie_reader'],
           'contexts/locals/sand::genie_reader', uri=input_file)

# tracker / grain / ecal reco
for mod, min_en, uses_bfield in [
    ('sand::fast::tracker::reco', min_en_dep_trk,   True),
    ('sand::fast::grain::reco',   min_en_dep_grain, True),
    ('sand::fast::ecal::reco',    min_en_dep_ecal,  False),
]:
    params = {'min_energy_deposit': float(min_en)}
    if uses_bfield:
        params['b_field_magnitude'] = float(b_field_magnitude)
    set_params(get_module(config_sandreco, mod), mod, **params)

# test
mod = 'sand::test::fast_reco_test'
set_params(get_module(config_sandreco, mod), mod,
           tracker_min_energy_deposit=float(min_en_dep_trk),
           grain_min_energy_deposit=float(min_en_dep_grain),
           ecal_min_energy_deposit=float(min_en_dep_ecal),
           b_field_magnitude=float(b_field_magnitude))

# gauss smearing
mod = 'sand::common::gauss_smearing'
if apply_gauss:
    set_params(get_module(config_sandreco, mod), mod,
               energy_resolution=float(energy_resolution_gauss),
               momentum_resolution=float(momentum_resolution_gauss),
               x_resolution=float(pos_resolution_gauss),
               y_resolution=float(pos_resolution_gauss),
               z_resolution=float(pos_resolution_gauss))

# gluckstern smearing
mod = 'sand::common::gluckstern_smearing'
if apply_gluck:
    set_params(get_module(config_sandreco, mod), mod,
               intrinsic_pos_res_t=float(pos_res_transverse_gluckstern),
               intrinsic_pos_res_l=float(pos_res_longitudinal_gluckstern),
               hit_energy_thr=float(hit_energy_threshold))

# caf output
mod = 'sand::caf::caf_streamer'
set_params(get_module(config_sandreco, mod), mod,
           uri=f"{relative_out_dir_path}/tmp/run-sandreco/{nd_prod_out_name}/{out_file_name}.SANDRECO.root")


with open(f"{cfg_json_file}", mode="w", encoding="utf-8") as write_file:
    json.dump(config_sandreco, write_file, indent=2)


