#!/usr/bin/env python3

import argparse
import math
import matplotlib
import matplotlib.pyplot as plt
import numpy as np
import operator
import os

from matplotlib.backends.backend_pdf import PdfPages


process_name_to_processes_per_node = {}
process_name_to_processes_per_node["genie (ndlarfid)"] = 256.0  
process_name_to_processes_per_node["genie (rockantindlarfid)"] = 256.0  
process_name_to_processes_per_node["edep (ndlarfid)"] = 256.0  
process_name_to_processes_per_node["edep (rockantindlarfid)"] = 256.0  
process_name_to_processes_per_node["hadd (ndlarfid)"] = 256.0  
process_name_to_processes_per_node["hadd (rockantindlarfid)"] = 256.0  
process_name_to_processes_per_node["spill (full)"] = 128  
process_name_to_processes_per_node["tmsreco (full)"] = 128  
process_name_to_processes_per_node["convert2h5 (full)"] = 128   
process_name_to_processes_per_node["larnd (full)"] = 4   
process_name_to_processes_per_node["flow (full)"] = 16
process_name_to_processes_per_node["flow2supera (full)"] = 32
process_name_to_processes_per_node["spine (full)"] = 4
process_name_to_processes_per_node["caf (full)"] = 4


def convert_to_minutes(time_string):
    time_string_list = time_string.split(':')
    # Ignore subseconds.
    time_string_list[-1] = time_string_list[-1].split(".")[0]
        
    conversion = [60,1,1.0/60.0]
    if len(time_string_list) == 2:
        conversion = conversion[1:]

    return sum([a*b for a,b in zip(conversion, map(int,time_string_list))])


def convert_to_gb_float(kb_string):
        
    return float(kb_string)/1.0e6


def main(base_dir, out_dir):

    master_dict = {}
    for root, _, files in os.walk(base_dir):
        if not "TIMING" in root: continue
        if not files: continue

        for file in files:
            with open (os.path.join(root, file)) as f:
                this_key = file.split('.')[1]+" ("+file.split('.')[2]+")"
                if not this_key in master_dict:
                    master_dict[this_key] = []
                lines = f.readlines()
                parsed_lines = []
                i = 0
                while i < len(lines):
                    line = lines[i]
                    if "Command" in line:
                        i += 2
                        continue
                    parsed_lines.append(line.rstrip("\n").split(" "))
                    i += 1
                master_dict[this_key].append(parsed_lines)

    bp_dicts_times = []
    bp_dicts_mems = []
    bp_dicts_times_node_time = []
    cpu_total_node_hours = [0.,0.]
    gpu_total_node_hours = [0.,0.]
    for production_step in master_dict.keys():
        times = []
        memories = []
        times_node_times = []
        for job in master_dict[production_step]:
            time = 0.
            memory = 0.
            time_node_time = 0.
            for executable in job:
                time += convert_to_minutes(executable[-1]) 
                memory = max(convert_to_gb_float(executable[-2]), memory)
            
            # Hadd factor of 10.
            if not ("full" in production_step or "hadd" in production_step):
                time = time*10.

            # Catch fail on startup (less than 10 seconds).
            if time < 0.17: continue

            times.append(time)
            memories.append(memory)

        # Process times scaled to post-hadd POT.
        median = np.median(times)
        std = np.std(times)
        min_val = np.min(times)
        max_val = np.max(times)
        q1 = max(min_val, median-2.*std)
        q3 = min(max_val, median+2.*std)
        bp_dicts_times.append({'label' : production_step, 'whislo' : min_val, 'q1' : q1, 'med' : median, 'q3' : q3, 'whishi' : max_val, 'fliers' : []})

        # Now make median, lower and upper estimates on node hours
        # per post-hadd POT. The median quantifies the average time 
        # per 10^15 if you could only run 1 process per node. You
        # can run as many processes per node as memory will allow so
        # divide by that parallelisation.
        #
        # This is a less than elegant way of doing things but right now
        # I just want the plot.
        #
        # Scale up to a MicroProd size (10^18) and convert to hours.
        scale_factor = 1000./(process_name_to_processes_per_node[production_step]*60.)
        median *= scale_factor 
        q1 *= scale_factor
        q3 *= scale_factor
        bp_dicts_times_node_time.append({'label' : production_step, 'whislo' : q1, 'q1' : q1, 'med' : median, 'q3' : q3, 'whishi' : q3, 'fliers' : []})
        if production_step.startswith("larnd") or "spine" in production_step:
            gpu_total_node_hours[0] += median
            gpu_total_node_hours[1] += q3
        else:
            cpu_total_node_hours[0] += median
            cpu_total_node_hours[1] += q3

        median = np.median(memories)
        std = np.std(memories)
        min_val = np.min(memories)
        max_val = np.max(memories)
        q1 = max(min_val, median-2.*std)
        q3 = min(max_val, median+2.*std)
        # Not the number we're interested in for GPU jobs.
        if production_step.startswith("larnd") or "spine" in production_step: continue
        bp_dicts_mems.append({'label' : production_step, 'whislo' : min_val, 'q1' : q1, 'med' : median, 'q3' : q3, 'whishi' : max_val, 'fliers' : []})


    bp_dicts_times_median_sorted = sorted(bp_dicts_times, key=operator.itemgetter('med'))
    bp_dicts_times_node_time_median_sorted = sorted(bp_dicts_times_node_time, key=operator.itemgetter('med'))
    bp_dicts_mems_median_sorted = sorted(bp_dicts_mems, key=operator.itemgetter('med'))

    with PdfPages(out_dir+"/analyse_benchmarking_summary.pdf") as output:
        fig, ax = plt.subplots()
        plt.gcf().subplots_adjust(left=0.30, right=0.99)
        ax.bxp(bp_dicts_times_median_sorted, orientation='horizontal')
        ax.set_xscale('log')
        ax.set_xlabel("Run Time / Process / 10^15 POT (Minutes)")
        output.savefig()
        plt.close()

        fig, ax = plt.subplots()
        plt.gcf().subplots_adjust(left=0.30, right=0.99)
        title_cpu = f'Total CPU Node Hours (median, +2sigma): ({math.ceil(cpu_total_node_hours[0])}, {math.ceil(cpu_total_node_hours[1])})'
        title_gpu = f'Total GPU Node Hours (median, +2sigma): ({math.ceil(gpu_total_node_hours[0])}, {math.ceil(gpu_total_node_hours[1])})'
        plt.title(title_cpu+"\n"+title_gpu)
        ax.bxp(bp_dicts_times_node_time_median_sorted, orientation='horizontal')
        ax.set_xscale('log')
        ax.set_xlabel("Perlmutter Node Hours / 10^18 POT")
        output.savefig()
        plt.close()

        fig, ax = plt.subplots()
        plt.gcf().subplots_adjust(left=0.30, right=0.99)
        ax.bxp(bp_dicts_mems_median_sorted, orientation='horizontal')
        ax.set_xscale('log')
        ax.set_xlabel("Maximum Memory / Process (GB)")
        output.savefig()
        plt.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--base_dir', default=None, required=True, type=str, help='''string corresponding to the directory below which all of the TIMING files can be found.''')
    parser.add_argument('--out_dir', default="./", required=True, type=str, help='''string corresponding to the directory path to write output pdf.''')
    args = parser.parse_args()
    main(**vars(args))
