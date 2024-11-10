#!/bin/bash

NUM_SERVERS=3
VERBOSE=0

# Parse flags to get # of servers (cant be <3)
while getopts ":s:v" opt; do
  case $opt in
   s) NUM_SERVERS="$OPTARG" ;;                        # sets number of servers if -s is provided
   v) VERBOSE=1 ;;                                    # all echo statements
   \?) echo "Invalid option -$OPTARG" >&2; exit 1 ;;  # any other flag is wrong
  esac
done

# checks if servers >=3
if [ "$NUM_SERVERS" -lt 3 ]; then
   echo "Error: The number of servers (-s) must be greater than 3."
   exit 1
fi
shift $((OPTIND -1))  # Shift positional arguments after options

# Parse the other arguments for destination IP/port
if [ "$#" -ne 2 ]; then
   echo "Usage: ./toralize [-s num_services] [-v] <destination_ip> <destination_port>"
   exit 1
fi

log() {
  if [ "$VERBOSE" -eq 1 ]; then
    echo "$@"
  fi
}

DEST_IP=$1
DEST_PORT=$2

# Array to hold open ports for each Dante instance
PORTS=()
CONFIG_FILES=()
PIDS=()

# finds open port to start server on
find_open_port() {
   PORT=1080  # Starting port for check
   while sudo lsof -i :$PORT >/dev/null 2>&1; do
      PORT=$((PORT + 1))
   done
   echo $PORT
}

echo "Starting..."

# Generate Dante server instances in a loop 
for i in $(seq 1 $NUM_SERVERS); do
   # Find an open port and save it in PORTS array
   OPEN_PORT=$(find_open_port)
   PORTS+=($OPEN_PORT)

   # Generate temporary config file for this instance (in /tmp somewhere)
   CONFIG_FILE=$(mktemp)
   CONFIG_FILES+=($CONFIG_FILE)

   # fill in the config file for each Dante instance
   cat <<EOF > "$CONFIG_FILE"
logoutput: stderr

internal: 127.0.0.1 port = $OPEN_PORT
external: eth0

socksmethod: none
user.privileged: root
user.unprivileged : nobody

client pass {
   from: 0.0.0.0/0 to: 0.0.0.0/0
   log: connect disconnect error
}

socks pass {
   from: 0.0.0.0/0 to: 0.0.0.0/0
   protocol: tcp udp
   log: connect disconnect error
}
EOF

   # Start danted with the configuration file
   sudo danted -f "$CONFIG_FILE" -D
   sleep 1  # Give time for danted to start

   # Get the PID of the main danted process and save it
   DANTED_PID=$(pgrep -f "$CONFIG_FILE")
   PIDS+=($DANTED_PID)
   log "Started danted instance $i on port $OPEN_PORT with PID $DANTED_PID"
done

# Select 3 random ports for the proxy chain
RANDOM_PORTS=($(shuf -e "${PORTS[@]}" | head -n 3))
log "Selected random ports for proxy chain: ${RANDOM_PORTS[@]}"

# Update configurations to route traffic in the chosen chain
for j in $(seq 0 1); do
   NEXT_PORT=${RANDOM_PORTS[$((j + 1))]}
   CONFIG_FILE="${CONFIG_FILES[$j]}"
   
   # Update route section in each chosen Dante config file
   cat <<EOF >> "$CONFIG_FILE"
# Route traffic to the next Dante server in the chain
route {
   from: 0.0.0.0/0 to: 0.0.0.0/0 via: 127.0.0.1 port = $NEXT_PORT
   protocol: tcp udp
   proxyprotocol: socks_v4
}
EOF
done

# Update toralize.h or set env variable to use first server in the chain
PROXYPORT=${RANDOM_PORTS[0]}
sed -i "s/^#define PROXYPORT .*/#define PROXYPORT $PROXYPORT/" toralize.h

# Compile toralize after change
log "Running make..."
make

log "Running toralize with DEST_IP=$DEST_IP and DEST_PORT=$DEST_PORT..."
./toralize "$DEST_IP" "$DEST_PORT"

# Once toralize is finished, shut down all danted processes and clean up
for PID in "${PIDS[@]}"; do
   log "Shutting down danted process with PID $PID..."
   sudo kill "$PID"
done

# Remove temporary config files
for CONFIG_FILE in "${CONFIG_FILES[@]}"; do
   rm -f "$CONFIG_FILE"
done

log "All danted processes stopped and configuration files cleaned up."