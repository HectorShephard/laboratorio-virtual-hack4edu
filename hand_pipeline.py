"""Estado independiente por ID; coordenadas de presentación espejadas una sola vez."""
import math
from hand_identity import HandIdentity
from hand_filters import OneEuro, Pinch
from hand_geometry import pinch_measure, valid, PALM
from hand_flexion import Flexion, measure_flexion

LOSS_GRACE = .55


class HandPipeline:
    def __init__(self, pinch=.35):
        self.identities = HandIdentity()
        self.pinch_offset = pinch-.35
        self.last_time = -1.
        self.last_samples = []
        self.states = [dict(epoch=0, present=False, seen=-100., roll=None,
                            cursor=OneEuro(minimum=1., beta=3.), fingers=OneEuro(minimum=1.8,beta=1.),
                            flexion=Flexion(), open_frames=0, representation=None, angle=OneEuro(minimum=1.5, beta=.5),
                            pinch=Pinch(pinch, pinch+.20), middle=Pinch(pinch, pinch+.20))
                       for _ in range(2)]

    def process(self, detections, now, width, height):
        if now <= self.last_time:
            return self.last_samples
        self.last_time = now
        detections = [d for d in detections if valid(d['points'])]
        for d in detections:
            d['palm'] = [1-sum(d['points'][i].x for i in PALM)/5,
                         sum(d['points'][i].y for i in PALM)/5]
        assigned = dict(self.identities.assign(detections[:2], now))
        hands = []
        for slot, state in enumerate(self.states):
            detection = assigned.get(slot)
            if detection is None:
                if state['present']:
                    state['epoch'] += 1
                state['present'] = False
                # Una oclusión breve no convierte una pinza sostenida en una apertura.
                if now-state['seen'] > LOSS_GRACE:
                    for key in ('cursor', 'angle', 'fingers', 'pinch', 'middle', 'flexion'):
                        state[key].reset()
                    state['roll'] = None
                    state['open_frames'] = 0
                uncertain = slot in self.identities.uncertain_ids
                hands.append(dict(id=slot, present=False, raw_present=uncertain,
                                  sample_time=now, hand_epoch=state['epoch'], identity_uncertain=uncertain))
                continue
            hand = detection['points']
            measure = pinch_measure(hand,width,height,detection.get('world'))
            flex = measure_flexion(hand,width,height,detection.get('world'))
            flex_state = state['flexion'].update(flex)
            measure['close']=max(.05,measure['close']+self.pinch_offset)
            measure['release']=max(measure['close']+.1,measure['release']+self.pinch_offset)
            # Umbrales por representación. Una transición 2D/3D no inventa flancos.
            for key in ('pinch','middle'):
                state[key].close=measure['close'] if key=='pinch' else measure['middle_close']+self.pinch_offset
                state[key].release=measure['release'] if key=='pinch' else measure['middle_release']+self.pinch_offset
            if state['representation'] != measure['representation']:
                state['pinch'].frames=state['middle'].frames=0
            state['representation']=measure['representation']
            closed=state['pinch'].update(measure['ratio'])
            state['open_frames'] = state['open_frames']+1 if measure['ratio']>=measure['release'] else 0
            # Palma estable incluso cuando el pulgar y el índice se cierran.
            raw_cursor = [1-sum(hand[i].x for i in (0,5,9,13,17))/5,
                          sum(hand[i].y for i in (0,5,9,13,17))/5]
            roll = math.atan2((hand[5].y-hand[17].y)*height,
                              (hand[17].x-hand[5].x)*width)
            if state['roll'] is not None:
                roll = state['roll']+(roll-state['roll']+math.pi)%(2*math.pi)-math.pi
            state.update(present=True, seen=now, roll=roll)
            cursor=state['cursor'].update(raw_cursor, now)
            center_z=sum(hand[i].z for i in PALM)/5
            relative=[]
            for p in hand:
                relative.extend([1-p.x-raw_cursor[0],p.y-raw_cursor[1],p.z-center_z])
            filtered=state['fingers'].update(relative,now)
            landmarks=[[round(cursor[0]+filtered[i*3],5),round(cursor[1]+filtered[i*3+1],5),
                        round(filtered[i*3+2],5)] for i in range(21)]
            hands.append(dict(id=slot, present=True, raw_present=True,
                sample_time=now, hand_epoch=state['epoch'], mirrored=True, cursor_anchor='palm',
                handedness=detection['label'], identity_label=self.identities.slots[slot]['label'],
                wrist=detection['wrist'], pinched=closed, open_confirmed=state['open_frames']>=2,
                flexed=flex_state=='flexed', hand_open=flex_state=='open', flex_state=flex_state,
                gesture_valid=flex['valid'], flexion=flex,
                ratio=measure['ratio'], ratio_legacy=measure['legacy_ratio'], ratio_representation=measure['representation'],
                palm_scale=measure['scale'], palm_scale_2d=measure['scale2d'],
                pinch_close=measure['close'], pinch_release=measure['release'],
                middle_pinched=state['middle'].update(measure['middle_ratio']),
                roll=state['angle'].update([roll], now)[0], raw_roll=roll,
                raw_cursor=raw_cursor, cursor=cursor,
                filter='one_euro_v1',
                landmarks=landmarks))
        self.last_samples=hands
        return hands
