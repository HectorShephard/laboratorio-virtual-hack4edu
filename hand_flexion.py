"""Flexión de índice, medio y anular; el pulgar no participa en el agarre."""
import math
from hand_geometry import valid, REFERENCES

FINGERS = ((5, 6, 7, 8), (9, 10, 11, 12), (13, 14, 15, 16))


def angle(a, b):
    denominator = math.sqrt(sum(x*x for x in a)*sum(x*x for x in b))
    if denominator < 1e-10:
        return None
    return math.degrees(math.acos(max(-1., min(1., sum(x*y for x,y in zip(a,b))/denominator))))


def measure_flexion(points, width, height, world=None):
    use_world = valid(world) and .015 <= max(math.dist(
        (world[a].x,world[a].y,world[a].z),(world[b].x,world[b].y,world[b].z)) for a,b in REFERENCES) <= .3
    coords = [(p.x,p.y,p.z) for p in world] if use_world else [(p.x*width,p.y*height,p.z*width) for p in points]
    def vector(a,b):return [coords[b][i]-coords[a][i] for i in range(3)]
    measurements=[]
    for mcp,pip,dip,tip in FINGERS:
        base=angle(vector(0,mcp),vector(mcp,pip))
        middle=angle(vector(mcp,pip),vector(pip,dip))
        end=angle(vector(pip,dip),vector(dip,tip))
        if any(value is None for value in (base,middle,end)):
            measurements.append(dict(valid=False))
            continue
        measurements.append(dict(valid=True,mcp=base,pip=middle,dip=end,
            bent=middle>=40 or base>=55,
            opened=middle<=22 and base<=35 and end<=30))
    return dict(valid=sum(f['valid'] for f in measurements)>=2,
                representation='world3d' if use_world else 'image3d', fingers=measurements,
                bent_votes=sum(f.get('bent',False) for f in measurements),
                open_votes=sum(f.get('opened',False) for f in measurements))


class Flexion:
    def __init__(self):self.reset()

    def reset(self):
        self.state='unknown'
        self.candidate=None
        self.frames=0

    def update(self, measurement):
        target = ('flexed' if measurement['bent_votes']>=2 else
                  'open' if measurement['open_votes']>=2 else None) if measurement['valid'] else None
        if target is None:
            self.candidate=None
            self.frames=0
        else:
            self.frames=self.frames+1 if target==self.candidate else 1
            self.candidate=target
            if self.frames>=2:self.state=target
        return self.state
