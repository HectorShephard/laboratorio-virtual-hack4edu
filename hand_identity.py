"""Identidad por muñeca predicha; lateralidad solo como apoyo, nunca orden X."""
import itertools
import math

class HandIdentity:
    def __init__(self):
        self.slots=[None,None]
        self.uncertain_ids=[]
        self.locked_ids=set()

    def assign(self,detections,now):
        self.uncertain_ids=[]
        detections=detections[:2]
        if not detections:return []
        def wrist(detection):return detection['wrist'] if 'wrist' in detection else detection['center']
        def cost(slot,detection):
            previous=self.slots[slot]
            if previous is None:
                # Solo al crear un ID. Nunca ordenar por X ni renumerar al entrar otra mano.
                return .65 + (.02 if detection['label'] != ('Left' if slot==0 else 'Right') else 0)
            gap=now-previous['time']
            prediction=[previous['wrist'][i]+previous['velocity'][i]*min(gap,.12) for i in range(2)]
            distance=math.dist(prediction,wrist(detection))
            if previous.get('palm') and detection.get('palm'):
                distance=.7*distance+.3*math.dist(previous['palm'],detection['palm'])
            # Una etiqueta que parpadea no debe vencer la trayectoria observada.
            mismatch=previous['label']!=detection['label']
            support=(.12 if gap>.35 else .045)*float(detection.get('score',.5)) if mismatch else 0
            return distance+support
        choices=list(itertools.permutations(range(2),len(detections)))
        choices.sort(key=lambda ids:sum(cost(i,d) for i,d in zip(ids,detections)))
        ids=choices[0]
        if len(detections)==2 and all(self.slots) and math.dist(wrist(detections[0]),wrist(detections[1]))<.035:
            self.uncertain_ids=[0,1]
            return []
        if all(self.slots) and len(choices)>1:
            margin=sum(cost(i,d) for i,d in zip(choices[1],detections))-sum(cost(i,d) for i,d in zip(ids,detections))
            if margin<(.05 if self.locked_ids else .025):
                self.uncertain_ids=list(ids)
                return []
        accepted=[]
        for slot,detection in zip(ids,detections):
            previous=self.slots[slot]
            if previous:
                gap=now-previous['time']
                # No teletransportar un ID a una detección de identidad dudosa.
                if cost(slot,detection)>(.24 if slot in self.locked_ids else (.8 if gap>.35 else .30)):
                    self.uncertain_ids.append(slot)
                    continue
            position=list(wrist(detection))
            dt=max(.001,now-previous['time']) if previous else 1
            velocity=[(position[i]-previous['wrist'][i])/dt for i in range(2)] if previous and dt<.3 else [0,0]
            if previous and dt<.3:velocity=[.55*v+.45*p for v,p in zip(velocity,previous['velocity'])]
            self.slots[slot]=dict(wrist=position,palm=detection.get('palm'),velocity=velocity,time=now,label=previous['label'] if previous else detection['label'])
            accepted.append((slot,detection))
        return accepted
