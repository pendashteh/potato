#!/usr/bin/env bash

POTATO=1

[ ! -z "$POTATO_LOG" ] && __log_path="$POTATO_LOG" || __log_path="/dev/null"

POTATO_COMMAND_DEFAULT='default'

function potato_source_all() {
	local __file_pattern=$1
	[ -e $__file_pattern ] && for f in $__file_pattern; do source $f; done
}

function potato_run() {
	local task=""
	local task_args="${@:2}"
  [ ! -z "$1" ] && task="$1" || task=$POTATO_COMMAND_DEFAULT

	task_script_path=$potato_root/tasks/$task
	if [ ! -e "$task_script_path" ]
		then
		echo "Potato task '$task' not found at $task_script_path"
		exit 1
	fi
	. $task_script_path $task_args
}

# @TODO find out if it is possible to set a variable for printing on screen
set | grep POTATO_LOG
[ ! -z "$POTATO_LOG" ] && __log_path="$POTATO_LOG" || __log_path="/dev/null"

# @example potato_set_env POTATO_LOG __log_path /dev/null
#function potato_set_env() {}
#echo "[INFO] 'deploy' in use." >> $__log_path
