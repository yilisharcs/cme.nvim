#!/usr/bin/env bash

WHITE_BOLD="\e[1;37m"
WHITE="\e[37m"
GREEN="\e[32m"
GREEN_BOLD="\e[1;32m"
RED_BOLD="\e[1;31m"
YELLOW_BOLD="\e[1;33m"
CYAN_BOLD="\e[1;36m"
RESET="\e[0m"

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
            echo -e "Compilation ${GREEN_BOLD}finished${RESET}" \
                    "at ${YELLOW_BOLD}${end_time}${RESET},"     \
                    "duration ${CYAN_BOLD}${duration}${RESET}"
        elif [ $exit_code -ge 128 ]; then
            local signal_num=$((exit_code - 128))
            echo -e "Compilation ${RED_BOLD}exited abnormally${RESET}"  \
                    "with ${RED_BOLD}signal ${signal_num}${RESET} at"   \
                    "${YELLOW_BOLD}${end_time}${RESET},"                \
                    "duration ${CYAN_BOLD}${duration}${RESET}"
        else
            echo -e "Compilation ${RED_BOLD}exited abnormally${RESET}"  \
                    "with ${RED_BOLD}code ${exit_code}${RESET} at"      \
                    "${YELLOW_BOLD}${end_time}${RESET},"                \
                    "duration ${CYAN_BOLD}${duration}${RESET}"
        fi

        trap - EXIT
        exit $exit_code
}

trap cleanup EXIT INT

CMD="$*"

GREET_DIR="${WHITE_BOLD}-*- ${GREEN}DIR:${WHITE} $(pwd)${RESET}"
GREET_CMD="${WHITE_BOLD}-*- ${GREEN}CMD:${WHITE} ${CMD}${RESET}"

echo -e "$GREET_DIR\n$GREET_CMD\n"
echo -e "Compilation started at ${YELLOW_BOLD}${START_TIME}${RESET}\n"

if [ $# -eq 0 ]; then
        echo -e "${RED_BOLD}Argument required.${RESET}"
        exit 1
fi

sh -c "$CMD"
