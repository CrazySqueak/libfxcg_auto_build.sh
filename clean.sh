#!/bin/bash
# This shell script is hereby released into the public domain. See https://unlicense.org/ for more information.
set -e -x -u -o pipefail

# Clean build files
rm -rf build/cross
rm -rf build/build-*/

# Clean build src directories of any build files (for deps that don't support configure)
for dir in build/src-*/.git; do
    [[ -e "$dir" ]] || continue  # avoid issue if glob doesn't match
    cd "$dir"/..
    git clean -dfx
done

# Clean output
rm -rf cross
rm -rf libfxcg