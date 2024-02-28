#!/usr/bin/env bash

# Code based on: https://unix.stackexchange.com/a/673436
# Version: 2024-02-26

_multiselect_menu() {
    local return_value=$1
    local -n options=$2
    local -n defaults=$3

    # Helpers for console print format and control.
    __cursor_blink_on() {
        echo -e -n "\e[?25h"
    }
    __cursor_blink_off() {
        echo -e -n "\e[?25l"
    }
    __cursor_to() {
        local row=$1
        local col=${2:-1}

        echo -e -n "\e[${row};${col}H"
    }
    __get_cursor_row() {
        local row=""
        local col=""

        # shellcheck disable=SC2034
        IFS=';' read -rsdR -p $'\E[6n' row col
        echo "${row#*[}"
    }
    __get_keyboard_key() {
        local key=""

        IFS="" read -rsn1 key &>/dev/null
        case "$key" in
        "") echo "enter" ;;
        " ") echo "space" ;;
        $'\e')
            IFS="" read -rsn2 key &>/dev/null
            case "$key" in
            "[A" | "[D") echo "up" ;;
            "[B" | "[C") echo "down" ;;
            esac
            ;;
        esac
    }
    # shellcheck disable=SC2317
    __on_ctrl_c() {
        __cursor_to "$last_row"
        __cursor_blink_on
        stty echo
        exit 1
    }

    # Ensure cursor and input echoing back on upon a ctrl+c during read -s.
    trap "__on_ctrl_c" SIGINT

    # Proccess the 'defaults' parameter.
    local selected=()
    local i=0
    for i in "${!options[@]}"; do
        if [[ -v "defaults[i]" ]]; then
            if [[ ${defaults[i]} == "false" ]]; then
                selected+=("false")
            else
                selected+=("true")
            fi
        else
            selected+=("true")
        fi
        echo
    done

    # Determine current screen position for overwriting the options.
    local start_row=""
    local last_row=""
    last_row=$(__get_cursor_row)
    start_row=$((last_row - ${#options[@]}))

    # Print options by overwriting the last lines.
    __print_options() {
        local index_active=$1

        local i=0
        for i in "${!options[@]}"; do
            # Set the prefix "[ ]" or "[*]".
            local prefix="[ ]"
            if [[ ${selected[i]} == "true" ]]; then
                prefix="[\e[1;32m*\e[0m]"
            fi

            # Print the prefix with the option in the menu.
            __cursor_to "$((start_row + i))"
            local option="${options[i]}"
            if ((i == index_active)); then
                # Print the active option.
                echo -e -n "$prefix \e[7m$option\e[27m"
            else
                # Print the inactive option.
                echo -e -n "$prefix $option"
            fi
            # Avoid print chars when press two keys at same time.
            __cursor_to "$start_row"
        done
    }

    # Main loop of the menu.
    __cursor_blink_off
    local active=0
    while true; do
        __print_options "$active"

        # User key control.
        case $(__get_keyboard_key) in
        "space")
            # Toggle the option.
            if [[ ${selected[active]} == "true" ]]; then
                selected[active]="false"
            else
                selected[active]="true"
            fi
            ;;
        "enter")
            __print_options -1
            break
            ;;
        "up")
            active=$((active - 1))
            if [[ $active -lt 0 ]]; then
                active=$((${#options[@]} - 1))
            fi
            ;;
        "down")
            active=$((active + 1))
            if [[ $active -ge ${#options[@]} ]]; then
                active=0
            fi
            ;;
        esac
    done

    # Set the cursor position back to normal.
    __cursor_to "$last_row"
    __cursor_blink_on

    eval "$return_value"='("${selected[@]}")'

    # Unset the trap function.
    trap "" SIGINT
}