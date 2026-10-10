def sub(path, old, new, count=1):
    s = open(path, encoding='utf-8').read()
    assert old in s, (path, old[:70])
    s = s.replace(old, new, count)
    open(path, 'w', encoding='utf-8', newline='\n').write(s)
P = 'scripts/generation/prop_sites.gd'
sub(P, '''	if fountain.size.x > 0:
		_add(fountain, Kind.FOUNTAIN, 2, 1)
		placed += 1''', '''	if fountain.size.x > 0:
		_add(fountain, Kind.FOUNTAIN, 2, 1)
		placed += 1
	else:
		# The city is built right up to the cinema: the nearest small lot in front of it
		# becomes the fountain (its number stays).
		var at := Vector2(cinema.get_center().x, cinema.end.y + 3)
		var best := -1
		var best_d := 9.0
		for b in _data.building_count():
			var k: int = _data.b_kind[b]
			var r := _data.building_rect(b)
			if (k == Kind.SHOP or k == Kind.OFFICE or k == Kind.APARTMENT or k == Kind.HOUSE) \
					and r.size.x >= 2 and r.size.y >= 2 and r.position.y >= cinema.end.y:
				var d := Vector2(r.get_center()).distance_to(at)
				if d < best_d:
					best_d = d
					best = b
		if best >= 0:
			_data.b_kind[best] = Kind.FOUNTAIN
			placed += 1''')
T = 'tests/test_urban_island.gd'
sub(T, '''		if not seeds.has(s) or Vector2(data.building_rect(b).get_center()).distance_to(port) \
				< Vector2((seeds[s] as Rect2i).get_center()).distance_to(port):''', '''		var ref := port if s == BoatSites.CARGO else Vector2(data.bridge)
		if not seeds.has(s) or Vector2(data.building_rect(b).get_center()).distance_to(ref) \
				< Vector2((seeds[s] as Rect2i).get_center()).distance_to(ref):''')
