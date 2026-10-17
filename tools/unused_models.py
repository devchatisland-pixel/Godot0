"""Writes scripts/assets/unused_models.gd from docs/used_models.tsv (tests/dump_used_models.gd):
every model file and node of the catalog that no slot draws on the map, with its bounding box,
so ModelLibrary does not read it.

  python tools/unused_models.py
"""
import csv

rows = list(csv.DictReader(open("docs/used_models.tsv", encoding="utf-8"), delimiter="\t"))
drawn = {r["source"] for r in rows if r["used"] == "1"}
unused = {}
for r in rows:
    if r["source"] and r["category"] and r["used"] == "0" and r["source"] not in drawn:
        unused[r["source"]] = r
out = ['class_name UnusedModels', 'extends RefCounted',
       '## Models of the library never drawn on the map (made by tools/unused_models.py from',
       '## tests/dump_used_models.gd): ModelLibrary does not read them, it keeps their bounding box only',
       '## (position x y z, size x y z), by "path|node", so that the choice of every other model stays the same.',
       '## Run the two again after a change that puts one of them back on the map.', '',
       'const BOUNDS := {']
for src in sorted(unused):
    out.append('\t"%s": [%s],' % (src, ", ".join(unused[src]["aabb"].split())))
out.append('}')
open("scripts/assets/unused_models.gd", "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
print(len(unused), "unused models,", round(sum(float(r["memory_mb"]) for r in unused.values()), 1), "MB not loaded any more")
