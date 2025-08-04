#!/bin/bash

# Test script for the interactive clone_app.sh
# This simulates user inputs to test the interactive mode

echo "Testing interactive clone_app.sh script..."
echo ""

# Test 1: Basic interaction with defaults
echo "Test 1: Using all defaults (just pressing Enter)"
echo "Expected: Should use current directory name as source, 'mynewapp' as new name"
echo ""

# Create test inputs
cat > test_inputs.txt << EOF

mynewapp

y
./idlibykilo
y
./idlibykilo/idlibykilo.jks
idlibykilo
idlibykilo
y
EOF

# Run the script with test inputs
echo "Running script with test inputs..."
cat test_inputs.txt | ./clone_app.sh

# Clean up
rm -f test_inputs.txt

echo ""
echo "Test completed!" 