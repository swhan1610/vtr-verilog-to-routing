#!/bin/bash

#!/bin/bash
#1
trap ctrl_c INT SIGINT SIGTERM
SHELL=/bin/bash
QUIT=0
FAILURE=0

##############################################
# grab the input args
INPUT=$@

##############################################
# grab the absolute Paths
THIS_SCRIPT=$(readlink -f $0)
THIS_SCRIPT_EXEC=$(basename ${THIS_SCRIPT})
THIS_SCRIPT_DIR=$(dirname ${THIS_SCRIPT})

ODIN_ROOT_DIR="$(readlink -f ${THIS_SCRIPT_DIR}/../..)"
ODIN_BENCHMARK_EXEC="${ODIN_ROOT_DIR}/verify_odin.sh"
BM_DIR="${ODIN_ROOT_DIR}/multithreaded_bm_results"
RESULT_DIR="${ODIN_ROOT_DIR}/regression_test"

function ctrl_c() {
	trap '' INT SIGINT SIGTERM
	QUIT=1
	while [ "${QUIT}" != "0" ]
	do
		echo "** Benchmark TEST EXITED FORCEFULLY **"
		pkill $(basename ${ODIN_BENCHMARK_EXEC}) &> /dev/null
		#should be dead by now
		exit 120
	done
}

exec_n_times() {
    EXEC_N_TIMES=$1
    BENCH_NAME=$2
    ARGS="${@:3}"

    /bin/bash -c "${ODIN_BENCHMARK_EXEC} --clean"

    for i in $(seq 1 1 ${EXEC_N_TIMES}); do
        /bin/bash -c "${ARGS}"
    done

    mkdir -p "${BM_DIR}/${BENCH_NAME}"

    for i in $(seq 1 1 ${EXEC_N_TIMES}); do
        mv "${RESULT_DIR}/run$(printf "%03d" ${i})" "${BM_DIR}/${BENCH_NAME}"
    done
}


EXECUTION_COUNT="4"
VECTOR_COUNT="3000"
TIMEOUT="7200"
NUMBER_OF_THREAD="30"
DEFAULT_ARGS="--test_name heavy_suite --perf --generate_bench --vectors ${VECTOR_COUNT} --timeout ${TIMEOUT} --best_coverage_off"

#################################################
# START !

exec_n_times "${EXECUTION_COUNT}" "single_thread" "${ODIN_BENCHMARK_EXEC} ${DEFAULT_ARGS}"

exec_n_times "${EXECUTION_COUNT}" "batch_thread" "${ODIN_BENCHMARK_EXEC} ${DEFAULT_ARGS} --sim_threads ${NUMBER_OF_THREAD} --batch_sim"

exec_n_times "${EXECUTION_COUNT}" "multi_thread" "${ODIN_BENCHMARK_EXEC} ${DEFAULT_ARGS} --sim_threads ${NUMBER_OF_THREAD}"