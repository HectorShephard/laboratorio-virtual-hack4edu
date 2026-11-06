import copy
import math
import unittest
from hand_geometry import pinch_measure
from hand_pipeline import HandPipeline
from hand_filters import OneEuro
from test_hand_pipeline import detection
from types import SimpleNamespace


class CameraGripTests(unittest.TestCase):
    def test_edge_palm_does_not_inflate_robust_pinch(self):
        hand=detection(.4,'Left',True)
        p=hand['points']
        factor=.012/abs(p[5].x-p[17].x)
        for point in p:point.x=p[0].x+(point.x-p[0].x)*factor
        p[4].y=p[8].y+.025
        measure=pinch_measure(p,640,480)
        self.assertGreater(measure['legacy_ratio'],1)
        self.assertLess(measure['ratio'],measure['close'])
        pipeline=HandPipeline()
        for i in range(8):sample=pipeline.process([hand],i/30,640,480)[0]
        self.assertTrue(sample['present'])
        self.assertTrue(sample['pinched'])

    def test_world_ratio_invariant_under_rotation(self):
        hand=detection(.4,'Left',True)
        world=[SimpleNamespace(x=(p.x-.5)*.5,y=(p.y-.5)*.5,z=0.) for p in hand['points']]
        front=pinch_measure(hand['points'],640,480,world)
        for p in world:p.x,p.z=p.x*math.cos(1.5),p.x*math.sin(1.5)
        side=pinch_measure(hand['points'],640,480,world)
        self.assertEqual(front['representation'],'world3d')
        self.assertAlmostEqual(front['ratio'],side['ratio'])

    def test_unique_samples_and_short_gap_do_not_reset_filter(self):
        filter=OneEuro()
        filter.update([.5,.5],0)
        before=filter.update([.501,.5],.033)
        self.assertEqual(filter.update([.9,.5],.033),before)
        after=filter.update([.51,.5],.133)
        self.assertLess(after[0],.51)
        self.assertGreater(after[0],before[0])
        pipeline=HandPipeline()
        hand=detection(.4,'Left',True)
        first=pipeline.process([hand],0,640,480)
        repeated=pipeline.process([hand],0,640,480)
        self.assertEqual(first,repeated)
        self.assertFalse(repeated[0]['pinched'])
        self.assertTrue(pipeline.process([hand],.033,640,480)[0]['pinched'])

    def test_locked_ambiguous_crossing_cannot_replace_slots(self):
        pipeline=HandPipeline()
        pipeline.process([detection(.3,'Left'),detection(.7,'Right')],0,640,480)
        pipeline.identities.locked_ids={0}
        slots=copy.deepcopy(pipeline.identities.slots)
        samples=pipeline.process([detection(.5,'Right'),detection(.5,'Left')],.033,640,480)
        self.assertTrue(all(not h['present'] for h in samples))
        self.assertEqual(pipeline.identities.slots,slots)

if __name__=='__main__':unittest.main()
