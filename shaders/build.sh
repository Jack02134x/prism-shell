#!/bin/sh
# Recompile the fragment shaders to .qsb (needs qt6-shadertools).
cd "$(dirname "$0")" || exit 1
for f in *.frag; do
    /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$f.qsb" "$f" && echo "built $f.qsb"
done
