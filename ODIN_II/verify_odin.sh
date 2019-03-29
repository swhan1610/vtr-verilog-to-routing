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

ODIN_ROOT_DIR=$(dirname ${THIS_SCRIPT})
REGRESSION_DIR="${ODIN_ROOT_DIR}/regression_test"
BENCHMARK_DIR="${REGRESSION_DIR}/benchmark"
TEST_DIR_LIST=$(find ${BENCHMARK_DIR} -mindepth 1 -maxdepth 1 -type d | cut -d '/' -f 3 | tr '\n' ' ')  
NEW_RUN_DIR=${REGRESSION_DIR}/run001

##############################################
# Arch Sweep Arrays to use during benchmarking
DEFAULT_ARCH="${ODIN_ROOT_DIR}/../libs/libarchfpga/arch/sample_arch.xml"
MEM_ARCH="${ODIN_ROOT_DIR}/../vtr_flow/arch/timing/k6_N10_mem32K_40nm.xml"
SMALL_ARCH_SWEEP="${DEFAULT_ARCH} ${MEM_ARCH}"
FULL_ARCH_SWEEP=$(find ${ODIN_ROOT_DIR}/../vtr_flow/arch/timing -maxdepth 1 | grep xml)

##############################################
# Include more generic names here for better vector generation
HOLD_LOW="-L reset rst"
HOLD_HIGH="-H we"
HOLD_PARAM="${HOLD_LOW} ${HOLD_HIGH}"

##############################################
# Exit Functions
function exit_program() {

	if [ "_${FAILURE}" != "_0" ]
	then
		echo "Failed ${FAILURE} benchmarks"
		echo "View Failure log in ${NEW_RUN_DIR}/test_failures.log"

	else
		echo "no run failure!"
	fi

	exit ${FAILURE}
}

function ctrl_c() {
	QUIT=1
	while [ "${QUIT}" != "0" ]
	do
		echo "** REGRESSION TEST EXITED FORCEFULLY **"
		jobs -p | xargs kill &> /dev/null
		pkill odin_II &> /dev/null
		pkill ${THIS_SCRIPT_EXEC} &> /dev/null
		#should be dead by now
		exit 120
	done
}

##############################################
# Help Print helper
function help() {
printf "
	Called program with $INPUT
	Usage: 
		./verify_odin [ OPTIONS / FLAGS ]

		-h|--help                                     print this

	OPTIONS:
		-t|--test < test name >         [ null ]      Test name is one of ( ${TEST_DIR_LIST} heavy_suite light_suite full_suite vtr_basic vtr_strong pre_commit )
		-j|--nb_of_process < N >        [ 1 ]         Number of process requested to be used
		-s|--sim_threads < N >          [ 1 ]         Use multithreaded simulation using N threads
		-V|--vectors < N >              [ 100 ]       Use N vectors to generate per simulation
		-T|--timeout < N sec >          [ 1200 ]      Timeout a simulation/synthesis after N seconds
		-a|--adder_def < /abs/path >    [ default ]   Use template to build adders

	FLAGS:
		-g|--generate_bench             [ off ]       Generate input and output vector for test
		-o|--generate_output            [ off ]       Generate output vector for test given its input vector
		-c|--clean                      [ off ]       Clean temporary directory
		-l|--limit_ressource            [ off ]       Force higher nice value and set hard limit for hardware memory to force swap more ***not always respected by system
		-v|--valgrind                   [ off ]       Run with valgrind
		-B|--best_coverage_off          [ on ]        Generate N vectors from --vector size batches until best node coverage is achieved
		-b|--batch_sim                  [ off ]       Use Batch mode multithreaded simulation

"
}

function config_help() {
printf "
	config.txt expects a single line of argument wich can be one of:
				--custom_args_file
				--arch_list	[list_name]*
								*memories        use VTR k6_N10_mem32k architecture
								*small_sweep     use a small set of timing architecture
								*full_sweep  	 sweep the whole vtr directory *** WILL FAIL ***
								*default         use the sample_arch.xml
				--simulate                       request simulation to be ran
				--no_threading                   do not use multithreading for this test ** useful if you have large test **
"
}

