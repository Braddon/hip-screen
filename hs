#!/bin/bash

# Get screen socket directory
SCREENDIR="/var/run/screen/S-$USER"
[[ ! -d "$SCREENDIR" ]] && SCREENDIR="$HOME/.screen"

# Parse screen sessions (preserves spaces)
mapfile -t sessions < <(screen -ls | grep -oP '\d+\.\K[^\t(]+' | sed 's/[[:space:]]*$//')

if [ ${#sessions[@]} -eq 0 ]; then
    echo "No active screens."
    read -p "Create new session - Name: " name
    [[ -n "$name" ]] && screen -S "$name" || echo "Cancelled."
    exit 0
fi

echo "There are ${#sessions[@]} screen(s) currently running:"
echo ""
printf "%-4s %-25s %-20s %-20s\n" "#" "Name" "Last Active" "Created"
echo "────────────────────────────────────────────────────────────────────"

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
    printf "%-4s %-25s %-20s %-20s\n" "$((i+1))." "$name" "$modified" "$created"
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
    screen -r "${sessions[$((choice-1))]}"
else
    echo "Invalid choice."
fi
