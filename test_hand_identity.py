import unittest
from hand_identity import HandIdentity
from hand_filters import OneEuro, Pinch
import random
import math

def hand(x, label):
    return dict(center=[x,.5],label=label,score=.95)

class IdentityTests(unittest.TestCase):
    def test_ambiguous_overlap_keeps_slots(self):
        tracker=HandIdentity()
        tracker.assign([hand(.2,'Left'),hand(.8,'Right')],0)
        previous=[slot.copy() for slot in tracker.slots]
        self.assertEqual(tracker.assign([hand(.5,'Right'),hand(.5,'Left')],.1),[])
        self.assertEqual(tracker.slots,previous)
        self.assertEqual(tracker.uncertain_ids,[0,1])

    def test_label_flicker_does_not_replace_wrist_trajectory(self):
        tracker=HandIdentity()
        tracker.assign([hand(.2,'Left'),hand(.8,'Right')],0)
        assigned=tracker.assign([hand(.21,'Right'),hand(.79,'Right')],.03)
        self.assertEqual(assigned[0][0],0)
        self.assertEqual(assigned[1][0],1)

    def test_pinch_hysteresis(self):
        pinch=Pinch()
        for _ in range(3):pinch.update(.3)
        self.assertTrue(pinch.closed)
        for ratio in [.36,.4,.54,.38,.5]:self.assertTrue(pinch.update(ratio))
        pinch.update(.6)
        self.assertFalse(pinch.update(.6))
        for ratio in [.4,.5,.39]:self.assertFalse(pinch.update(ratio))

    def test_one_euro_reduces_noise_and_tracks_motion(self):
        randomizer=random.Random(2026)
        filtered=OneEuro()
        raw=[]
        smooth=[]
        for index in range(150):
            point=[.5+randomizer.gauss(0,.004),.5+randomizer.gauss(0,.004)]
            result=filtered.update(point,index/30)
            if index>20:
                raw.append(sum((p-.5)**2 for p in point))
                smooth.append(sum((p-.5)**2 for p in result))
        self.assertLess(sum(smooth),sum(raw)*.4)
        for index in range(10):result=filtered.update([.8,.5],5+index/30)
        self.assertLess(math.dist(result,[.8,.5]),.03)
        other=OneEuro()
        self.assertEqual(other.update([.1,.2],0),[.1,.2])

    def test_cross_and_return(self):
        tracker=HandIdentity()
        first=tracker.assign([hand(.2,'Left'),hand(.8,'Right')],0)
        ids={d['label']:i for i,d in first}
        for step in range(1,11):
            x=.2+step*.06
            assigned=tracker.assign([hand(1-x,'Right'),hand(x,'Left')],step*.1)
            if not assigned:
                self.assertLess(abs(1-2*x),.035)
                self.assertEqual(tracker.uncertain_ids,[0,1])
            else:
                self.assertEqual({d['label']:i for i,d in assigned},ids)
        one=tracker.assign([hand(.18,'Right')],1.1)
        self.assertEqual(one[0][0],ids['Right'])
        restored=tracker.assign([hand(.75,'Left'),hand(.2,'Right')],1.8)
        self.assertEqual({d['label']:i for i,d in restored},ids)

if __name__=='__main__': unittest.main()
