#!/bin/sh
# Headless checks + screenshots, run inside the "tests" container.
# Results are written to /out (mounted as ./docker-out on the host).
set -e
mkdir -p /out
cd /project

echo "== Generation test"
godot --headless --script res://tests/test_generation.gd

echo "== Urban island, BT tower islet, watchtowers"
godot --headless --script res://tests/test_urban_island.gd

echo "== Top-down zoning map -> /out/map.png"
godot --headless --script res://tests/debug_map.gd -- /out/map.png

echo "== Chunk benchmark"
godot --headless --script res://tests/bench_chunks.gd

echo "== Screenshots (software OpenGL, slow but needs no GPU) -> /out/shot_*.png"
xvfb-run -a -s "-screen 0 1600x900x24" \
    godot --rendering-driver opengl3 --resolution 1600x900 --audio-driver Dummy -- --capture /out

echo "== Done. Files in ./docker-out"