###############################################
# Time Helper Functions
function get_current_time() {
	echo $(date +%s%3N)
}

# needs start time $1
function print_time_since() {
	BEGIN=$1
	NOW=`get_current_time`
	TIME_TO_RUN=$(( ${NOW} - ${BEGIN} ))

	Mili=$(( ${TIME_TO_RUN} %1000 ))
	Sec=$(( ( ${TIME_TO_RUN} /1000 ) %60 ))
	Min=$(( ( ( ${TIME_TO_RUN} /1000 ) /60 ) %60 ))
	Hour=$(( ( ( ${TIME_TO_RUN} /1000 ) /60 ) /60 ))

	echo "ran test in: $Hour:$Min:$Sec.$Mili"
}

################################################
# Init Directories and cleanup
function init_temp() {
	last_run=$(find ${REGRESSION_DIR}/run* -maxdepth 0 -type d 2>/dev/null | tail -1 )
	if [ "_${last_run}" != "_" ]
	then
		last_run_id=${last_run##${REGRESSION_DIR}/run}
		n=$(echo $last_run_id | awk '{print $0 + 1}')
		NEW_RUN_DIR=${REGRESSION_DIR}/run$(printf "%03d" $n)
	fi
	echo "running benchmark @${NEW_RUN_DIR}"
	mkdir -p ${NEW_RUN_DIR}
}

function cleanup_temp() {
	for runs in ${REGRESSION_DIR}/run*
	do 
		rm -Rf ${runs}
	done
}

function mv_failed() {
	failed_dir=$1
	log_file="${failed_dir}.log"

	if [ -e ${log_file} ]
	then
		echo "Failed benchmark have been move to ${failed_dir}"
		for failed_benchmark in $(cat ${log_file})
		do
			parent_dir=$(dirname ${failed_dir}/${failed_benchmark})
			mkdir -p ${parent_dir}
			mv ${NEW_RUN_DIR}/${failed_benchmark} ${parent_dir}
			FAILURE=$(( ${FAILURE} + 1 ))
		done
		cat ${log_file} >> ${NEW_RUN_DIR}/test_failures.log
		rm -f ${log_file}
	fi
}

#########################################
# Helper Functions
function flag_is_number() {
	case "_$2" in
		_) 
			echo "Passed an empty value for $1"
			help
			exit 120
		;;
		*)
			case $2 in
				''|*[!0-9]*) 
					echo "Passed a non number value [$2] for $1"
					help
					exit 120
				;;
				*)
					echo $2
				;;
			esac
		;;
	esac
}

##############
# defaults
_TEST=""
_NUMBER_OF_PROCESS="1"
_SIM_THREADS="1"
_VECTORS="100"
_TIMEOUT="1200"
_ADDER_DEF="default"

_GENERATE_BENCH="off"
_GENERATE_OUTPUT="off"
_LIMIT_RESSOURCE="off"
_VALGRIND="off"
_BEST_COVERAGE_OFF="on"
_BATCH_SIM="off"

# boolean type flags
_low_ressource_flag=""
_valgrind_flag=""
_batch_sim_flag=""
_use_best_coverage_flag=""

# number type flags
_vector_flag=""
_timeout_flag=""
_simulation_threads_flag=""

_adder_definition_flag=""

function _set_if() {
	[ "$1" == "on" ] && echo "$2" || echo ""
}

function _set_flag() {
	_low_ressource_flag=$(_set_if ${_LIMIT_RESSOURCE} "--limit_ressource")
	_valgrind_flag=$(_set_if ${_LIMIT_RESSOURCE} "--valgrind")
	_batch_sim_flag=$(_set_if ${_LIMIT_RESSOURCE} "--batch")
	_use_best_coverage_flag=$(_set_if ${_LIMIT_RESSOURCE} "--best_coverage")
	
	_vector_flag="-g ${_VECTORS}"
	_timeout_flag="--time_limit ${_TIMEOUT}s"
	_simulation_threads_flag=$([ "${_SIM_THREADS}" != "1" ] && echo "-j ${_SIM_THREADS}")

	_adder_definition_flag="--adder_type ${_ADDER_DEF}"

}

