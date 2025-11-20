#!/usr/bin/env bash

EPOCH_START=$(date +%s%3N)
START_TIME=$(date -d "@$((EPOCH_START/1000))" +"%Y-%m-%d %H:%M:%S")

cleanup() {
        exit_code=$?

        epoch_end=$(date +%s%3N)
        end_time=$(date -d "@$((epoch_end/1000))" +"%Y-%m-%d %H:%M:%S")
        diff_ms=$((epoch_end - EPOCH_START))
        duration=$(printf "%.3f" $(echo "$diff_ms / 1000" | bc -l))

        echo

        if [ $exit_code -eq 0 ]; then
            echo -e "Compilation finished" \
                    "at ${end_time},"     \
                    "duration ${duration}"
        elif [ $exit_code -ge 128 ]; then
            if [ "$exit_code" -eq 254 ]; then
                signal_num=2
            else
                signal_num=$((exit_code - 128))
            fi
            echo -e "Compilation exited abnormally with signal ${signal_num} at ${end_time}, duration ${duration}"
        else
            echo -e "Compilation exited abnormally with code ${exit_code} at ${end_time}, duration ${duration}"
        fi

        trap - EXIT
        exit $exit_code
}

trap cleanup EXIT INT

# Get the shell argument and remove it from the list
CME_SHELL="$1"; shift

echo -e "-*- directory: $(pwd | sed "s#^${HOME}#~#") -*-"
echo -e "Compilation started at ${START_TIME}\n"

if [ $# -eq 0 ]; then
        echo -e "Argument required."
        exit 1
fi

$CME_SHELL -c "$1"
