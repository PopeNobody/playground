#!/bin/bash
# End-to-end test for AI Playground
# Tests full workflow: server startup, script generation, execution, validation

set -e

# Set TMUX environment to avoid conflicting with user's session
export TMUX_TMPDIR=$(mktemp -d $PWD/tmp-XXXXXXX)

# Working directory for test artifacts
TEST_DIR=$(mktemp -d)
echo "Using test directory: $TEST_DIR"
cd $TEST_DIR

# Copy necessary files from the original project
ORIG_DIR="$PWD/.."  # Assumes script is run from project root
cp -r $ORIG_DIR/bin $ORIG_DIR/lib .
mkdir -p ai_scripts ai_logs ai_sockets

# Set up the environment for the test
export API_KEY="test_key_123"
export API_MOD="gpt-4o"  # Default model, server will infer the rest

# Start tmux session
TMUX_SESSION="ai-playground-test"
tmux new-session -d -s $TMUX_SESSION -n "e2e-test"

# First pane: Start the server
tmux send-keys -t $TMUX_SESSION "cd $TEST_DIR && PATH=$TEST_DIR/bin:$PATH PERL5LIB=$TEST_DIR/lib:$PERL5LIB ./bin/playground-server" C-m

# Give the server time to start
sleep 2

# Second pane: Run the client test
tmux split-window -h -t $TMUX_SESSION
tmux send-keys -t $TMUX_SESSION "cd $TEST_DIR" C-m

# Function to send a prompt and check response
MAX_TRIES=3
SUCCESS=false

for ((i=1; i<=MAX_TRIES; i++)); do
    echo "Attempt $i of $MAX_TRIES to get a working script..."
    
    # Create the prompt file
    cat > prompt.txt << EOF
Please write a simple "Hello, World!" script in the programming language of your choice.
Make sure to include the appropriate shebang line using /usr/bin/env to find the interpreter.
The script should print exactly "Hello, World!" (without quotes) to the standard output.
EOF

    tmux send-keys -t $TMUX_SESSION "cat prompt.txt" C-m
    tmux send-keys -t $TMUX_SESSION "echo 'Sending prompt to AI...'" C-m
    tmux send-keys -t $TMUX_SESSION "PATH=$TEST_DIR/bin:$PATH PERL5LIB=$TEST_DIR/lib:$PERL5LIB ./bin/ai-cli -i prompt.txt -o response.txt" C-m
    
    # Give AI time to respond
    sleep 5
    
    # Extract code from response
    tmux send-keys -t $TMUX_SESSION "echo 'Extracting script from response...'" C-m
    tmux send-keys -t $TMUX_SESSION "cat response.txt | grep -A 1000 '#!/' | grep -B 1000 -m 1 -P '(\`\`\`|$)' > script.sh" C-m
    tmux send-keys -t $TMUX_SESSION "chmod +x script.sh" C-m
    
    # Execute the script
    tmux send-keys -t $TMUX_SESSION "echo 'Executing script...'" C-m
    tmux send-keys -t $TMUX_SESSION "./script.sh > output.txt 2>&1" C-m
    tmux send-keys -t $TMUX_SESSION "EXIT_CODE=\$?" C-m
    
    # Check output
    tmux send-keys -t $TMUX_SESSION "echo 'Checking output...'" C-m
    tmux send-keys -t $TMUX_SESSION "cat output.txt" C-m
    tmux send-keys -t $TMUX_SESSION "if grep -q 'Hello, World!' output.txt && [ \$EXIT_CODE -eq 0 ]; then echo 'SUCCESS: Script works correctly!'; touch test_success; else echo 'FAILURE: Script did not produce expected output'; fi" C-m
    
    # Give commands time to execute
    sleep 2
    
    # Check if test succeeded
    if [ -f "$TEST_DIR/test_success" ]; then
        SUCCESS=true
        break
    fi
done

# Give tmux a moment to finish executing
sleep 2

# Third pane for log output
tmux split-window -v -t $TMUX_SESSION:0.1
tmux send-keys -t $TMUX_SESSION "cd $TEST_DIR" C-m
tmux send-keys -t $TMUX_SESSION "echo 'Test logs:'" C-m
tmux send-keys -t $TMUX_SESSION "find ai_logs -type f -name '*.log' | sort | tail -n 2 | xargs cat" C-m

# Check final result
if [ "$SUCCESS" = true ]; then
    tmux send-keys -t $TMUX_SESSION "echo 'END-TO-END TEST PASSED!'" C-m
    echo "Test PASSED!"
    exit_code=0
else
    tmux send-keys -t $TMUX_SESSION "echo 'END-TO-END TEST FAILED after $MAX_TRIES attempts!'" C-m
    echo "Test FAILED!"
    exit_code=1
fi

# Attach to the tmux session for the user to see the results
tmux attach-session -t $TMUX_SESSION

# Clean up
rm -rf $TEST_DIR

exit $exit_code