function parse_args() {
	while [[ "$#" > 0 ]]
	do 
		case $1 in 

		# Help Desk
			-h|--help)
				echo "Printing Help information"
				help
				exit_program
			
		## directory in benchmark
			;;-t|--test)
				# this is handled down stream
				if [ "_$2" == "_" ]; then 
					echo "empty argument for $1"
					exit 120
				fi

				_TEST="$2"
				echo "Running test $2"
				shift

		## absolute path
			;;-a|--adder_def)

				if [ "_$2" == "_" ]; then 
					echo "empty argument for $1"
					exit 120
				fi
				
				_ADDER_DEF=$2

				if [ "${_ADDER_DEF}" != "default" ] && [ "${_ADDER_DEF}" != "optimized" ] && [ ! -f "$(readlink -f ${_ADDER_DEF})" ]; then
					echo "invalid adder definition passed in ${_ADDER_DEF}"
					exit 120
				fi

				shift

		## number
			;;-j|--nb_of_process)
				_NUMBER_OF_PROCESS=$(flag_is_number $1 $2)
				echo "Using timeout [$2] for synthesis and simulation"
				shift

			;;-s|--sim_threads)
				_SIM_THREADS=$(flag_is_number $1 $2)
				echo "Using timeout [$2] for synthesis and simulation"
				shift

			;;-V|--vectors)
				_VECTORS=$(flag_is_number $1 $2)
				echo "Using timeout [$2] for synthesis and simulation"
				shift

			;;-T|--timeout)
				_TIMEOUT=$(flag_is_number $1 $2)
				echo "Using timeout [$2] for synthesis and simulation"
				shift

		# Boolean flags
			;;-g|--generate_bench)		
				_GENERATE_BENCH="on"
				echo "generating output vector for test given predefined input"

			;;-o|--generate_output)		
				_GENERATE_OUTPUT="on"
				echo "generating input and output vector for test"

			;;-c|--clean)				
				echo "Cleaning temporary run in directory"
				cleanup_temp

			;;-l|--limit_ressource)		
				_LIMIT_RESSOURCE="on"
				echo "limiting ressources for benchmark, this can help with small hardware"

			;;-v|--valgrind)			
				_VALGRIND="on"
				echo "Using Valgrind for benchmarks"

			;;-B|--best_coverage_off)	
				_BEST_COVERAGE_OFF="off"
				echo "turning off using best coverage for benchmark vector generation"

			;;-b|--batch_sim)			
				_BATCH_SIM="on"
				echo "Using Batch multithreaded simulation with -j threads"
			;;*) 
				echo "Unknown parameter passed: $1"
				help 
				ctrl_c
		esac
		shift
	done
}


