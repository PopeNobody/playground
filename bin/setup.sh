#!/bin/bash
# Start AI executor daemons for each provider
# Usage: start-daemons [--stop]

# Configuration
SOCKET_DIR="ai_sockets"
LOG_DIR="ai_logs"
PROVIDERS=("gpt" "claude" "gemini" "grok")

# Create directories
mkdir -p $SOCKET_DIR
mkdir -p $LOG_DIR

# Stop existing daemons
stop_daemons() {
  echo "Stopping AI executor daemons..."
  for provider in "${PROVIDERS[@]}"; do
    PID_FILE="$SOCKET_DIR/$provider.sock.pid"
    if [ -f "$PID_FILE" ]; then
      PID=$(cat "$PID_FILE")
      if kill -0 $PID 2>/dev/null; then
        echo "  Stopping $provider daemon (PID: $PID)"
        kill $PID
        sleep 1
        if kill -0 $PID 2>/dev/null; then
          echo "  Daemon didn't exit gracefully, sending SIGKILL"
          kill -9 $PID
        fi
      fi
      rm -f "$PID_FILE"
    fi
    # Remove socket file
    rm -f "$SOCKET_DIR/$provider.sock"
  done
  echo "All daemons stopped."
}

# If --stop argument is provided, just stop daemons
if [ "$1" == "--stop" ]; then
  stop_daemons
  exit 0
fi

# Stop any existing daemons first
stop_daemons

# Start daemons for each provider
echo "Starting AI executor daemons..."
for provider in "${PROVIDERS[@]}"; do
  echo "  Starting $provider daemon..."
  LOG_FILE="$LOG_DIR/$provider.log"
  SOCKET_FILE="$SOCKET_DIR/$provider.sock"
  
  # Start the daemon
  bin/unix_capture -f "$LOG_FILE" -s "$SOCKET_FILE" -u "$provider" -d
  
  # Check if daemon started successfully
  sleep 1
  if [ -S "$SOCKET_FILE" ]; then
    echo "  $provider daemon started successfully."
    # Export socket path for shell scripts
    export "${provider^^}_SOCKET=$SOCKET_FILE"
  else
    echo "  Failed to start $provider daemon!"
  fi
done

echo "All daemons started."
echo ""
echo "Socket paths:"
for provider in "${PROVIDERS[@]}"; do
  SOCKET_FILE="$SOCKET_DIR/$provider.sock"
  if [ -S "$SOCKET_FILE" ]; then
    echo "  $provider: $SOCKET_FILE"
    # Set environment variable
    echo "  export ${provider^^}_SOCKET=$SOCKET_FILE"
  fi
done
.
