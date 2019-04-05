#!/usr/bin/env python
from __future__ import division
import sys, os

def time_to_millis(time_in):
    time_in.strip()
    time_in.replace(' ', '')
    
    result = 'NaN'

    if 'h' in time_in:
        result = str(float(time_in.replace('h','')) * 60.0 * 60.0 * 1000.0)

    elif 'm' in time_in:
        result = str(float(time_in.replace('m','')) * 60.0 * 1000.0)

    elif 's' in time_in:
        result = str(float(time_in.replace('s','')) * 1000.0)

    elif 'ms'	in time_in:
        result = str(float(time_in.replace('ms','')))
    
    return result

def size_to_MiB(size_in):
    size_in = format_token(size_in)

    base_size = 1.0
    if 'b' in size_in:
        base_size = 8.0

    size_in = size_in.replace('i','')
    size_in = size_in.replace('I','')
    size_in = size_in.replace('b','')
    size_in = size_in.replace('B','')

    if 'G' in size_in or 'g' in size_in:
        size_in = (float(size_in.replace('G','').replace('g','')) / 1024.0 / 1024.0 / base_size)

    elif 'M' in size_in or 'm' in size_in:
        size_in = (float(size_in.replace('M','').replace('m','')) / 1024.0 / base_size)

    elif 'K' in size_in or 'k' in size_in:
        size_in = (float(size_in.replace('K','').replace('k','')) / 1024.0 / base_size)

    #we are now in byte
    return str(float(size_in) * 1024.0 * 1024.0)

def contains(line_in, on_tokens):
    for token in on_tokens:
        if token not in line_in:
            return False

    return True

def format_token(input_str):
    return input_str.strip().replace(' ', '').replace('(','').replace(')','').replace('%','').replace(',','')

# 1 indexed
def get_token(line_in, index):
    return str(line_in.split(" ")[index-1])

def insert_value(value_map, key, input_str):
    # catch non float value
    float_value = float(format_token(input_str))
    str_value = str(float_value)
    if key not in value_map:
        value_map[key] = str_value

def parse_line(benchmarks, line):

    line.strip()
    line = " ".join(line.split())

    if contains(line, {"Executing simulation with", "threads"}):
        insert_value(benchmarks, "max_thread_count", get_token(line,8))

    elif contains(line, {"Simulating", "vectors"}):
        insert_value(benchmarks, "number_of_vectors", get_token(line,2))	

    elif contains(line, {"Nodes:"}):
        insert_value(benchmarks, "number_of_nodes", get_token(line,2))	
        
    elif contains(line, {"Connections:"}):
        insert_value(benchmarks, "number_of_connections", get_token(line,2))

    elif contains(line, {"Threads:"}):
        insert_value(benchmarks, "used_threads", get_token(line,2))	

    elif contains(line, {"Degree:"}):
        insert_value(benchmarks, "degree", get_token(line,2))

    elif contains(line, {"Stages:"}):
        insert_value(benchmarks, "number_of_stages", get_token(line,2))

    elif contains(line, {"Simulation time:"}):
        insert_value(benchmarks, "simulation_time", time_to_millis(get_token(line,3)))

    elif contains(line, {"Elapsed time:"}):
        insert_value(benchmarks, "elapsed_time", time_to_millis(get_token(line,3)))

    elif contains(line, {"Coverage:"}):
        # get rid of the leading ( and trailing %)
        insert_value(benchmarks, "percent_coverage", get_token(line,3))

    elif contains(line, {"Odin ran with exit status:"}):
        insert_value(benchmarks, "exit_code", get_token(line,6))

    elif contains(line, {"Odin II took", "seconds", "(max_rss"}):
        input_str = get_token(line,4) + 's'
        insert_value(benchmarks, "total_time", time_to_millis(input_str))

        input_str = get_token(line,7) + get_token(line,8)
        insert_value(benchmarks, "max_rss", size_to_MiB(input_str))

    elif contains(line, {"context-switches"}):
        insert_value(benchmarks, "context_switches", get_token(line,1))

    elif contains(line, {"cpu-migrations"}):
        insert_value(benchmarks, "cpu_migration", get_token(line,1))

    elif contains(line, {"page-faults"}):
        insert_value(benchmarks, "page_faults", get_token(line,1))

    elif contains(line, {"stalled-cycles-frontend"}):
        insert_value(benchmarks, "stalled_cycle_frontend", get_token(line,1))

    elif contains(line, {"stalled-cycles-backend"}):
        insert_value(benchmarks, "stalled_cycle_backend", get_token(line,1))

    elif contains(line, {"cycles"}):
        insert_value(benchmarks, "cycles", get_token(line,1))

    elif contains(line, {"branches"}):
        insert_value(benchmarks, "branches", get_token(line,1))

    elif contains(line, {"branch-misses"}):
        insert_value(benchmarks, "branch_misses", get_token(line,1))

    elif contains(line, {"LLC-loads"}):
        insert_value(benchmarks, "llc_loads", get_token(line,1))

    elif contains(line, {"LLC-load-misses"}):
        insert_value(benchmarks, "llc_load_miss", get_token(line,1))

    elif contains(line, {"CPU:"}):
        insert_value(benchmarks, "percent_cpu_usage", get_token(line,2))

    elif contains(line, {"Minor PF:"}):
        insert_value(benchmarks, "minor_page_faults", get_token(line,3))


def main():
    benchmarks = {}

    if len(sys.argv) < 4:
        print("Wrong number of argument, expecting ./exec <input.log> <output.csv> <... (header value pair)>")
        exit(-1)

    log_file_to_parse = sys.argv[1]
    output_file = sys.argv[2]

    fileContext = open(log_file_to_parse, "r")

    for wholeLine in fileContext:
        parse_line(benchmarks, wholeLine)

    f = open(output_file,"w+")
    
    header_in = ""
    values_in = ""
    i = 0
    while i < (len(sys.argv)-3):
        header_in += sys.argv[i+3] + ","
        values_in += sys.argv[i+4] + ","
        i += 2

    header_in += ",".join(benchmarks.keys()) + "\n"
    values_in += ",".join(benchmarks.values()) + "\n"

    f.write(header_in)
    f.write(values_in)
    f.close() 

    exit(0)


if __name__ == "__main__":
    main()