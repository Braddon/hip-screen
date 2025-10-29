#!/bin/bash

# Get screen socket directory
SCREENDIR="/var/run/screen/S-$USER"
[[ ! -d "$SCREENDIR" ]] && SCREENDIR="$HOME/.screen"

# Parse screen sessions (preserves spaces) and get full output for connection info
screen_output=$(screen -ls)
mapfile -t sessions < <(echo "$screen_output" | grep -oP '\d+\.\K[^\t(]+' | sed 's/[[:space:]]*$//')

# Get connection counts for each session
declare -A conn_counts
while IFS= read -r line; do
    if [[ "$line" =~ ([0-9]+)\.([^[:space:]]+) ]]; then
        session_name="${BASH_REMATCH[2]}"
        # Count attached connections (look for "Attached" in the line)
        if [[ "$line" =~ Attached ]]; then
            ((conn_counts["$session_name"]++))
        fi
    fi
done <<< "$screen_output"

if [ ${#sessions[@]} -eq 0 ]; then
    echo "No active screens."
    read -p "Create new session - Name: " name
    [[ -n "$name" ]] && screen -S "$name" || echo "Cancelled."
    exit 0
fi

echo "There are ${#sessions[@]} screen(s) currently running:"
echo ""
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
    printf "%-4s %-25s %-20s %-20s %-12s\n" "$((i+1))." "$name" "$modified" "$created" "$conns"
done

echo ""
read -p "Select session number, 'n' for new, 'k' to kill: " choice

if [[ "$choice" == "n" ]]; then
    read -p "Name: " name
    [[ -n "$name" ]] && screen -S "$name" || echo "Cancelled."
elif [[ "$choice" == "k" ]]; then
    read -p "Kill session number: " num
    idx=$((num-1))
    if [[ $idx -ge 0 && $idx -lt ${#sessions[@]} ]]; then
        read -p "Kill session $num [${sessions[$idx]}]? (y/N): " confirm
        [[ "$confirm" == "y" ]] && screen -S "${sessions[$idx]}" -X quit && echo "Killed."
    fi
elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 && $choice -le ${#sessions[@]} ]]; then
    screen -x "${sessions[$((choice-1))]}"
else
    echo "Invalid choice."
fi