function sim() {

	####################################
	# parse the function commands passed
	with_custom_args="0"
	arch_list="no_arch"
	with_sim="0"
	threads=${_NUMBER_OF_PROCESS}
	DEFAULT_CMD_PARAM="${_adder_definition_flag} ${_simulation_threads_flag} ${_batch_sim_flag}"


	if [ ! -e "$1" ]; then
		echo "invalid benchmark directory passed to simulation function $1"
		ctrl_c
	fi
	benchmark_dir="$1"
	shift

	while [[ "$#" > 0 ]]
	do 
		case $1 in
			--custom_args_file) 
				with_custom_args=1
				;;

			--arch_list)
				case $2 in
					memories)
						arch_list="${MEM_ARCH}"
						;;

					small_sweep)
						arch_list="${SMALL_ARCH_SWEEP}"
						;;

					full_sweep)
						arch_list="${FULL_ARCH_SWEEP}"
						;;

					default)
						arch_list="${DEFAULT_ARCH}"
						;;
					*)
						;;
				esac
				shift
				;;

			--simulate)
				with_sim=1
				;;

			--no_threading)
				echo "This test will not be multithreaded"
				threads="1"
				;;

			*)
				echo "Unknown internal parameter passed: $1"
				config_help 
				ctrl_c
				;;
		esac
		shift
	done

	###########################################
	# run custom benchmark
	bench_type=${benchmark_dir##*/}
	echo " BENCHMARK IS: ${bench_type}"

	if [ "_${with_custom_args}" == "_1" ]; then

		global_odin_failure="${NEW_RUN_DIR}/odin_failures"

		for dir in ${benchmark_dir}/*
		do
			if [ -e ${dir}/odin.args ]; then
				test_name=${dir##*/}
				TEST_FULL_REF="${bench_type}/${test_name}"

				DIR="${NEW_RUN_DIR}/${bench_type}/$test_name"
				blif_file="${DIR}/odin.blif"


				#build commands
				mkdir -p $DIR
				wrapper_odin_command="./wrapper_odin.sh
											--log_file ${DIR}/odin.log
											--test_name ${TEST_FULL_REF}
											--failure_log ${global_odin_failure}.log
											${_timeout_flag}
											${_low_ressource_flag}
											${RUN_WITH_VALGRIND}"

				odin_command="${DEFAULT_CMD_PARAM}
								$(cat ${dir}/odin.args | tr '\n' ' ') 
								-o ${blif_file} 
								-sim_dir ${DIR}"

				echo $(echo "${wrapper_odin_command} ${odin_command}" | tr '\n' ' ' | tr -s ' ' ) > ${DIR}/odin_param
			fi
		done

		#run the custon command
		echo " ========= Synthesizing Circuits"
		find ${NEW_RUN_DIR}/${bench_type}/ -name odin_param | xargs -n1 -P$threads -I test_cmd ${SHELL} -c '$(cat test_cmd)'
		mv_failed ${global_odin_failure}

	############################################
	# run benchmarks
	else

		global_synthesis_failure="${NEW_RUN_DIR}/synthesis_failures"
		global_simulation_failure="${NEW_RUN_DIR}/simulation_failures"

		for benchmark in ${benchmark_dir}/*.v
		do
			basename=${benchmark%.v}
			test_name=${basename##*/}

			input_vector_file="${basename}_input"
			output_vector_file="${basename}_output"

			for arches in ${arch_list}
			do

				arch_cmd=""
				if [ -e ${arches} ]
				then
					arch_cmd="-a ${arches}"
				fi

				arch_basename=${arches%.xml}
				arch_name=${arch_basename##*/}

				TEST_FULL_REF="${bench_type}/${test_name}/${arch_name}"

				DIR="${NEW_RUN_DIR}/${TEST_FULL_REF}"
				blif_file="${DIR}/odin.blif"


				#build commands
				mkdir -p $DIR

				wrapper_synthesis_command="./wrapper_odin.sh
											--log_file ${DIR}/synthesis.log
											--test_name ${TEST_FULL_REF}
											--failure_log ${global_synthesis_failure}.log
											${_timeout_flag}
											${_low_ressource_flag}
											${RUN_WITH_VALGRIND}"

				synthesis_command="${DEFAULT_CMD_PARAM}
									${arch_cmd}
									-V ${benchmark}
									-o ${blif_file}
									-sim_dir ${DIR}"

				echo $(echo "${wrapper_synthesis_command} ${synthesis_command}"  | tr '\n' ' ' | tr -s ' ') > ${DIR}/cmd_param

				if [ "_$with_sim" == "_1" ] || [ -e ${input_vector_file} ]
				then
					#force trigger simulation if input file exist
					with_sim="1"

					wrapper_simulation_command="./wrapper_odin.sh
											--log_file ${DIR}/simulation.log
											--test_name ${TEST_FULL_REF}
											--failure_log ${global_simulation_failure}.log
											${_timeout_flag}
											${_low_ressource_flag}
											${RUN_WITH_VALGRIND}"

					simulation_command="${DEFAULT_CMD_PARAM}
											${arch_cmd}
											-b ${blif_file}
											-sim_dir ${DIR}
											${HOLD_PARAM}"

					if [ "${_GENERATE_BENCH}" == "on" ]; then
						simulation_command="${simulation_command} ${_use_best_coverage_flag} ${_vector_flag}"

					elif [ -e ${input_vector_file} ]; then
						simulation_command="${simulation_command} -t ${input_vector_file}"

						if [ "${_GENERATE_OUTPUT}" != "on" ] && [ -e ${output_vector_file} ]; then
							simulation_command="${simulation_command} -T ${output_vector_file}"
						fi
						
					else
						simulation_command="${simulation_command} ${_vector_flag}"

					fi

					echo $(echo "${wrapper_simulation_command} ${simulation_command}" | tr '\n' ' ' | tr -s ' ') > ${DIR}/sim_param
				fi
			done
		done

		#synthesize the circuits
		echo " ========= Synthesizing Circuits"
		find ${NEW_RUN_DIR}/${bench_type}/ -name cmd_param | xargs -n1 -P$threads -I test_cmd ${SHELL} -c '$(cat test_cmd)'
		mv_failed ${global_synthesis_failure}

		if [ "_$with_sim" == "_1" ]
		then
			#run the simulation
			echo " ========= Simulating Circuits"
			find ${NEW_RUN_DIR}/${bench_type}/ -name sim_param | xargs -n1 -P$threads -I sim_cmd ${SHELL} -c '$(cat sim_cmd)'
			mv_failed ${global_simulation_failure}
		fi

	fi
	

}

