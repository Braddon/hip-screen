#!/bin/bash

# Get screen socket directory
SCREENDIR="/var/run/screen/S-$USER"
[[ ! -d "$SCREENDIR" ]] && SCREENDIR="$HOME/.screen"

# Check if we're already in a screen session
CURRENT_SESSION=""
if [[ -n "$STY" ]]; then
    # Extract session name from STY (format: PID.session_name)
    CURRENT_SESSION="${STY#*.}"
fi

# Main loop - return here after killing a session
while true; do
    # Parse screen sessions (preserves spaces) and get full output for connection info
    screen_output=$(screen -ls)
    mapfile -t sessions < <(echo "$screen_output" | grep -oP '\d+\.\K[^\t(]+' | sed 's/[[:space:]]*$//')

    # Get connection counts for each session by counting screen client processes
    declare -A conn_counts
    for session_name in "${sessions[@]}"; do
        # Count screen client processes for this session
        count=$(ps -eo cmd | grep -F "screen" | grep -F "$session_name" | grep -v "SCREEN" | grep -v grep | wc -l)
        conn_counts["$session_name"]=$count
    done

    if [ ${#sessions[@]} -eq 0 ]; then
    echo "No active screens."
    echo -n "Create new session - Name: "
    name=""
    while true; do
        IFS= read -n 1 -s char
        if [[ "$char" == $'\e' ]]; then
            echo ""
            exit 0
        fi
        if [[ "$char" == $'\n' || "$char" == "" ]]; then
            echo ""
            break
        fi
        if [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
            if [[ -n "$name" ]]; then
                name="${name%?}"
                echo -ne '\b \b'
            fi
            continue
        fi
        echo -n "$char"
        name="${name}${char}"
    done
    [[ -n "$name" ]] && screen -S "$name" || echo "Cancelled."
    exit 0
fi

echo "There are ${#sessions[@]} screen(s) currently running:"
echo ""

# Get terminal width
term_width=$(tput cols 2>/dev/null || echo 80)
# Calculate if inline note will fit (base table width ~86 + note text ~30 = ~116)
use_footnote=false
footnote_text=""
if [[ $term_width -lt 116 ]]; then
    use_footnote=true
fi

printf "%-4s %-25s %-20s %-20s %-12s\n" "#" "Name" "Last Active" "Created" "Connections"
echo "─────────────────────────────────────────────────────────────────────────────────"

for i in "${!sessions[@]}"; do
    name="${sessions[$i]}"
    # Find socket file (handle spaces)
    socket=$(find "$SCREENDIR" -name "*.$name" 2>/dev/null | head -1)
    if [[ -n "$socket" ]]; then
        modified=$(stat -c %y "$socket" 2>/dev/null | cut -d. -f1)
        created=$(stat -c %w "$socket" 2>/dev/null | cut -d. -f1)
        [[ "$created" == "-" ]] && created=$(stat -c %y "$socket" 2>/dev/null | cut -d. -f1)
    else
        modified="unknown"
        created="unknown"
    fi
    conns="${conn_counts[$name]:-0}"

    # Check if this is the current session
    display_name="$name"
    note=""
    if [[ "$name" == "$CURRENT_SESSION" ]]; then
        display_name="${name}^"
        if $use_footnote; then
            footnote_text="^ [you are already in '$name']"
        else
            note="<--- you are already in here"
        fi
    fi

    printf "%-4s %-25s %-20s %-20s %-12s %s\n" "$((i+1))." "$display_name" "$modified" "$created" "$conns" "$note"
done

# Display footnote if needed
if [[ -n "$footnote_text" ]]; then
    echo ""
    echo "$footnote_text"
fi

echo ""
show_exit_hint=false
echo -n "Select session number, 'n' for new, 'k' to kill: "

# Read input character by character to handle ESC immediately
choice=""
while true; do
    IFS= read -n 1 -s char

    # Check for ESC
    if [[ "$char" == $'\e' ]]; then
        echo ""
        exit 0
    fi

    # Check for Enter/Return
    if [[ "$char" == $'\n' || "$char" == "" ]]; then
        echo ""
        break
    fi

    # Check for backspace/delete
    if [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
        if [[ -n "$choice" ]]; then
            # Remove last character from string
            choice="${choice%?}"
            # Move cursor back, print space, move back again
            echo -ne '\b \b'
        fi
        continue
    fi

    # Echo the character and add to choice
    echo -n "$char"
    choice="${choice}${char}"
done

    if [[ -z "$choice" ]]; then
        # Empty input - show hint and re-prompt
        if $show_exit_hint; then
            echo -n "Select session number, 'n' for new, 'k' to kill, 'q' to exit: "
        else
            show_exit_hint=true
            echo -n "Select session number, 'n' for new, 'k' to kill: "
        fi
        # Re-read input
        choice=""
        while true; do
            IFS= read -n 1 -s char
            if [[ "$char" == $'\e' ]]; then
                echo ""
                exit 0
            fi
            if [[ "$char" == $'\n' || "$char" == "" ]]; then
                echo ""
                break
            fi
            if [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
                if [[ -n "$choice" ]]; then
                    choice="${choice%?}"
                    echo -ne '\b \b'
                fi
                continue
            fi
            echo -n "$char"
            choice="${choice}${char}"
        done
    fi

    if [[ "$choice" == "q" || "$choice" == "exit" ]]; then
        exit 0
    elif [[ "$choice" == "n" ]]; then
        echo -n "Name: "
        name=""
        while true; do
            IFS= read -n 1 -s char
            if [[ "$char" == $'\e' ]]; then
                echo ""
                exit 0
            fi
            if [[ "$char" == $'\n' || "$char" == "" ]]; then
                echo ""
                break
            fi
            if [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
                if [[ -n "$name" ]]; then
                    name="${name%?}"
                    echo -ne '\b \b'
                fi
                continue
            fi
            echo -n "$char"
            name="${name}${char}"
        done
        [[ -n "$name" ]] && screen -S "$name" || echo "Cancelled."
        exit 0
    elif [[ "$choice" == "k" ]]; then
        echo -n "Kill session number: "
        num=""
        while true; do
            IFS= read -n 1 -s char
            if [[ "$char" == $'\e' ]]; then
                echo ""
                exit 0
            fi
            if [[ "$char" == $'\n' || "$char" == "" ]]; then
                echo ""
                break
            fi
            if [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
                if [[ -n "$num" ]]; then
                    num="${num%?}"
                    echo -ne '\b \b'
                fi
                continue
            fi
            echo -n "$char"
            num="${num}${char}"
        done
        idx=$((num-1))
        if [[ $idx -ge 0 && $idx -lt ${#sessions[@]} ]]; then
            echo -n "Kill session $num [${sessions[$idx]}]? (y/N): "
            confirm=""
            while true; do
                IFS= read -n 1 -s char
                if [[ "$char" == $'\e' ]]; then
                    echo ""
                    exit 0
                fi
                if [[ "$char" == $'\n' || "$char" == "" ]]; then
                    echo ""
                    break
                fi
                if [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
                    if [[ -n "$confirm" ]]; then
                        confirm="${confirm%?}"
                        echo -ne '\b \b'
                    fi
                    continue
                fi
                echo -n "$char"
                confirm="${confirm}${char}"
            done
            if [[ "$confirm" == "y" ]]; then
                screen -S "${sessions[$idx]}" -X quit && echo "Killed."
                echo ""
            fi
        fi
        # Continue loop to show updated session list
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 && $choice -le ${#sessions[@]} ]]; then
        screen -x "${sessions[$((choice-1))]}"
        exit 0
    fi
done
