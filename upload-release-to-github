#!/bin/bash
set -e
set -x
set -v

# GitHub Auth token. Generate one from settings.
export GITHUB_TOKEN="..."

#GitHub User
export GITHUB_USER="Unvanquished"
export GITHUB_REPO="Unvanquished"

ALPHA=$1
FILE=$2

# github-release binary
# Get it with "go get github.com/aktau/github-release"
GR="$HOME/gocode/bin/github-release"

$GR release \
        --tag "v0.$ALPHA.0" \
        --name "Alpha $ALPHA Release" \
        --description "Alpha $ALPHA release for unvanquished" \
        --pre-release \
        --draft \

$GR upload \
        --tag "v0.$ALPHA.0" \
        --name $(basename $FILE) \
        --file $FILE
