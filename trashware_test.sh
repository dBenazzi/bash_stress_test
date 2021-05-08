#!/bin/bash

#define params of stress test
STRESS_TIMEOUT="300s"
CPU_COUNT=$(nproc)
IO_COUNT=$(( CPU_COUNT * 2 ))
VM_COUNT=${CPU_COUNT}

# define temperatures at wich warnings are displayed
T_WARNING="75"
T_HIGH="85"

# utility variables
T_OK=0
MAX_T=0 # mi rifiuto di chiamarla t_max
INFO_MESSAGE=""

# launches stress test & checks sensors
function tests {
	(str) & sensor
}

# check for sensors and stress installed
function check {
	if ! command -v sensors &> /dev/null; then
		echo "sensors not installed. aborting..."
		exit -1
	fi
	if ! command -v stress &> /dev/null; then
		echo "stress not installed. aborting..."
		exit -1
	fi
}

#report results
function results {
	if [[ ${T_OK} == 0 ]]; then
		echo "test passed. temperatures are fine."
	else
		echo "test NOT passed. temperatures were too high"
	fi
	echo "max temperature reached: ${MAX_T}°C"
}

# stress test
function str {
	stress -t ${STRESS_TIMEOUT} -c ${CPU_COUNT} -i ${IO_COUNT} -m ${VM_COUNT}
}

# testing core temperatures
function sensor {
	# while stress is running
	while [[ $( ps | grep "stress" ) != "" ]]; do
		toasty=0
		temps_cores=""
		num_core=0
		# check for temperatures
		for temp in $( sensors | grep "Core" | cut -b 16-22 ); do
			#check temperature limit
			if [[ ${temp%%.*} -ge ${T_HIGH} ]]; then
				toasty=2
			elif [[ ${toasty} != "2" && ${temp%%.*} -ge ${T_WARNING} ]]; then
				toasty=1;
			fi
			temps_cores="${temps_cores}Core ${num_core}: ${temp} "
			(( num_core = ${num_core} + 1 ))
			# check max temperature
			if [[ ${temp%%.*} -gt ${MAX_T} ]]; then
				MAX_T=${temp%%.*}
			fi
		done
		clear
		# output results
		echo ${INFO_MESSAGE}
		if [[ ${toasty} -eq 2 ]]; then
			echo -n "temps not OK: "
			T_OK=1
		elif [[ ${toasty} -eq 1 ]]; then
			echo -n "warning temps mildly high: "
		else
			echo -n "temp OK: "
		fi
		echo ${temps_cores}
		echo "max temperature reached: ${MAX_T}°C"
		sleep 1
	done
	results
}

# message to be desplayed on each temp tick
function construct_info_message {
	INFO_MESSAGE="running test with: ${CPU_COUNT} cpu(s), ${IO_COUNT} io(s), ${VM_COUNT} vm(s)"
}

# optional:  auto-launch update if temps are ok
function apt_up {
	echo "launching updates. please type password."
	if [[ ${T_OK} == 0 ]]; then
		( sudo apt update && apt upgrade -y ) &
	fi
}

#main function
function main {
	check
	construct_info_message
	tests
	if [[ $# != 0 && $1 == "-u" ]]; then
		apt_up
	fi
}

main
