#!/bin/bash
OLDPWD=`pwd`;
MINGW32_DIR="/usr/i686-w64-mingw32/bin"
MINGW64_DIR="/usr/x86_64-w64-mingw32/bin"

if [ ! -d $1 ]; then
	echo "Please pass the pass to the Unvanquished git repo"
	exit 1
fi

cd $1
if [[ -z `git remote -v | grep Unvanquished/Unvanquished` ]]; then
	echo "Not the Unvanquished git repo!"
	exit 1
fi

# Build VMs
if [ -e rel ]; then
	rm -rf rel
fi
mkdir rel
cd rel
cmake -DBUILD_CLIENT=OFF -DBUILD_GAME_NATIVE_EXE=OFF -DBUILD_GAME_NATIVE_DLL=OFF -DBUILD_SERVER=OFF -DBUILD_TTY_CLIENT=OFF -DCMAKE_BUILD_TYPE=Release ..
make -j10
cd ..

# Build Win32
if [ -e win32 ]; then
	rm -rf win32
fi
mkdir win32
cd win32
cmake -DBUILD_CLIENT=ON -DBUILD_GAME_NATIVE_EXE=OFF -DBUILD_GAME_NATIVE_DLL=OFF -DBUILD_SERVER=ON -DBUILD_TTY_CLIENT=ON -D BUILD_GAME_NACL=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=cmake/cross-toolchain-mingw32.cmake ..
make -j10
cp $MINGW32_DIR/{libgcc_s_sjlj-1.dll,libstdc++-6.dll,libwinpthread-1.dll} .
zip -9 win32 *.exe *.dll *.nexe
cd ..

# Build Win64
if [ -e win64 ]; then
	rm -rf win64
fi
mkdir win64
cd win64
cmake -DBUILD_CLIENT=ON -DBUILD_GAME_NATIVE_EXE=OFF -DBUILD_GAME_NATIVE_DLL=OFF -DBUILD_SERVER=ON -DBUILD_TTY_CLIENT=ON -D BUILD_GAME_NACL=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=cmake/cross-toolchain-mingw64.cmake ..
make -j10
cp $MINGW64_DIR/{libgcc_s_seh-1.dll,libstdc++-6.dll,libwinpthread-1.dll} .
zip -9 win64 *.exe *.dll *.nexe
cd ..
