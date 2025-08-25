#!/bin/bash

# Prompt for sudo permissions
if [ "$EUID" -ne 0 ]; then
  echo "This script requires superuser privileges. Please enter your password."
  exec sudo "$0" "$@"
fi

# Define source and destination paths
SOURCE_DIR="./resources"
DEST_DIR="/etc/udev/rules.d"
FILES=("98-steelseries.rules" "98-steelseries-init.py")

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Source directory '$SOURCE_DIR' does not exist."
  exit 1
fi

# Create destination directory if it doesn't exist
if [ ! -d "$DEST_DIR" ]; then
  echo "Creating directory: $DEST_DIR"
  mkdir -p "$DEST_DIR"
fi

# Copy each file to the destination directory
for FILE in "${FILES[@]}"; do
  SOURCE_FILE="$SOURCE_DIR/$FILE"
  DEST_FILE="$DEST_DIR/$FILE"
  
  # Check if source file exists
  if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: Source file '$SOURCE_FILE' does not exist."
    exit 1
  fi
  
  # Copy the file
  echo "Copying $SOURCE_FILE to $DEST_FILE"
  cp "$SOURCE_FILE" "$DEST_FILE"
  
  # Check if copy was successful
  if [ $? -eq 0 ]; then
    echo "Successfully copied $FILE"
  else
    echo "Error: Failed to copy $FILE"
    exit 1
  fi
done

echo "All done. Now either reboot, or, if you know what you're doing, reload udev rules."
exit 0