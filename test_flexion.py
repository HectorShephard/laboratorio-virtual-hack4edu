import copy
import json
import math
import unittest
from pathlib import Path
from types import SimpleNamespace as P
from hand_flexion import measure_flexion
from hand_pipeline import HandPipeline


def detection(x=.3, label='Left', bends=(60,60,0), edge=False, thumb=False, world_mode=True):
    world=[P(x=0.,y=0.,z=0.) for _ in range(21)]
    for i,point in enumerate(((-.04,.015,0),(-.06,.03,0),(-.07,.055,0),(-.08,.08,0)),1):
        world[i]=P(x=point[0],y=point[1],z=point[2])
    if thumb:world[4]=P(x=.08,y=.13,z=.05)
    for index,(mcp,bend) in enumerate(zip((5,9,13),bends)):
        base=((- .025,.06),(0,.065),(.022,.055))[index]
        world[mcp]=P(x=base[0],y=base[1],z=0)
        world[mcp+1]=P(x=base[0],y=base[1]+.03,z=0)
        a=math.radians(bend)
        world[mcp+2]=P(x=base[0],y=base[1]+.03+.022*math.cos(a),z=.022*math.sin(a))
        b=a*1.5
        world[mcp+3]=P(x=base[0],y=world[mcp+2].y+.018*math.cos(b),z=world[mcp+2].z+.018*math.sin(b))
    for i in range(17,21):world[i]=P(x=.04,y=.045+(i-17)*.02,z=0)
    for p in world:
        if label=='Right':p.x=-p.x
        if edge:p.x,p.z=p.x*math.cos(1.4)+p.z*math.sin(1.4),-p.x*math.sin(1.4)+p.z*math.cos(1.4)
    points=[P(x=1-(x+p.x*1.5),y=.55-p.y*1.5*640/480,z=p.z*1.5) for p in world]
    return dict(points=points,world=world if world_mode else None,label=label,score=.98,wrist=[1-points[0].x,points[0].y])


def fixture():
    pipeline=HandPipeline()
    result=[]
    for i in range(30):
        bends=(0,0,0) if i<5 or i>=25 else (60,60,0)
        hands=pipeline.process([detection(.3,'Left',bends,i>=15),detection(.7,'Right',bends,i>=15,True)],i/30,640,480)
        result.append(hands)
    return result


class FlexionTests(unittest.TestCase):
    def test_majority_front_edge_thumb_and_both_representations(self):
        for label in ('Left','Right'):
            for edge in (False,True):
                for world in (False,True):
                    for thumb in (False,True):
                        hand=detection(.3,label,(60,60,0),edge,thumb,world)
                        m=measure_flexion(hand['points'],640,480,hand['world'])
                        self.assertTrue(m['valid'])
                        self.assertEqual(m['bent_votes'],2)
                        self.assertAlmostEqual(m['fingers'][0]['pip'],60)

    def test_hysteresis_new_samples_and_majority_open(self):
        pipeline=HandPipeline()
        pipeline.process([detection()],0,640,480)
        self.assertFalse(pipeline.process([detection()],0,640,480)[0]['flexed'])
        self.assertTrue(pipeline.process([detection()],1/30,640,480)[0]['flexed'])
        for i in range(2,6):
            self.assertTrue(pipeline.process([detection(bends=(30,30,30))],i/30,640,480)[0]['flexed'])
        one=pipeline.process([detection(bends=(0,0,60))],6/30,640,480)[0]
        self.assertFalse(one['hand_open'])
        two=pipeline.process([detection(bends=(0,0,60))],7/30,640,480)[0]
        self.assertTrue(two['hand_open'])
        self.assertFalse(two['flexed'])

    def test_independence_missing_pose_and_invalid_geometry(self):
        pipeline=HandPipeline()
        for i in range(2):hands=pipeline.process([detection(.3),detection(.7,'Right',(0,0,0))],i/30,640,480)
        self.assertTrue(hands[0]['flexed'])
        self.assertTrue(hands[1]['hand_open'])
        hands=pipeline.process([detection(.7,'Right',(0,0,0))],2/30,640,480)
        self.assertFalse(hands[0]['present'])
        hands=pipeline.process([detection(.3),detection(.7,'Right',(0,0,0))],3/30,640,480)
        self.assertTrue(hands[0]['flexed'])
        bad=detection()
        bad['world']=None
        bad['points']=[P(x=.5,y=.5,z=0) for _ in range(21)]
        self.assertFalse(measure_flexion(bad['points'],640,480)['valid'])

if __name__=='__main__':
    import sys
    if '--fixture' in sys.argv:
        Path('registros/flexion_fixture.json').write_text(json.dumps(fixture()),encoding='utf-8')
    else:unittest.main()
