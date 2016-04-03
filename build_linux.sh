#!/bin/bash
set -e
set -x
function dump_syms() {
        EXEC=$1
        SYMBOL_DIR=$2
        TMP_FILE=$(mktemp)
        ../daemon/libs/breakpad/src/tools/linux/dump_syms/dump_syms $EXEC > $TMP_FILE
        NAME=$(head -n1 $TMP_FILE | cut -f 5 -d ' ')
        BUILD_ID=$(head -n1 $TMP_FILE | cut -f 4 -d ' ')
        mkdir -p $SYMBOL_DIR/$NAME/$BUILD_ID
        mv $TMP_FILE $SYMBOL_DIR/$NAME/$BUILD_ID/$NAME.sym
}

make -j10
rm -rf symbols
for f in daemon daemonded daemon-tty; do
        dump_syms $f symbols
        strip $f
done
strip crash_server
zip -r9 linux64 daemon daemonded daemon-tty crash_server nacl_loader irt_core-x86_64.nexe nacl_helper_bootstrap
