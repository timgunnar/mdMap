#!/bin/sh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

case "$(uname -s)" in
  Darwin)  exec "$DIR/mdmap-darwin" "$@" ;;
  Linux)   exec "$DIR/mdmap-linux" "$@" ;;
  *)
    if [ -f "$DIR/mdmap" ]; then
      exec "$DIR/mdmap" "$@"
    else
      echo "mdMap: unsupported platform"
      exit 1
    fi
    ;;
esac
