#!/bin/bash

SCRIPT_NAME=$(basename $0)

ADB=adb
PROFILE_DIR=/data/local/tmp

# The get_pids function populates B2G_PIDS as an array containting the PIDs
# of all of the b2g processes
declare -a B2G_PIDS

# The get_comms function populates B2G_COMMS as an associative array mapping
# pids to comms (process names). get_comms also causes B2G_PIDS to be populated.
declare -A B2G_COMMS

declare -A HELP

###########################################################################
#
# Clears the B2G_PIDS, which will force the information to be refetched.
#
clear_pids() {
  unset B2G_PIDS
  unset B2G_COMMS
}

###########################################################################
#
# Takes a pid or process name, and tries to determine the PID (only accepts
# PIDs which are associated with a b2g process)
#
find_pid() {
  local search=$1
  get_comms
  for pid in ${B2G_PIDS[*]}; do
    if [ "${search}" == "${pid}" -o "${search}" == "${B2G_COMMS[${pid}]}" ]; then
      echo -n "${pid}"
      return
    fi
  done
}

###########################################################################
#
# Fill B2G_PIDS with an array of b2g process PIDs
#
get_pids() {
  if [ ${#B2G_PIDS[*]} -gt 0 ]; then
    # We've already populated B2G_PIDS, don't bother doing it again
    return
  fi

  B2G_PIDS=($(${ADB} shell ps | while read line; do
    if [ "${line/*b2g*/b2g}" = "b2g" ]; then
      echo ${line} | (
        read user pid rest;
        echo -n "${pid} "
      )
    fi
  done))
}

###########################################################################
#
# Fill B2G_COMMS such that B2G_COMMS[pid] contains the process name.
#
get_comms() {
  if [ ${#B2G_COMMS[*]} -gt 0 ]; then
    # We've already populated B2G_COMMS, don't bother doing it again
    return
  fi
  get_pids
  for pid in ${B2G_PIDS[*]}; do
    # adb shell seems to replace the \n with a \r, so we use
    # tr to strip trailing newlines or CRs
    B2G_COMMS[${pid}]=$(${ADB} shell cat /proc/${pid}/comm | tr -d '\r\n')
  done
}

###########################################################################
#
# Capture the profiling information from a given process.
#
HELP["capture"]="Signals, pulls, and symbolicates the profile data"
cmd_capture() {
  cmd_signal $1
  cmd_pull ${CMD_SIGNAL_PID} ${B2G_COMMS[${CMD_SIGNAL_PID}]}
  cmd_symbolicate ${CMD_PULL_LOCAL_FILENAME}
}

###########################################################################
#
# Display a brief help message for each supported command
#
HELP["help"]="Shows these help messages"
cmd_help() {
  if [ "$1" == "" ]; then
    echo "Usage: ${SCRIPT_NAME} command [args]"
    echo "where command is one of:"
    for command in ${allowed_commands}; do
      printf "  %-10s %s\n" ${command} "${HELP[${command}]}"
    done
  else
    command=$1
    if [ "${allowed_commands/*${command}*/${command}}" == "${command}" ]; then
      printf "%-10s %s\n" ${command} "${HELP[${command}]}"
    else
      echo "Unrecognized command: '${command}'"
    fi
  fi
}

###########################################################################
#
# Show all of the profile files on the phone
#
HELP["ls"]="Shows the profile files on the phone"
cmd_ls() {
  ${ADB} shell "cd ${PROFILE_DIR}; ls -l profile_?_*.txt"
}

###########################################################################
#
# Show all of the b2g processes which are currently running.
#
HELP["ps"]="Shows the B2G processes"
cmd_ps() {
  get_comms
  echo "  PID Name"
  echo "----- ----------------"
  for pid in ${B2G_PIDS[*]}; do
    printf "%5d %s\n" "${pid}" "${B2G_COMMS[${pid}]}"
  done
}

###########################################################################
#
# Pulls the profile file from the phone
#
HELP["pull"]="Pulls the profile data from the phone"
cmd_pull() {
  local pid=$1
  local comm=$2

  # The profile data gets written to /data/local/tmp/profile_X_PID.txt
  # where X is the XRE_ProcessType (so 0 for the b2g process, 2 for
  # the plugin containers).
  #
  # We know the PID, so we look for the file, and we wait for it to
  # stabilize.

  local attempt
  local profile_filename
  local profile_pattern="${PROFILE_DIR}/profile_?_${pid}.txt"
  local local_filename
  if [ -z "${comm}" ]; then
    local_filename="profile_${pid}.txt"
  else
    local_filename="profile_${pid}_${B2G_COMMS[${pid}]}.txt"
  fi

  echo -n "Waiting for profile file to stabilize ..."
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    profile_filename=$(${ADB} shell "echo -n ${profile_pattern}")
    if [ "${profile_filename}" == "${profile_pattern}" ]; then
      echo -n "."
      sleep 1
    else
      break
    fi
  done
  if [ "${profile_filename}" == "${profile_pattern}" ]; then
    echo
    echo "Profiler doesn't seem to have created file: '${profile_pattern}'"
    echo "Did you build with B2G_PROF=1 in your .userconfig ?"
    exit 1
  fi
  local prev_ls
  local matches=0
  while true; do
    curr_ls=$(${ADB} shell "ls -l ${profile_pattern}")
    if [ "${prev_ls}" != "${curr_ls}" ]; then
      prev_ls=${curr_ls}
      echo -n "."
      sleep 1
      matches=0
    else
      matches=$(( ${matches} + 1 ))
      if [ ${matches} -ge 5 ]; then
        # If the filesize hasn't changed in 5 seconds then we consider
        # the file to be stabilized.
        break
      fi
    fi
  done
  echo

  echo "Pulling ${profile_filename} into ${local_filename}"
  ${ADB} pull ${profile_filename} ${local_filename}
  CMD_PULL_LOCAL_FILENAME=${local_filename}
}

###########################################################################
#
# Signal the profiler to generate the profile data
#
HELP["signal"]="Signal the profiler to generate profile data"
cmd_signal() {
  # Call get_comms here since we need it later. find_pid is launched in
  # a sub-shell since we want the echo'd output which means we won't
  # see the results when it calls get_comms, but if we call get_comms,
  # then find_pid will see the results of us calling get_comms.
  get_comms
  local pid=$(find_pid $1)
  if [ "${pid}" == "" ]; then
    echo "Must specify a PID or process-name to capture"
    cmd_ps
    exit 1
  fi

  echo "Signalling PID: ${pid} ${B2G_COMMS[${pid}]} ..."
  ${ADB} shell "kill -12 ${pid}"
  CMD_SIGNAL_PID=${pid}
}

###########################################################################
#
# Start b2g with the profiler enabled.
#
HELP["start"]="Starts the profiler"
cmd_start() {
  stop_b2g
  # If we try to start b2g immediately after stopping it, then it typically
  # doesn't start. Adding a small sleep seems to work.
  sleep 1

  echo -n "Starting b2g with profiling enabled ..."
  ${ADB} shell "MOZ_PROFILER_STARTUP=1 /system/bin/b2g.sh > /dev/null" &
  echo " started"
}

###########################################################################
#
# Add symbols to a captured profile using the libraries from our build
# tree.
#
HELP["symbolicate"]="Add symbols to a captured profile"
cmd_symbolicate() {
  local profile_filename=$1
  if [ -z "${profile_filename}" ]; then
    echo "Expecting the filename containing the profile data"
    exit 1
  fi
  if [ ! -f "${profile_filename}" ]; then
    echo "File ${profile_filename} doesn't exist"
    exit 1
  fi

  # Get some variables from the build system
  local var_profile="./.var.profile"
  if [ ! -f ${var_profile} ]; then
    echo "Unable to locate ${var_profile}"
    echo "You need to build b2g in order to get symbolic information"
    exit 1
  fi
  source ${var_profile}

  local sym_filename=${profile_filename%.*}.sym
  echo "Adding symbols to ${profile_filename} and creating ${sym_filename} ..."
  ./scripts/profile-symbolicate.py -o ${sym_filename} ${profile_filename}
}

###########################################################################
#
# Tries to stop b2g
#
stop_b2g() {
  local pid
  local attempt
  echo -n "Stopping b2g ..."
  ${ADB} shell "stop b2g"
  for attempt in 1 2 3 4 5; do
    pid=$(${ADB} shell 'toolbox ps b2g | (read header; read user pid rest; echo -n ${pid})')
    if [ "${pid}" != "" ]; then
        echo -n "."
        sleep 1
    fi
  done
  if [ "${pid}" != "" ]; then
    echo
    echo -n "b2g doesn't seem to be responding to stop. Being more forceful."
    ${ADB} shell "kill ${pid}"
    for attempt in 1 2 3; do
      pid=$(${ADB} shell 'toolbox ps b2g | (read header; read user pid rest; echo -n ${pid})')
      if [ "${pid}" != "" ]; then
          echo -n "."
          sleep 1
      fi
    done
  fi
  clear_pids
  get_pids
  if [ "${#B2G_PIDS[*]}" -gt 0 ]; then
    echo
    echo "b2g doesn't seem to be responding to kill. Being even more forceful."
    for pid in ${B2G_PIDS[*]}; do
      ${ADB} shell "kill -9 ${pid}"
    done
    sleep 1
  fi
  clear_pids
  get_pids
  if [ "${#B2G_PIDS[*]}" -gt 0 ]; then
    echo
    echo "b2g doesn't seem to want to go away. Try rebooting."
    exit 1
  fi
  echo " stopped."
}

###########################################################################
#
# Determine if the first argument is a valid command and execute the
# corresponding function if it is.
#
allowed_commands=$(declare -F | sed -ne 's/declare -f cmd_\(.*\)/\1/p' | tr "\n" " ")
command=$1
if [ "${command}" == "" ]; then
  cmd_help
  exit 0
fi
if [ "${allowed_commands/*${command}*/${command}}" == "${command}" ]; then
  shift
  cmd_${command} "$@"
else
  echo "Unrecognized command: '${command}'"
fi

