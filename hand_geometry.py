"""Escala de palma y pinza independientes del ancho aparente de una mano de canto."""
import math

PALM = (0, 5, 9, 13, 17)
REFERENCES = ((0, 9), (0, 5), (0, 17), (5, 17))


def valid(points):
    return points is not None and len(points) == 21 and all(
        math.isfinite(getattr(p, axis)) for p in points for axis in ('x', 'y', 'z'))


def pinch_measure(points, width, height, world=None):
    def pixel(a, b):
        return math.hypot((points[a].x-points[b].x)*width, (points[a].y-points[b].y)*height)
    scale2d = max(pixel(a, b) for a, b in REFERENCES)
    legacy = pixel(4, 8)/max(1., pixel(5, 17))
    if valid(world):
        def distance(a, b):
            return math.dist([getattr(world[a], k) for k in ('x','y','z')],
                             [getattr(world[b], k) for k in ('x','y','z')])
        scale = max(distance(a, b) for a, b in REFERENCES)
        if .015 <= scale <= .3:
            return dict(ratio=distance(4, 8)/scale, middle_ratio=distance(4, 12)/scale,
                        representation='world3d', scale=scale, scale2d=scale2d,
                        legacy_ratio=legacy, close=.50, release=.75,
                        middle_close=.30, middle_release=.48)
    scale = max(1., scale2d)
    return dict(ratio=pixel(4, 8)/scale, middle_ratio=pixel(4, 12)/scale,
                representation='image2d', scale=scale, scale2d=scale2d,
                legacy_ratio=legacy, close=.55, release=.80,
                middle_close=.35, middle_release=.55)
