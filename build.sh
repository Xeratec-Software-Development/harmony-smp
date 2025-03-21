#!/bin/bash

BUILD_REMOTE_DIR="/opt/harmony-smp/webapps/ROOT/WEB-INF/lib/"
# verify that BUILD_REMOTE_USER, BUILD_REMOTE_HOST, and BUILD_SSH_PEM are set
ALL_ARGUMENTS_SET=true
if [ -z "$BUILD_REMOTE_USER" ]; then
  echo "BUILD_REMOTE_USER is not set"
  ALL_ARGUMENTS_SET=false
fi
if [ -z "$BUILD_REMOTE_HOST" ]; then
  echo "BUILD_REMOTE_HOST is not set"
  ALL_ARGUMENTS_SET=false
fi
if [ -z "$BUILD_SSH_PEM" ]; then
  echo "BUILD_SSH_PEM is not set"
  ALL_ARGUMENTS_SET=false
fi

# verify first argument is set
if [ -z "$1" ]; then
  echo "No file specified"
  ALL_ARGUMENTS_SET=false
fi

if [ "$ALL_ARGUMENTS_SET" = false ]; then
  echo "Usage: BUILD_REMOTE_USER=<user> BUILD_REMOTE_HOST=<host> BUILD_SSH_PEM=<path> ./build.sh <file>"
  exit 1
fi

mvn install -DskipTests -DskipITs

# Fetch list of files from the remote directory
echo "==============================="
echo "Stopping harmony..."
echo "==============================="
ssh -i $BUILD_SSH_PEM "$BUILD_REMOTE_USER@$BUILD_REMOTE_HOST" "sudo systemctl stop harmony-smp"

echo "==============================="
echo "Copying file to remote..."
echo "==============================="
scp -i "$BUILD_SSH_PEM" "$1" "$BUILD_REMOTE_USER@$BUILD_REMOTE_HOST:/tmp"
# File needs to be pasted with sudo
ssh -i "$BUILD_SSH_PEM" "$BUILD_REMOTE_USER@$BUILD_REMOTE_HOST" "sudo mv /tmp/$(basename "$1") $BUILD_REMOTE_DIR"

echo "==============================="
echo "Starting harmony..."
echo "==============================="
ssh -i $BUILD_SSH_PEM "$BUILD_REMOTE_USER@$BUILD_REMOTE_HOST" "sudo systemctl start harmony-smp"
