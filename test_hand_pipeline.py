"""Señales sintéticas por la misma cadena que usa seguimiento.py; no son webcam real."""
import json
import unittest
from types import SimpleNamespace
from hand_pipeline import HandPipeline


def detection(x, label, closed=False, y=.52):
    # Coordenadas anatómicas de prueba; inference X aún NO está espejada.
    shape = [(0,.12),(-.05,.08),(-.09,.04),(-.13,0),(-.16,-.04),
             (-.06,0),(-.07,-.07),(-.07,-.13),(-.07,-.19),
             (-.02,-.02),(-.02,-.10),(-.02,-.17),(-.02,-.22),
             (.02,-.01),(.03,-.09),(.03,-.15),(.03,-.20),
             (.06,.015),(.08,-.05),(.09,-.10),(.10,-.15)]
    if closed:
        shape[4] = (-.065,-.08)
        shape[8] = (-.06,-.08)
    points = [SimpleNamespace(x=1-(x+dx*.55), y=y+dy*.55, z=-.01 if i in (4,8) else 0.)
              for i,(dx,dy) in enumerate(shape)]
    return dict(points=points, label=label, score=.96,
                wrist=[1-points[0].x,points[0].y])


def transport_frames():
    pipeline = HandPipeline()
    frames=[]
    for i in range(150):
        if i<20: detections=[detection(.3,'Left')]
        elif i<40: detections=[detection(.7,'Right'),detection(.3,'Left')]
        elif i<80:
            x=.3+(i-40)/39*.4
            detections=[detection(1-x,'Right'),detection(x,'Left')]
            if i%2: detections.reverse()
        elif i<88: detections=[detection(.3,'Right')]
        else: detections=[detection(.7,'Left'),detection(.3,'Right')]
        frames.append(dict(type='frame',seq=i,synthetic=True,
                           hands=pipeline.process(detections,i/30,640,480)))
    return frames


class PipelineTests(unittest.TestCase):
    def test_enter_both_orders_and_return(self):
        for first in ['Left','Right']:
            pipeline=HandPipeline()
            hands=[detection(.25,'Left'),detection(.75,'Right')]
            alone=hands[0 if first=='Left' else 1]
            samples=pipeline.process([alone],0,640,480)
            first_id=next(h['id'] for h in samples if h['present'])
            for i in range(1,10):
                result=pipeline.process(hands[::-1] if i%2 else hands,i/30,640,480)
                self.assertEqual(sum(h['present'] for h in result),2)
                self.assertEqual(result[first_id]['identity_label'],first)
                self.assertEqual(len(result[0]['landmarks']),21)
                self.assertEqual(len(result[1]['landmarks']),21)

    def test_palm_is_stationary_when_pinching_and_mirror_once(self):
        pipeline=HandPipeline()
        opened=pipeline.process([detection(.3,'Left')],0,640,480)[0]
        for i in range(1,4):closed=pipeline.process([detection(.3,'Left',True)],i/30,640,480)[0]
        self.assertTrue(closed['pinched'])
        self.assertEqual(opened['raw_cursor'],closed['raw_cursor'])
        self.assertAlmostEqual(closed['wrist'][0],.3)
        self.assertEqual(closed['cursor_anchor'],'palm')

    def test_short_loss_preserves_pinch_only_for_that_hand(self):
        pipeline=HandPipeline()
        for i in range(4):
            result=pipeline.process([detection(.3,'Left',True),detection(.7,'Right',True)],i/30,640,480)
        for i in range(4,10):
            result=pipeline.process([detection(.7,'Right',True)],i/30,640,480)
            self.assertFalse(result[0]['present'])
            self.assertTrue(result[1]['pinched'])
        result=pipeline.process([detection(.3,'Left',True),detection(.7,'Right',True)],.34,640,480)
        self.assertTrue(result[0]['pinched'])
        self.assertTrue(result[1]['pinched'])
        self.assertEqual(result[0]['hand_epoch'],1)
        self.assertEqual(result[1]['hand_epoch'],0)

    def test_order_label_flicker_crossing_and_occlusion(self):
        frames=transport_frames()
        for frame in frames:
            for hand in frame['hands']:
                if hand['present']:
                    self.assertEqual(hand['identity_label'],'Left' if hand['id']==0 else 'Right')
                    left_x=.3 if frame['seq']<40 else (.3+(frame['seq']-40)/39*.4 if frame['seq']<80 else .7)
                    self.assertAlmostEqual(hand['wrist'][0],left_x if hand['id']==0 else 1-left_x)
        self.assertTrue(all(h['present'] for h in frames[-1]['hands']))
        pipeline=HandPipeline()
        pipeline.process([detection(.3,'Left'),detection(.7,'Right')],0,640,480)
        changed=pipeline.process([detection(.31,'Right'),detection(.69,'Right')],.033,640,480)
        self.assertEqual(changed[0]['identity_label'],'Left')
        self.assertTrue(all(h['present'] for h in changed))


if __name__=='__main__':
    import sys
    if '--fixture' in sys.argv:
        from pathlib import Path
        destination=Path('registros/manos_pipeline_fixture.json')
        destination.parent.mkdir(exist_ok=True)
        destination.write_text(json.dumps(transport_frames()),encoding='utf-8')
        print(destination)
    else: unittest.main()
