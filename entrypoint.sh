#!/bin/bash

UPLOAD_DIR="/upload"
BOT_DIR="/bots"
COMMAND_DIR="/bots/commands"
LOG_FILE="/bots/botfarm.log"
DB_FILE="/bots/botfarm.db"

# Create necessary directories
mkdir -p "$UPLOAD_DIR" "$BOT_DIR" "$COMMAND_DIR"

declare -A pids
declare -A failed_scripts
declare -A script_status  # track status: "running", "stopped", "deleted"

# Ensure required tools are installed
if ! command -v inotifywait &> /dev/null; then
    echo "Installing inotify-tools..." | tee -a "$LOG_FILE"
    apt-get update && apt-get install -y inotify-tools
fi

if ! command -v pipreqs &> /dev/null; then
    echo "Installing pipreqs..." | tee -a "$LOG_FILE"
    pip install pipreqs
fi

if ! command -v sqlite3 &> /dev/null; then
    echo "Installing sqlite3..." | tee -a "$LOG_FILE"
    apt-get update && apt-get install -y sqlite3
fi

# Initialize SQLite database
init_database() {
    echo "Initializing SQLite database..." | tee -a "$LOG_FILE"
    sqlite3 "$DB_FILE" <<EOF
CREATE TABLE IF NOT EXISTS bots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    path TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL,
    last_updated TIMESTAMP,
    pid INTEGER,
    added_at TIMESTAMP,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS bot_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    bot_path TEXT NOT NULL,
    event_type TEXT NOT NULL,
    timestamp TIMESTAMP,
    details TEXT
);
EOF
}

# Database functions
update_bot_status() {
    local script_path=$1
    local status=$2
    local pid=$3
    local details=$4
    
    # Update bot status in database
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local script_name=$(basename "$script_path")
    
    sqlite3 "$DB_FILE" <<EOF
INSERT OR REPLACE INTO bots (name, path, status, last_updated, pid)
VALUES ('$script_name', '$script_path', '$status', '$timestamp', $pid);

INSERT INTO bot_events (bot_path, event_type, timestamp, details)
VALUES ('$script_path', '$status', '$timestamp', '$details');
EOF
}

