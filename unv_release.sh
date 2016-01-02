#!/bin/bash

set -x
set -v
set -e

OLDPWD=`pwd`;
MINGW32_DIR="/usr/i686-w64-mingw32/bin"
MINGW64_DIR="/usr/x86_64-w64-mingw32/bin"
DUMP_SYMS_LINUX="$HOME/unv/breakpad/src/tools/linux/dump_syms/dump_syms"
DUMP_SYMS_WINDOWS="wine $HOME/unv/breakpad-win/src/tools/windows/dump_syms_dwarf/dump_syms.exe"

function dump_syms() {
	EXEC=$1
	SYMBOL_DIR=$2
	TMP_FILE=$(mktemp)
	$DUMP_SYMS_LINUX $EXEC > $TMP_FILE
	NAME=$(head -n1 $TMP_FILE | cut -f 5 -d ' ')
	BUILD_ID=$(head -n1 $TMP_FILE | cut -f 4 -d ' ')
	mkdir -p $SYMBOL_DIR/$NAME/$BUILD_ID
	mv $TMP_FILE $SYMBOL_DIR/$NAME/$BUILD_ID/$NAME.sym
}

function dump_syms_win() {
	EXEC=$(readlink -f $1)
	SYMBOL_DIR=$(readlink -f $2)
	pushd ../win32
	TMP_FILE=$(mktemp)
	$DUMP_SYMS_WINDOWS $EXEC > $TMP_FILE
	dos2unix $TMP_FILE
	NAME=$(head -n1 $TMP_FILE | cut -f 5 -d ' ')
	BUILD_ID=$(head -n1 $TMP_FILE | cut -f 4 -d ' ')
	mkdir -p $SYMBOL_DIR/$NAME/$BUILD_ID
	mv $TMP_FILE $SYMBOL_DIR/$NAME/$BUILD_ID/$NAME.sym
	popd
}

if [ ! -d $1 ]; then
	echo "Please pass the pass to the Unvanquished git repo"
	exit 1
fi

cd $1
if [[ -z `git remote -v | grep Unvanquished/Unvanquished` ]]; then
	echo "Not the Unvanquished git repo!"
	exit 1
fi

# Delete breakpad symbols
if [ -e symbols ]; then
	rm -rf symbols
fi

# # Build VMs
if [ -e rel ]; then
	rm -rf rel
fi
mkdir rel
cd rel
cmake -DBUILD_CLIENT=OFF -DBUILD_GAME_NATIVE_EXE=OFF -DBUILD_GAME_NATIVE_DLL=OFF -DBUILD_SERVER=OFF -DBUILD_TTY_CLIENT=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
make -j10
for vm in sgame cgame; do
	ln -s $vm-x86.nexe main.nexe
	dump_syms main.nexe ../symbols
	rm main.nexe
	ln -s $vm-x86_64.nexe main.nexe
	dump_syms main.nexe ../symbols
	rm main.nexe
done
cd ..

# Build Win32
if [ -e win32 ]; then
	rm -rf win32
fi
mkdir win32
cd win32
cmake -DBUILD_CLIENT=ON -DBUILD_GAME_NATIVE_EXE=OFF -DBUILD_GAME_NATIVE_DLL=OFF -DBUILD_SERVER=ON -DBUILD_TTY_CLIENT=ON -D BUILD_GAME_NACL=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo -DUSE_BREAKPAD=ON -DCMAKE_TOOLCHAIN_FILE=daemon/cmake/cross-toolchain-mingw32.cmake ..
make -j10
cp $MINGW32_DIR/{libgcc_s_sjlj-1.dll,libstdc++-6.dll,libwinpthread-1.dll} .
for f in daemon*.exe; do
	dump_syms_win $f ../symbols
	i686-w64-mingw32-strip $f
done

zip -9 win32 *.exe *.dll *.nexe
cd ..

# Build Win64
if [ -e win64 ]; then
	rm -rf win64
fi
mkdir win64
cd win64
cmake -DBUILD_CLIENT=ON -DBUILD_GAME_NATIVE_EXE=OFF -DBUILD_GAME_NATIVE_DLL=OFF -DBUILD_SERVER=ON -DBUILD_TTY_CLIENT=ON -D BUILD_GAME_NACL=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo -DUSE_BREAKPAD=ON -DCMAKE_TOOLCHAIN_FILE=daemon/cmake/cross-toolchain-mingw64.cmake ..
make -j10
cp $MINGW64_DIR/{libgcc_s_seh-1.dll,libstdc++-6.dll,libwinpthread-1.dll} .
for f in daemon*.exe; do
	dump_syms_win $f ../symbols
	x86_64-w64-mingw32-strip $f
done
zip -9 win64 *.exe *.dll *.nexe
cd ..
