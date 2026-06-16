#!/bin/bash
set -e

cd "$(dirname "$0")"

NATIVE_ARCH=$(go env GOARCH)

echo "Building mdmap (native ${NATIVE_ARCH})..."
go build -o mdmap .

echo "Building mdmap-darwin (macOS ${NATIVE_ARCH})..."
GOOS=darwin GOARCH=${NATIVE_ARCH} go build -o mdmap-darwin .

echo "Building mdmap-linux (Linux amd64)..."
GOOS=linux GOARCH=amd64 go build -o mdmap-linux .

echo "Building mdmap-windows.exe (Windows amd64)..."
GOOS=windows GOARCH=amd64 go build -o mdmap-windows.exe .

echo "Done:"
ls -lh mdmap mdmap-darwin mdmap-linux mdmap-windows.exe
