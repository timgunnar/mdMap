#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Building mdmap-darwin (macOS amd64)..."
GOOS=darwin GOARCH=amd64 go build -o mdmap-darwin .

echo "Building mdmap-linux (Linux amd64)..."
GOOS=linux GOARCH=amd64 go build -o mdmap-linux .

echo "Building mdmap-windows.exe (Windows amd64)..."
GOOS=windows GOARCH=amd64 go build -o mdmap-windows.exe .

echo "Done:"
ls -lh mdmap-darwin mdmap-linux mdmap-windows.exe
