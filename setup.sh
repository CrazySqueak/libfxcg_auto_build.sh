#!/bin/bash
# This shell script is hereby released into the public domain. See https://unlicense.org/ for more information.
set -e -u -o pipefail

GCC_URL="https://ftp.gnu.org/gnu/gcc/gcc-14.2.0/gcc-14.2.0.tar.xz"
GCC_XZ_PATH="gcc-src.tar.xz"
GCC_SRC_DIR="src-gcc"
GCC_BUILD_DIR="build-gcc"

BINUTILS_URL="https://ftp.gnu.org/gnu/binutils/binutils-2.43.1.tar.xz"
BINUTILS_XZ_PATH="binutils-src.tar.xz"
BINUTILS_SRC_DIR="src-binutils"
BINUTILS_BUILD_DIR="build-binutils"

CROSS_TARGET_DIR="cross"
GCC_SUCCESS_MARKER=".gcc-build-ok.marker"
BINUTILS_SUCCESS_MARKER=".binutils-build-ok.marker"
MKG3A_SUCCESS_MARKER=".mkg3a-build-ok.marker"

LIBFXCG_GIT_URL="https://github.com/Jonimoose/libfxcg"
LIBFXCG_BRANCH="v0.6"
LIBFXCG_BUILD_DIR="build-libfxcg"
LIBFXCG_ARCHIVE="$LIBFXCG_BUILD_DIR/lib/libfxcg.a"
LIBC_ARCHIVE="$LIBFXCG_BUILD_DIR/lib/libc.a"

MKG3A_GIT_URL="https://gitlab.com/taricorp/mkg3a.git"
MKG3A_BRANCH="master"
MKG3A_SRC_DIR="src-mkg3a"
MKG3A_BUILD_DIR="build-mkg3a"

function count_input_lines {
    # $1 = FORMAT
    awk '{printf "\r'"$1"'",NR} END {printf "\r                                                                \r"}'
}

function download_or_cached {
    # $1 = URL, $2 = PATH
    if [[ ! -f "$2" ]]; then
        curl "$1" -o "$2.tmp"
        mv "$2.tmp" "$2"
    fi
}
function extract_src_skip_root {
    # $1 = FILE, $2 = TARGET
    if [[ ! -d "$2" ]]; then
        # Extract to temp folder to find root dir
        if [[ -d "$2.tmp" ]]; then rm -rf "$2.tmp"; fi
        mkdir -p "$2.tmp" && cd "$2.tmp" # WD = sd/$2.tmp
        tar -xvf "../$1" --xz | count_input_lines "Extracted %s files..."
        OUT_DIR="$(ls -1 | head -1)"
        cd ..  # WD = sd
        # Move into target folder
        if [[ -d "$2" ]]; then rm -rf "$2"; fi
        mv "$2.tmp/$OUT_DIR" "$2"
        rmdir "$2.tmp"
    fi
}

function git_clone_or_pull {
    # $1 = URL, $2 = PATH, $3 = BRANCH
    if [[ ! -d "$2" ]]; then
        git clone --branch "$3" -- "$1" "$2"
    else
        cd "$2"
        git fetch && git fetch --tags
        git checkout --force "$3"
        cd ..
    fi
}

function require_shell_cmd {
    # $1 = NAME
    if [[ -z $(which "$1") ]]; then
        echo "Missing required command: $1. Please install it and try again."
        exit 1
    fi
}
require_shell_cmd curl
require_shell_cmd tar
require_shell_cmd git
require_shell_cmd awk
require_shell_cmd gcc
require_shell_cmd make
require_shell_cmd cmake

set -x

SETUP_ROOT_DIR="setup"
mkdir -p "$SETUP_ROOT_DIR"
cd "$SETUP_ROOT_DIR" # WD = setup_dir

mkdir -p "$CROSS_TARGET_DIR"
CROSS_TARGET_DIR=$(realpath "$CROSS_TARGET_DIR")

####
echo "Building binutils..."
if [[ ! -f "$CROSS_TARGET_DIR/$BINUTILS_SUCCESS_MARKER" ]]; then
    download_or_cached "$BINUTILS_URL" "$BINUTILS_XZ_PATH"
    extract_src_skip_root "$BINUTILS_XZ_PATH" "$BINUTILS_SRC_DIR"
    
    if [[ -d "$BINUTILS_BUILD_DIR" ]]; then rm -rf "$BINUTILS_BUILD_DIR"; fi
    mkdir -p "$BINUTILS_BUILD_DIR"; cd "$BINUTILS_BUILD_DIR" # WD = setup_dir/build-binutils

    ../"$BINUTILS_SRC_DIR"/./configure --target=sh3eb-elf --prefix="$CROSS_TARGET_DIR" --disable-nls
    make -j$(nproc)
    make install

    touch "$CROSS_TARGET_DIR/$BINUTILS_SUCCESS_MARKER"
    cd .. # WD = setup_dir
else echo "Already built.";
fi

####
echo "Building GCC..."
if [[ ! -f "$CROSS_TARGET_DIR/$GCC_SUCCESS_MARKER" ]]; then
    download_or_cached "$GCC_URL" "$GCC_XZ_PATH"
    extract_src_skip_root "$GCC_XZ_PATH" "$GCC_SRC_DIR"

    if [[ -d "$GCC_BUILD_DIR" ]]; then rm -rf "$GCC_BUILD_DIR"; fi
    mkdir -p "$GCC_BUILD_DIR"; cd "$GCC_BUILD_DIR" # WD = setup_dir/build-gcc

    export PATH="$PATH:$CROSS_TARGET_DIR/bin"
    ../"$GCC_SRC_DIR"/./configure --target=sh3eb-elf --prefix="$CROSS_TARGET_DIR" --disable-nls --enable-languages=c,c++ --without-headers
    make -j$(nproc) all-gcc all-target-libgcc
    make install-gcc install-target-libgcc

    touch "$CROSS_TARGET_DIR/$GCC_SUCCESS_MARKER"
    cd .. # WD = setup_dir
else echo "Already built.";
fi

#### cross-compiler is now built, so ensure it's in PATH
export PATH="$PATH:$CROSS_TARGET_DIR/bin"

#### 
echo "Building libfxcg..."
if [[ ! -f "$LIBFXCG_ARCHIVE" ]] || [[ ! -f "$LIBC_ARCHIVE" ]]; then
    git_clone_or_pull "$LIBFXCG_GIT_URL" "$LIBFXCG_BUILD_DIR" "$LIBFXCG_BRANCH"
    cd "$LIBFXCG_BUILD_DIR"  # WD = setup_dir/build-libfxcg
    
    make -j$(nproc)
    
    cd ..
else echo "Already built.";
fi

####
echo "Building mkg3a..."
if [[ ! -f "$CROSS_TARGET_DIR/$MKG3A_SUCCESS_MARKER" ]]; then
    git_clone_or_pull "$MKG3A_GIT_URL" "$MKG3A_SRC_DIR" "$MKG3A_BRANCH"
    
    if [[ -d "$MKG3A_BUILD_DIR" ]]; then rm -rf "$MKG3A_BUILD_DIR"; fi
    mkdir -p "$MKG3A_BUILD_DIR"; cd "$MKG3A_BUILD_DIR" # WD = setup_dir/build-mkg3a
    
    cmake -DCMAKE_INSTALL_PREFIX:PATH="$CROSS_TARGET_DIR" ../"$MKG3A_SRC_DIR"/.
    make -j$(nproc)
    make install
    
    touch "$CROSS_TARGET_DIR/$MKG3A_SUCCESS_MARKER"
    cd ..  # WD = setup_dir
else echo "Already built.";
fi