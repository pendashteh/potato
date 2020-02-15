#!/usr/bin/env bash

POTATO=1

# Helper functions to get the abolute path for the command
# Copyright http://stackoverflow.com/a/7400673/257479
myreadlink() { [ ! -h "$1" ] && echo "$1" || (local link="$(expr "$(command ls -ld -- "$1")" : '.*-> \(.*\)$')"; cd $(dirname $1); myreadlink "$link" | sed "s|^\([^/].*\)\$|$(dirname $1)/\1|"); }
whereis() { echo $1 | sed "s|^\([^/].*/.*\)|$(pwd)/\1|;s|^\([^/]*\)$|$(which -- $1)|;s|^$|$1|"; }
whereis_realpath() { local SCRIPT_PATH=$(whereis $1); myreadlink ${SCRIPT_PATH} | sed "s|^\([^/].*\)\$|$(dirname ${SCRIPT_PATH})/\1|"; }

[ ! -z "$POTATO_LOG" ] && __log_path="$POTATO_LOG" || __log_path="/dev/null"

POTATO_COMMAND_DEFAULT='default'

echo $0
[ -z "$POTATO_PATH" ] &&
	# This file is being executed directly from command line
	potato_root=$(dirname $(whereis_realpath "$0")) ||
		# This file is being sourced from .bashrc
		potato_root=$POTATO_PATH

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
