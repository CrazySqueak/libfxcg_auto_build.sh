#!/bin/bash
# This shell script is hereby released into the public domain. See https://unlicense.org/ for more information.
set -e -x -u -o pipefail

# Clean setup files
rm -rf setup/cross
rm -rf setup/build-*/

# Clean setup src directories
for dir in setup/src-*/.git; do
    [[ -e "$dir" ]] || continue  # avoid issue if glob doesn't match
    cd "$dir"/..
    git clean -dfx
done
