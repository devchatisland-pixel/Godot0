"""Takes the sand bags off the roofs of the military post (FREEMODELS/curated/checkpoint.glb:
the jail of the prison island and the Golden Gate checkpoint). They are the brown islands (about
12 000 triangles) lying on the two roofs, above 1.3 m; the roofs themselves, the towers and the
rest of the post stay as they are.

Usage:  python tools/remove_checkpoint_sandbags.py
Needs:  numpy, Pillow (and tools/make_night_variants.py next to it).
"""
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_night_variants as m

PATH = os.path.join(m.CUR, 'checkpoint.glb')
## Colour (sRGB) of the sand bags in the texture of the post, and how far a face may be from it.
SAND = np.array([0.42, 0.32, 0.23])


def main():
    g = m.GLB(PATH)
    tri = m.Triangles(g)
    isl = tri.islands()
    col = m.to_srgb(tri.colours())
    drop = np.zeros(len(isl), bool)
    count = 0
    for k in np.unique(isl):
        sel = isl == k
        if tri.pos[sel][..., 1].min() >= 1.3 and np.abs(col[sel].mean(0) - SAND).max() < 0.03:
            drop |= sel
            count += 1
    print('  %d sand bag groups, %d of %d triangles' % (count, drop.sum(), len(drop)))
    assert count == 4, 'expected the 4 groups of the two roofs, found %d' % count
    m.drop_triangles(tri, drop)
    m.write_geometry(g, tri)
    g.save(PATH)


if __name__ == '__main__':
    main()
