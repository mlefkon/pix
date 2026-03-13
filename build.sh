#!/bin/bash

SCRIPT_DIR="$(dirname $(realpath -- "$0"))"

docker build \
    -f "$SCRIPT_DIR/pix.dockerfile" \
    -t mlefkon/pix-nanogallery2 \
    "$SCRIPT_DIR"