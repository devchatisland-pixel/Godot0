class_name BakedModels
extends Resource
## The model library as it is once every model file is loaded and merged (ModelLibrary):
## saved by tools/bake.gd when the web build is made, so the game reads one file at start
## instead of opening and merging a hundred model files. See ModelLibrary.save_bake.

@export var key := ""
@export var meshes: Array[Mesh] = []
@export var bounds: Array[AABB] = []
@export var road_masks := PackedInt32Array()
@export var names := PackedStringArray()
@export var cats := PackedInt32Array()
## Category -> PackedInt32Array of mesh ids.
@export var by_cat := {}
## Name -> mesh id of the models loaded by name (vehicles, shops, props, fences, containers).
@export var named := {}
