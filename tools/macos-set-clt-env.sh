#!/usr/bin/env bash

cat >> ~/.bashrc <<'EOF'
export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX13.sdk
export CPLUS_INCLUDE_PATH="$SDKROOT/usr/include/c++/v1"
EOF
