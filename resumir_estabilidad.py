"""Resume las capturas reales con el mismo margen y escala del cursor de Godot."""
import json
import math
from pathlib import Path
from diagnostico_manos import metrics,screen_point
ROOT=Path(__file__).resolve().parent
summary={
    'viewport':[1100,720],
    'mapping':'clamp((normalized - 0.1) / 0.8) * viewport',
    'comparison':'Crudo y One Euro sobre exactamente las mismas muestras de webcam',
    'real':[],
    'simulated':{'object_swaps':0,'one_hand_loss_stops_flow':True,'other_hand_remains_usable':True,'mouse_poured_ml':25,'initial_ml':100,'remaining_ml':75},
    'pending':['Confirmar visualmente identidad física al cruzar manos y después de oclusión completa','Recorrer el vertido completo con dos manos humanas; la prueba funcional se automatizó con señales simuladas']
}
for label,phase in [('una_mano',0),('despues',1),('despues',2)]:
    source=ROOT/'registros'/('estabilidad_'+label+'.json')
    data=json.loads(source.read_text(encoding='utf-8-sig'))
    frames=[f['packet'] for f in data['frames'] if f['phase']==phase]
    result={'source':str(source.relative_to(ROOT)),'phase':data['phases'][phase]['phase'],'frames':len(frames),'detected_counts':data['phases'][phase]['detected_counts'],'hands':{}}
    for id in range(2):
        hands=[h for p in frames for h in p.get('hands',[]) if h['id']==id and h.get('present')]
        raw=metrics([screen_point(h.get('raw_cursor',h['cursor'])) for h in hands])
        filtered=metrics([screen_point(h['cursor']) for h in hands])
        replay=[]
        previous=None
        stamp=None
        epoch=None
        for packet in frames:
            for hand in packet.get('hands',[]):
                if hand['id']!=id or not hand.get('present'):continue
                target=screen_point(hand.get('raw_cursor',hand['cursor']))
                now=packet['captured_unix']
                if previous is None or hand.get('hand_epoch',0)!=epoch:
                    previous=target
                else:
                    alpha=1-math.exp(-(now-stamp)/.075)
                    previous=[a+(b-a)*alpha for a,b in zip(previous,target)]
                replay.append(previous)
                stamp=now
                epoch=hand.get('hand_epoch',0)
        result['hands'][str(id)]={'raw':raw,'previous_exponential_replay':metrics(replay),'one_euro':filtered,'epochs':len(set(h.get('hand_epoch',0) for h in hands))}
    result['screen_order_changes']=data['phases'][phase].get('screen_order_changes',0)
    summary['real'].append(result)
summary['initial_capture']='registros/estabilidad_antes.json: fase de una mano sin detecciones; fase de dos manos con movimiento, no comparable como reposo'
(ROOT/'docs/verificacion_demo_quimica.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False,indent=2))