HEAVY_LIST=(
	"syntax"
	"full"
	"large"
)

LIGHT_LIST=(
	"operators"
	"arch"
	"other"
	"micro"
)

function run_light_suite() {
	for test_dir in ${LIGHT_LIST[@]}; do
		sim ${BENCHMARK_DIR}/${test_dir} $(cat ${BENCHMARK_DIR}/${test_dir}/config.txt)
	done
}

function run_heavy_suite() {
	for test_dir in ${HEAVY_LIST[@]}; do
		sim ${BENCHMARK_DIR}/${test_dir} $(cat ${BENCHMARK_DIR}/${test_dir}/config.txt)
	done
}

function run_all() {
	run_light_suite
	run_heavy_suite
}

#########################################################
#	START HERE

START=`get_current_time`

parse_args $INPUT
_set_flag

if [ "_${_TEST}" == "_" ]; then
	echo "No input test!"
	help
	print_time_since $START
	exit_program
fi

init_temp
echo "Benchmark is: ${_TEST}"
case "${_TEST}" in

	"full_suite")
		run_all
		;;	
		
	"heavy_suite")
		run_heavy_suite
		;;

	"light_suite")
		run_light_suite
		;;

	"vtr_basic")
		cd ..
		/usr/bin/perl run_reg_test.pl -j ${_NUMBER_OF_PROCESS} vtr_reg_basic
		cd ODIN_II
		;;

	"vtr_strong")
		cd ..
		/usr/bin/perl run_reg_test.pl -j ${_NUMBER_OF_PROCESS} vtr_reg_strong
		cd ODIN_II
		;;

	"pre_commit")
		run_all
		cd ..
		/usr/bin/perl run_reg_test.pl -j ${_NUMBER_OF_PROCESS} vtr_reg_basic
		/usr/bin/perl run_reg_test.pl -j ${_NUMBER_OF_PROCESS} vtr_reg_strong
		cd ODIN_II
		;;

	*)
		if [ ! -e ${BENCHMARK_DIR}/${_TEST} ]; then
			echo "${BENCHMARK_DIR}/${_TEST} Not Found! exiting."
			config_help
			ctrl_c
		fi

		if [ ! -e ${BENCHMARK_DIR}/${_TEST}/config.txt ]; then
			echo "no config file found in the directory."
			echo "please make sure a config.txt exist"
			config_help
			ctrl_c
		fi

		sim ${BENCHMARK_DIR}/${_TEST} $(cat ${BENCHMARK_DIR}/${_TEST}/config.txt)
		;;
esac

print_time_since $START

exit_program
### end here
