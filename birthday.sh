#!/bin/bash

# Author: Haitham Aouati
# GitHub: github.com/haithamaouati

# Colors
nc="\e[0m"
underline="\e[4m"

# JSON storage
JSON_FILE="$HOME/.birthday.json"

# Initialize file if missing
[[ ! -f "$JSON_FILE" ]] && echo "[]" > "$JSON_FILE"

# Check required dependencies
check_dependencies() {
    local missing=0
    for dep in jq termux-notification cal date; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo "Missing dependency: $dep"
            missing=1
        fi
    done
    if (( missing == 1 )); then
        echo -e "\nInstall missing dependencies and try again."
        exit 1
    fi
}

# Banner
show_banner() {
    clear
    cal
    echo -e " Author: Haitham Aouati"
    echo -e " GitHub: ${underline}github.com/haithamaouati${nc}\n"
}

# Help message
show_help() {
    cat <<EOF
Usage: birthday [options]

Options:

  -n, --name <name>         Friend's name
  -d, --date <dd/mm/yyyy>   Birthday date
  -r, --remove <#>          Remove entry by number
  -h, --help                Show this help

Examples:

  birthday -n 'Immortal method' -d '14/06/1902'
  birthday                      # Displays all birthdays
  birthday -r 1                 # Removes the first entry
EOF
    exit 0
}

# Add birthday
add_birthday() {
    local name="$1"
    local date="$2"
    local entry="{\"name\":\"$name\",\"date\":\"$date\"}"

    jq ". + [$entry]" "$JSON_FILE" > "$JSON_FILE.tmp" && mv "$JSON_FILE.tmp" "$JSON_FILE"
    echo -e "\n[+] Added: $name - $date\n"
    exit 0
}

# Remove birthday
remove_entry() {
    local index="$1"
    total=$(jq length "$JSON_FILE")

    if ! [[ "$index" =~ ^[0-9]+$ ]] || (( index < 1 || index > total )); then
        echo -e "\n[!] Invalid entry number: $index\n"
        exit 1
    fi

    new_json=$(jq "del(.[${index}-1])" "$JSON_FILE")
    echo "$new_json" > "$JSON_FILE"
    echo -e "\n[-] Removed entry #$index\n"
    exit 0
}

# Notifications for today
send_notifications() {
    jq -c '.[]' "$JSON_FILE" | while read -r entry; do
        name=$(echo "$entry" | jq -r '.name')
        bdate=$(echo "$entry" | jq -r '.date')

        day=$(echo "$bdate" | cut -d/ -f1)
        month=$(echo "$bdate" | cut -d/ -f2)

        today_day=$(date +%d)
        today_month=$(date +%m)

        if (( 10#$day == 10#$today_day && 10#$month == 10#$today_month )); then
            termux-notification \
                --title "🎉 Birthday Reminder" \
                --content "Today is $name's birthday!" \
                --priority high \
                --vibrate 100,100,100 \
                --sound
        fi
    done
}

# Show all birthdays
calculate_and_show() {
    show_banner
    local i=1
    printf "%-3s | %-15s | %-10s | %-4s | %s\n" "#" "Name" "Birthday" "Age" "Coming"
    printf "%s\n" "———————————————————————————————————————————————————————"
    jq -c '.[]' "$JSON_FILE" | while read -r entry; do
        name=$(echo "$entry" | jq -r '.name')
        bdate=$(echo "$entry" | jq -r '.date')

        day=$(echo "$bdate" | cut -d/ -f1)
        month=$(echo "$bdate" | cut -d/ -f2)
        year=$(echo "$bdate" | cut -d/ -f3)

        birth_fmt="$year-$month-$day"
        today=$(date +%Y-%m-%d)
        age=$(($(date +%Y) - year))
        current_month=$(date +%m)
        current_day=$(date +%d)

        if (( 10#$month > 10#$current_month || (10#$month == 10#$current_month && 10#$day > 10#$current_day) )); then
            age=$((age - 1))
        fi

        this_year=$(date +%Y)
        next_bday="$this_year-$month-$day"
        [[ $(date -d "$next_bday" +%s) -lt $(date +%s) ]] && next_bday="$((this_year + 1))-$month-$day"

        days_left=$(( ( $(date -d "$next_bday" +%s) - $(date +%s) ) / 86400 ))

        if [ "$days_left" -eq 0 ]; then
            coming="today"
        elif [ "$days_left" -eq 1 ]; then
            coming="in a day"
        else
            coming="in $days_left days"
        fi

        display_date=$(date -d "$birth_fmt" "+%d %B")
        printf "%-3s | %-15s | %-10s | %-4s | %s\n" "$i" "$name" "$display_date" "$age" "$coming"
        i=$((i + 1))
    done
    echo
    send_notifications
}

# === Entry Point ===

check_dependencies

# Flags
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -n|--name) name="$2"; shift ;;
        -d|--date) date="$2"; shift ;;
        -r|--remove) remove="$2"; shift ;;
        -h|--help) show_help ;;
        *) echo "Unknown option: $1"; show_help ;;
    esac
    shift
done

if [[ -n "$name" && -n "$date" ]]; then
    add_birthday "$name" "$date"
elif [[ -n "$remove" ]]; then
    remove_entry "$remove"
else
    calculate_and_show
fi
