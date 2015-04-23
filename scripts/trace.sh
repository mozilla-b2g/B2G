#!/bin/sh

###############################################################################
# Option variables

opt_adb=adb
opt_adb_device=
opt_buffer_size=2048
opt_keep=no
opt_trace_name=trace.log
action=

###############################################################################
# Globals

ADB= # adb command complete with parameters

###############################################################################
# Print the help message

print_help() {
    printf "Usage: `basename $0` [OPTION...] [ACTION]
Traces application running on the phone.

Tracing is enabled by invoking the script with the --start command. The device
can be disconnected after this point. Once the trace is stopped with the --stop
a summary of the applications having run in the meantime is printed out.

Actions:
  -h, --help            Show this help message
  -s, --start           Start tracing
  -t, --stop            Stop tracing and pull the trace

Application options:
  -b, --buffer-size     Size of the tracing buffer in KiB
  -k, --keep            Don't delete the trace

ADB options:
  --adb                 Path to the adb command (default: $opt_adb)
  --emulator            Trace the emulator
  --device [serial]     Trace a device (the serial number is optional)
"
}

suggest_help() {
    printf "Try \``basename $0` --help' for more information\n"
}

###############################################################################
# Parse the program arguments

parse_args() {
    # If no arguments were given print the help message
    if [ $# -eq 0 ]; then
        action=help
        return
    fi

    # Set the options variables depending on the passed arguments
    while [ $# -gt 0 ]; do
        if [ `expr "$1" : "^-"` -eq 1 ]; then
            if [ $1 = "-h" ] || [ $1 = "--help" ]; then
                action=help
                shift 1
            elif [ $1 = "-s" ] || [ $1 = "--start" ]; then
                action=start
                shift 1
            elif [ $1 = "-t" ] || [ $1 = "--stop" ]; then
                action=stop
                shift 1
            elif [ $1 = "-b" ] || [ $1 = "--buffer-size" ]; then
                if [ $# -le 1 ]; then
                    printf "error: No argument specified for $1\n"
                    suggest_help
                    exit 1
                else
                    opt_buffer_size="$2"
                    shift 2
                fi
            elif [ $1 = "-k" ] || [ $1 = "--keep" ]; then
                opt_keep=yes
                shift 1
            elif [ $1 = "-l" ] || [ $1 = "--duration" ]; then
                if [ $# -le 1 ]; then
                    printf "error: No argument specified for $1\n"
                    suggest_help
                    exit 1
                else
                    opt_duration="$2"
                    shift 2
                fi
            elif [ $1 = "-d" ] || [ $1 = "--delay" ]; then
                if [ $# -le 1 ]; then
                    printf "error: No argument specified for $1\n"
                    suggest_help
                    exit 1
                else
                    opt_delay="$2"
                    shift 2
                fi
            elif [ $1 = "--adb" ]; then
                if [ $# -le 1 ]; then
                    printf "error: No argument specified for $1\n"
                    suggest_help
                    exit 1
                else
                    opt_adb="$2"
                    shift 2
                fi
            elif [ $1 = "--emulator" ]; then
                opt_adb_device="-e"
                shift 1
            elif [ $1 = "--device" ]; then
                if [ $# -le 1 ] || [ `expr "$2" : "^-"` -eq 1 ]; then
                    opt_adb_device="-d"
                    shift 1
                else
                    opt_adb_device="-s $2"
                    shift 2
                fi
            else
                printf "error: Unknown option $1\n"
                suggest_help
                exit 1
            fi
        else
            printf "error: Unknown option $1\n"
            suggest_help
            exit 1
        fi
    done
}

###############################################################################
# Prepare the adb command

prepare_adb() {
    ADB="$opt_adb $opt_adb_device"
}

###############################################################################
# Find a place where to store the trace on the phone

get_trace_path() {
    sdcard=$(
      $ADB shell "vdc volume list" | tr -d '\r' \
                                   | grep -m 1 sdcard \
                                   | cut -d' ' -f4
    )

    if [ -n "$sdcard" ]; then
        printf "$sdcard/$opt_trace_name"
    else
        printf "/data/local/tmp/$opt_trace_name"
    fi
}

###############################################################################
# Setup tracing and start it (this also clears the previous trace)

start_tracing() {
    # Enlarge the trace ring buffer
    $ADB shell "echo $opt_buffer_size > /sys/kernel/debug/tracing/buffer_size_kb" &&
    # Clear the existing buffer
    $ADB shell "echo '' > /sys/kernel/debug/tracing/trace" &&
    # Enable the scheduling runtime stats event tracer
    $ADB shell "echo 1 > /sys/kernel/debug/tracing/events/sched/sched_stat_runtime/enable" &&
    # Enable the scheduling wakeups event tracer
    $ADB shell "echo 1 > /sys/kernel/debug/tracing/events/sched/sched_wakeup/enable" &&
    # Enable the scheduling new wakeups event tracer
    $ADB shell "echo 1 > /sys/kernel/debug/tracing/events/sched/sched_wakeup_new/enable" &&
    # Enable tracing
    $ADB shell "echo 1 > /sys/kernel/debug/tracing/tracing_enabled"
}

###############################################################################
# Stop tracing and dump the trace to the SD-card

stop_tracing() {
    trace_path=$(get_trace_path)
    # Disable tracing
    $ADB shell "echo 0 > /sys/kernel/debug/tracing/tracing_enabled" &&
    # Disable the scheduling runtime stats event tracer
    $ADB shell "echo 0 > /sys/kernel/debug/tracing/events/sched/sched_stat_runtime/enable" &&
    # Disable the scheduling wakeups event tracer
    $ADB shell "echo 0 > /sys/kernel/debug/tracing/events/sched/sched_wakeup/enable" &&
    # Disable the scheduling new wakeups event tracer
    $ADB shell "echo 0 > /sys/kernel/debug/tracing/events/sched/sched_wakeup_new/enable" &&
    # Dump the trace
    $ADB shell "cat /sys/kernel/debug/tracing/trace > '$trace_path'"
}

###############################################################################
# Pull the trace from the SD-card

transfer_trace() {
  trace_path=$(get_trace_path)
  $ADB pull "$trace_path" 1>/dev/null 2>/dev/null &&
  if [ $opt_keep != yes ]; then
      $ADB shell rm "$trace_path"
  fi
}

###############################################################################
# Get the PIDs of all FxOS applications

get_pids() {
  $ADB shell 'ps | grep /system/b2g/ | while read user pid ppid rest ; do
                  echo $pid
              done' | tr -d '\r'
}

###############################################################################
# Process trace

process_trace() {
    printf "%16s %5s %7s %12s %3s\n" "NAME" "PID" "WAKEUPS" "RUNTIME" "NEW"
    for pid in $(get_pids) ; do
        name=$($ADB shell cat /proc/$pid/comm | tr -d '\r')
        total_runtime=0
        wakeups=0
        new=no

        grep " pid=$pid " "$opt_trace_name" | {
            while read -r line; do
                # Accumulate each time slice
                runtime=$(expr "$line" : ".* sched_stat_runtime:.* runtime=\([0-9]*\).*")
                total_runtime=$((total_runtime + runtime))

                # Count the number of wakeups
                wakeup=$(expr "$line" : ".* sched_wakeup:.* success=1.*")
                if [ $wakeup -gt 0 ]; then
                    wakeups=$((wakeups + 1))
                fi

                # Check if the app was created while we were tracing
                wakeup_new=$(expr "$line" : ".* sched_wakeup_new:.* success=1.*")
                if [ $wakeup_new -gt 0 ]; then
                    new=yes
                fi
            done

            total_runtime=$((total_runtime / 1000000))
            printf "%16s %5u %7u %9u ms %3s\n" \
                   "$name" $pid $wakeups $total_runtime $new
        }
    done

    if [ $opt_keep != yes ]; then
        rm -f "$opt_trace_name"
    fi
}

###############################################################################
# Main script

parse_args "$@"
prepare_adb

case $action in
    help)
        print_help
        ;;
    start)
        start_tracing
        ;;
    stop)
        stop_tracing &&
        transfer_trace &&
        process_trace
        ;;
    *)
        printf "error: Unknown action $action\n"
        suggest_help
        exit 1
        ;;
esac
