#!/usr/bin/env python
from __future__ import division
import sys, os

log_file_to_parse = sys.argv[1]

benchmarks = {}

fileContext = open(log_file_to_parse, "r")

for wholeLine in fileContext:
    line = wholeLine.strip()

    if line.startswith("Threads: "):
        threads = line.split(" ")[-1].replace("Threads:","")	
        benchmarks["threads"] = str(threads)	

    if line.startswith("Simulating "):
        vectors = line.split(" existing vectors")[0].replace("Simulating ","").replace(" new vectors.","")
        benchmarks["vectors"] = vectors
        
    if line.startswith("Nodes: "):
        nodes = line.split(" ")[-1].replace("Nodes:","")
        benchmarks["nodes"] = nodes

    if line.startswith("Stages: "):
        stages = line.split(" ")[-1].replace("Stages:","")
        benchmarks["stage"] = stages	

    if line.startswith("Simulation time:"):
        sim_time = line.split(" ")[-1].replace("Simulation time:","")
        if "sim_time" not in benchmarks:
            benchmarks["sim_time"] = []
            
        if 'ms'	in sim_time:
            sim_time = float(sim_time.replace('ms',''))
        elif 's' in sim_time:
            sim_time = float(sim_time.replace('s',''))
            sim_time = sim_time*1000
        elif 'm' in sim_time:
            sim_time = float(sim_time.replace('m',''))
            sim_time = sim_time*60000							
        benchmarks["sim_time"].append(sim_time)	

    if line.startswith("Elapsed time:"):
        elap_time = line.split(" ")[-1].replace("Elapsed time:","")
        if "elap_time" not in benchmarks:
            benchmarks["elap_time"] = []	
            
        if 'ms'	in elap_time:
            elap_time = float(elap_time.replace('ms',''))
        elif 's' in elap_time:
            elap_time = float(elap_time.replace('s',''))
            elap_time = elap_time*1000
        elif 'm' in elap_time:
            elap_time = float(elap_time.replace('m',''))
            elap_time = elap_time*60000
            
        benchmarks["elap_time"].append(elap_time)

    if "CPU:" in line:
        cpu_perc = float(line.split(" ")[-1].replace("CPU:","").replace('%',''))
        if "cpu_perc" not in benchmarks:
            benchmarks["cpu_perc"] = []							
        benchmarks["cpu_perc"].append(cpu_perc)							