start_script() {
    local script=$1
    if [[ "${script_status[$script]}" != "deleted" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') Starting $script..." | tee -a "$LOG_FILE"
        python3 "$script" &  # Run in background
        local pid=$!
        pids[$script]=$pid     # Store PID
        script_status[$script]="running"
        
        # Update database
        update_bot_status "$script" "running" "$pid" "Started by system"
    fi
}

stop_script() {
    local script=$1
    if [[ -v pids[$script] ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') Stopping $script..." | tee -a "$LOG_FILE"
        kill "${pids[$script]}" 2>/dev/null
        unset pids[$script]
        script_status[$script]="stopped"
        
        # Update database
        update_bot_status "$script" "stopped" "NULL" "Stopped by system"
    fi
}

delete_script() {
    local script=$1
    if [[ -v pids[$script] ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') Stopping and marking $script as deleted..." | tee -a "$LOG_FILE"
        kill "${pids[$script]}" 2>/dev/null
        unset pids[$script]
    fi
    script_status[$script]="deleted"
    
    # Update database
    update_bot_status "$script" "deleted" "NULL" "Marked as deleted"
}

install_from_pipreqs() {
    local script_path=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') Generating and installing requirements for $(basename "$script_path")..." | tee -a "$LOG_FILE"
    
    # Use pipreqs to detect and install dependencies
    cd "$(dirname "$script_path")" || return
    pipreqs --print . | while read -r package; do
        echo "$(date '+%Y-%m-%d %H:%M:%S') Installing $package..." | tee -a "$LOG_FILE"
        pip install "$package"
    done
}

install_requirements() {
    for req_file in "$BOT_DIR"/*/requirements.txt "$BOT_DIR"/requirements.txt; do
        if [[ -f "$req_file" ]]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') Installing dependencies from $req_file..." | tee -a "$LOG_FILE"
            if ! pip install -r "$req_file"; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') Error installing dependencies from $req_file" | tee -a "$LOG_FILE"
            fi
        fi
    done
}

process_commands() {
    for cmd_file in "$COMMAND_DIR"/*.cmd; do
        if [[ -f "$cmd_file" ]]; then
            # Parse command file (format: ACTION SCRIPT_PATH)
            read -r action script_path < "$cmd_file"
            script_path="$BOT_DIR/$(basename "$script_path")"
            
            case "$action" in
                start)
                    if [[ -f "$script_path" ]]; then
                        if [[ "${script_status[$script_path]}" != "running" ]]; then
                            echo "$(date '+%Y-%m-%d %H:%M:%S') Command: Starting $script_path" | tee -a "$LOG_FILE"
                            start_script "$script_path"
                        fi
                    fi
                    ;;
                stop)
                    if [[ "${script_status[$script_path]}" == "running" ]]; then
                        echo "$(date '+%Y-%m-%d %H:%M:%S') Command: Stopping $script_path" | tee -a "$LOG_FILE"
                        stop_script "$script_path"
                    fi
                    ;;
                delete)
                    echo "$(date '+%Y-%m-%d %H:%M:%S') Command: Deleting $script_path" | tee -a "$LOG_FILE"
                    delete_script "$script_path"
                    ;;
                status)
                    echo "$(date '+%Y-%m-%d %H:%M:%S') Bot Status:" | tee -a "$LOG_FILE"
                    sqlite3 "$DB_FILE" "SELECT name, status, last_updated FROM bots ORDER BY name;" | 
                    while IFS='|' read -r name status timestamp; do
                        echo "  - $name: $status (Last updated: $timestamp)" | tee -a "$LOG_FILE"
                    done
                    ;;
                *)
                    echo "$(date '+%Y-%m-%d %H:%M:%S') Unknown command: $action" | tee -a "$LOG_FILE"
                    ;;
            esac
            
            # Remove the command file after processing
            rm "$cmd_file"
        fi
    done
}

monitor_scripts() {
    while true; do
        # Process any command files
        process_commands
        
        # Check for new scripts that aren't already running
        for script in "$BOT_DIR"/*.py; do
            if [[ -f "$script" ]]; then
                if [[ ! -v script_status[$script] ]]; then
                    # New script detected, mark as stopped initially
                    echo "$(date '+%Y-%m-%d %H:%M:%S') New script detected: $script" | tee -a "$LOG_FILE"
                    script_status[$script]="stopped"
                    
                    # Update database
                    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
                    local script_name=$(basename "$script")
                    sqlite3 "$DB_FILE" <<EOF
INSERT OR IGNORE INTO bots (name, path, status, last_updated, added_at)
VALUES ('$script_name', '$script', 'new', '$timestamp', '$timestamp');

INSERT INTO bot_events (bot_path, event_type, timestamp, details)
VALUES ('$script', 'new', '$timestamp', 'New script detected');
EOF
                fi
            fi
        done
        
        # Check if running scripts have crashed
        for script in "${!pids[@]}"; do
            if ! kill -0 "${pids[$script]}" 2>/dev/null; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') Script $script has stopped unexpectedly." | tee -a "$LOG_FILE"
                unset pids[$script]
                
                if [[ "${script_status[$script]}" == "running" ]]; then
                    # Only restart scripts that should be running
                    failed_scripts[$script]=1
                    
                    # Update database
                    update_bot_status "$script" "crashed" "NULL" "Script crashed unexpectedly"
                fi
            fi
        done

        # Retry failed scripts
        for script in "${!failed_scripts[@]}"; do
            echo "$(date '+%Y-%m-%d %H:%M:%S') Retrying $script in 10 seconds..." | tee -a "$LOG_FILE"
            sleep 10
            start_script "$script"
            unset failed_scripts["$script"]
        done

        sleep 5  # Check every 5 seconds
    done
}

# Setup file watcher in the background
setup_file_watcher() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') Setting up file watcher on $UPLOAD_DIR..." | tee -a "$LOG_FILE"
    
    inotifywait "$UPLOAD_DIR" -m -r -e create --format "%f" |
    while read -r filename; do
        file_path="$UPLOAD_DIR/$filename"
        
        # Check if the file is a directory
        if [ -d "$file_path" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') Directory created: $filename (ignoring)" | tee -a "$LOG_FILE"
        else
            # Check if the file has a .py extension
            if [[ $filename == *.py ]]; then
                # Move the .py file to the bot directory
                bot_path="$BOT_DIR/$filename"
                mv "$file_path" "$bot_path"
                echo "$(date '+%Y-%m-%d %H:%M:%S') Moving .py file: $filename to $bot_path" | tee -a "$LOG_FILE"
                
                # Generate and install requirements using pipreqs
                install_from_pipreqs "$bot_path"
                
                # Add to database as new script
                local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
                sqlite3 "$DB_FILE" <<EOF
INSERT OR IGNORE INTO bots (name, path, status, last_updated, added_at)
VALUES ('$filename', '$bot_path', 'new', '$timestamp', '$timestamp');

INSERT INTO bot_events (bot_path, event_type, timestamp, details)
VALUES ('$bot_path', 'new', '$timestamp', 'Uploaded to $UPLOAD_DIR');
EOF
                
                # Mark as a new, stopped script
                script_status["$bot_path"]="stopped"
                echo "$(date '+%Y-%m-%d %H:%M:%S') Bot $filename is ready to start (status: stopped)" | tee -a "$LOG_FILE"
            else
                # Delete non-.py files from the upload directory
                rm "$file_path"
                echo "$(date '+%Y-%m-%d %H:%M:%S') Deleting non-.py file: $filename" | tee -a "$LOG_FILE"
            fi
        fi
    done
}

# Main execution starts here
echo "$(date '+%Y-%m-%d %H:%M:%S') Bot farm initializing..." | tee -a "$LOG_FILE"

# Initialize the database
init_database

# Ensure dependencies are installed
install_requirements

for script in "$BOT_DIR"/*.py; do
    if [[ -f "$script" ]]; then
        script_status[$script]="stopped"
        script_name=$(basename "$script")
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Add to database if not exists
        sqlite3 "$DB_FILE" <<EOF
INSERT OR IGNORE INTO bots (name, path, status, last_updated, added_at)
VALUES ('$script_name', '$script', 'stopped', '$timestamp', '$timestamp');
EOF
        
        echo "$(date '+%Y-%m-%d %H:%M:%S') Found existing script: $script (status: stopped)" | tee -a "$LOG_FILE"
    fi
done

# Start the file watcher in the background
setup_file_watcher &
file_watcher_pid=$!

echo "$(date '+%Y-%m-%d %H:%M:%S') Bot farm initialized. Scripts discovered but not started automatically." | tee -a "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') Use command files in $COMMAND_DIR to control bots." | tee -a "$LOG_FILE"

# Start the script monitoring loop
monitor_scripts &
monitor_pid=$!

# Setup trap to clean up when this script exits
cleanup() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') Shutting down bot farm..." | tee -a "$LOG_FILE"
    
    # Kill the file watcher and monitor processes
    kill $file_watcher_pid 2>/dev/null
    kill $monitor_pid 2>/dev/null
    
    # Stop all running scripts
    for script in "${!pids[@]}"; do
        echo "$(date '+%Y-%m-%d %H:%M:%S') Stopping $script during shutdown..." | tee -a "$LOG_FILE"
        kill "${pids[$script]}" 2>/dev/null
        update_bot_status "$script" "stopped" "NULL" "Stopped during system shutdown"
    done
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') Bot farm shutdown complete." | tee -a "$LOG_FILE"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Wait forever - the real work happens in the background
echo "$(date '+%Y-%m-%d %H:%M:%S') Bot farm running. Press Ctrl+C to shutdown gracefully." | tee -a "$LOG_FILE"
while true; do
    sleep 60
done
