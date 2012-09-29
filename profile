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
# Sets B2G_PID to be the pid of the b2g process.
#
get_b2g_pid() {
   echo $($ADB shell 'toolbox ps b2g | (read header; read user pid rest; echo -n $pid)')
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
# Determines if the profiler is running for a given pid
#
# We use the traditional 0=success 1=failure return code.
#
is_profiler_running() {
  local pid=$1
  if [ -z "${pid}" ]; then
    return 1
  fi
  local status="$(${ADB} shell cat /proc/${pid}/environ | tr '\0' '\n' | grep 'MOZ_PROFILER_STARTUP=1')"
  if [ -z "${status}" ]; then
    return 1
  fi
  return 0
}

###########################################################################
#
# Capture the profiling information from a given process.
#
HELP["capture"]="Signals, pulls, and symbolicates the profile data"
cmd_capture() {
  cmd_signal $1
  get_comms
  declare -A local_filename
  local timestamp=$(date +"%H%M")
  if [ "${CMD_SIGNAL_PID:0:1}" == "-" ]; then
    # We signalled the entire process group. Pull and symbolicate
    # each file
    for pid in ${B2G_PIDS[*]}; do
      cmd_pull ${pid} ${B2G_COMMS[${pid}]} ${timestamp}
      local_filename[${pid}]=${CMD_PULL_LOCAL_FILENAME}
    done
    echo
    for filename in ${local_filename[*]}; do
      cmd_symbolicate ${filename}
    done
  else
    cmd_pull ${CMD_SIGNAL_PID} ${B2G_COMMS[${CMD_SIGNAL_PID}]}
    cmd_symbolicate ${CMD_PULL_LOCAL_FILENAME}
  fi
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
  local status
  get_comms
  echo "  PID Name"
  echo "----- ----------------"
  for pid in ${B2G_PIDS[*]}; do
    if is_profiler_running ${pid}; then
      status="profiler running"
    else
      status="profiler not running"
    fi
    printf "%5d %-16s %s\n" "${pid}" "${B2G_COMMS[${pid}]}" "${status}"
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
  local label=$3

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
  elif [ -z "${label}" ]; then
    local_filename="profile_${pid}_${B2G_COMMS[${pid}]}.txt"
  else
    local_filename="profile_${label}_${pid}_${B2G_COMMS[${pid}]}.txt"
  fi

  echo -n "Waiting for profile file for ${pid}:${B2G_COMMS[${pid}]} to stabilize ..."
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
  local filesize
  local stabilized=0
  for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    curr_ls=$(${ADB} shell "ls -l ${profile_pattern}")
    # Android's ls -l output looks like:
    #   -rw-rw-rw- root     root      2078953 2012-09-28 15:14 profile_0_4601.txt
    # if the file exists, or
    #   /data/local/tmp/profile_?_4601.txt: No such file or directory
    # if it doesn't. In the first case, field[3] corresponds to the file size. In
    # the second case fields[3] will contain the word "file"
    local fields=(${curr_ls})
    filesize=${fields[3]}
    if [ "${prev_ls}" != "${curr_ls}" -o "${filesize}" == "0" -o "${filesize}" == "file" ]; then
      prev_ls=${curr_ls}
      echo -n "."
      echo -n "${filesize}"
      matches=0
    else
      echo -n "+"
      matches=$(( ${matches} + 1 ))
      if [ ${matches} -ge 5 ]; then
        # If the filesize hasn't changed in 5 seconds then we consider
        # the file to be stabilized.
        stabilized=1
        break
      fi
    fi
    sleep 1
  done
  echo
  if [ "${stabilized}" == "0" ]; then
    # Whoops. The process probably got killed (due to OOM) by trying to
    # collect the profile file. Skip it.
    echo "Whoops. Looks like ${pid}:${B2G_COMMS[${pid}]} is gone. Skipping..."
    CMD_PULL_LOCAL_FILENAME=
    return
  fi

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
  local pid
  if [ -z "$1" ]; then
    # If no pid is specified, then send a signal to the b2g process group.
    # This will cause the signal to go to b2g and all of it subprocesses.
    pid=-$(find_pid b2g)
    echo "Signalling Process Group: ${pid:1} ${B2G_COMMS[${pid:1}]} ..."
  else
    pid=$(find_pid $1)
    if [ "${pid}" == "" ]; then
      echo "Must specify a PID or process-name to capture"
      cmd_ps
      exit 1
    fi
    echo "Signalling PID: ${pid} ${B2G_COMMS[${pid}]} ..."
  fi

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
  echo -n "Starting b2g with profiling enabled ..."
  # Use nohup or we may accidentally kill the adb shell when this
  # script exits.
  nohup ${ADB} shell "MOZ_PROFILER_STARTUP=1 /system/bin/b2g.sh > /dev/null" > /dev/null 2>&1 &
  echo " started"
}

###########################################################################
#
# Stop profiling and start b2g normally
#
HELP["stop"]="Stops profiling and restarts b2g normally."
cmd_stop() {
  stop_b2g
  echo "Restarting b2g (normally) ..."
  ${ADB} shell start b2g
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
  if is_profiler_running $(get_b2g_pid); then
    echo -n "Profiler appears to be running."
  else
    # Note: stop sends SIGKILL, but only if b2g was launched via start
    # If b2g was launched via the debugger or the profiler, then stop is
    # essentially a no-op
    echo -n "Stopping b2g ..."
    ${ADB} shell "stop b2g"
    for attempt in 1 2 3 4 5; do
      pid=$(${ADB} shell 'toolbox ps b2g | (read header; read user pid rest; echo -n ${pid})')
      if [ "${pid}" == "" ]; then
        break
      fi
      echo -n "."
      sleep 1
    done
  fi

  # Now do a cleanup check and make sure that all of the b2g pids are actually gone
  clear_pids
  get_pids
  if [ "${#B2G_PIDS[*]}" -gt 0 ]; then
    echo
    echo -n "Killing b2g ..."
    for pid in ${B2G_PIDS[*]}; do
      ${ADB} shell "kill -9 ${pid}"
    done
    for attempt in 1 2 3 4 5; do
      clear_pids
      get_pids
      if [ "${#B2G_PIDS[*]}" == 0 ]; then
        break
      fi
      echo -n "."
      sleep 1
    done
  fi

  # And if things still haven't shutdown, then give up
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

