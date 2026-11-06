import math
import unittest
from types import SimpleNamespace
from hand_pipeline import HandPipeline
from hand_geometry import pinch_measure, REFERENCES
from test_hand_pipeline import detection


def hand_at_ratio(x, label, ratio, world_mode, edge=False):
    hand=detection(x,label)
    points=hand['points']
    if world_mode:
        world=[SimpleNamespace(x=(p.x-.5)*.5,y=(p.y-.5)*.5,z=0.) for p in points]
        scale=max(math.dist((world[a].x,world[a].y,world[a].z),(world[b].x,world[b].y,world[b].z)) for a,b in REFERENCES)
        world[4]=SimpleNamespace(x=world[8].x+ratio*scale,y=world[8].y,z=world[8].z)
        if edge:
            for p in world:p.x,p.z=p.x*math.cos(1.4),p.x*math.sin(1.4)
        hand['world']=world
    else:
        if edge:
            for p in points:p.x=points[0].x+(p.x-points[0].x)*.15
        measure=pinch_measure(points,640,480)
        points[4]=SimpleNamespace(x=points[8].x+ratio*measure['scale']/640,y=points[8].y,z=0.)
    return hand


class SoftControlsTests(unittest.TestCase):
    def test_soft_pinch_and_clear_release_for_both_hands_front_and_edge(self):
        for world in (False,True):
            for edge in (False,True):
                with self.subTest(world=world,edge=edge):
                    pipeline=HandPipeline()
                    t=0.
                    def step(left,right):
                        nonlocal t
                        t+=1/30
                        return pipeline.process([hand_at_ratio(.25,'Left',left,world,edge),hand_at_ratio(.75,'Right',right,world,edge)],t,640,480)
                    for _ in range(2):hands=step(.95,.95)
                    self.assertTrue(all(h['open_confirmed'] for h in hands))
                    for _ in range(2):hands=step(.45,.95)
                    self.assertTrue(hands[0]['pinched'])
                    self.assertFalse(hands[1]['pinched'])
                    self.assertGreater(hands[0]['ratio'],.35) # puntas todavía separadas
                    for _ in range(2):hands=step(.65,.45)
                    self.assertTrue(all(h['pinched'] for h in hands))
                    for _ in range(2):hands=step(.95,.65)
                    self.assertFalse(hands[0]['pinched'])
                    self.assertTrue(hands[1]['pinched'])
                    self.assertAlmostEqual(pipeline.states[1]['middle'].close,.30 if world else .35)
                    for _ in range(2):hands=step(.95,.95)
                    self.assertTrue(all(not h['pinched'] for h in hands))

if __name__=='__main__':unittest.main()
