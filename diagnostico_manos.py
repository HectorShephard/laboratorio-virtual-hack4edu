"""Medición local sin grabar imágenes. Las fases guiadas necesitan colaboración humana."""
import argparse
import json
import math
import statistics
import threading
import time
from pathlib import Path
import seguimiento

ROOT = Path(__file__).resolve().parent

def screen_point(point):
    return [max(0,min(1,(point[i]-.1)/.8))*[1100,720][i] for i in range(2)]

def metrics(points):
    if len(points) < 2:
        return {'samples': len(points), 'rms_px': None, 'step_p95_px': None}
    mean = [statistics.mean(p[i] for p in points) for i in range(2)]
    rms = math.sqrt(statistics.mean(sum((p[i]-mean[i])**2 for i in range(2)) for p in points))
    steps = sorted(math.dist(a,b) for a,b in zip(points,points[1:]))
    return {'samples':len(points),'rms_px':round(rms,3),'step_p95_px':round(steps[round(.95*(len(steps)-1))],3)}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--label',default='antes')
    parser.add_argument('--camera',type=int,default=0)
    parser.add_argument('--single',action='store_true',help='Esperar una sola mano y medir cinco segundos continuos')
    args=parser.parse_args()
    cv2,mp,np=__import__('prueba_camara').load_dependencies()
    stop=threading.Event()
    frames=[]
    first=None
    single_started=None
    opened_at=time.monotonic()
    phases=['UNA MANO QUIETA (5 s)','DOS MANOS QUIETAS (5 s)','CRUZA LAS MANOS (5 s)']
    def receive(packet):
        nonlocal first,single_started
        if packet.get('type')!='frame':
            print(packet,flush=True)
            return
        now=time.monotonic()
        if first is None:first=now
        elapsed=now-first
        phase=min(2,int(elapsed//8))
        local=elapsed-phase*8
        canvas=np.full((600,900,3),(22,28,35),dtype=np.uint8)
        title=('PREPARATE: '+str(max(1,3-int(local))) if local<3 else phases[phase])
        cv2.putText(canvas,title,(30,45),cv2.FONT_HERSHEY_SIMPLEX,.8,(200,225,245),2)
        hands=packet.get('hands',[dict(packet,id=0)])
        if args.single:
            count=sum(bool(h.get('present')) for h in hands)
            if count!=1:
                single_started=None
                frames.clear()
            elif single_started is None:
                single_started=now
            phase=0
            local=now-single_started if single_started is not None else 0
            cv2.rectangle(canvas,(0,0),(900,70),(22,28,35),-1)
            title=('MUESTRA SOLO UNA MANO QUIETA' if single_started is None else 'UNA MANO: '+str(round(max(0,8-local),1))+' s')
            cv2.putText(canvas,title,(30,45),cv2.FONT_HERSHEY_SIMPLEX,.8,(200,225,245),2)
        for hand in hands:
            if not hand.get('present'):continue
            color=(50,180,245) if hand['id']==0 else (220,210,180)
            for p in hand.get('landmarks',[]):cv2.circle(canvas,(int(p[0]*900),int(p[1]*600)),4,color,-1)
            cursor=hand.get('cursor',[.5,.5])
            cv2.putText(canvas,'ID '+str(hand['id'])+' '+hand.get('handedness',''),(int(cursor[0]*900),int(cursor[1]*600)),cv2.FONT_HERSHEY_SIMPLEX,.7,color,2)
            raw=hand.get('raw_cursor',cursor)
            cv2.circle(canvas,(int(raw[0]*900),int(raw[1]*600)),8,(70,70,245),1)
            cv2.circle(canvas,(int(cursor[0]*900),int(cursor[1]*600)),8,color,2)
        cv2.putText(canvas,'Manos detectadas: '+str(sum(bool(h.get('present')) for h in hands)),(30,90),cv2.FONT_HERSHEY_SIMPLEX,.65,(200,225,245),1)
        cv2.putText(canvas,'Q: terminar | Imagen espejada | No se guardan imagenes',(30,570),cv2.FONT_HERSHEY_SIMPLEX,.55,(180,190,200),1)
        cv2.imshow('Hack4Edu - medir estabilidad',canvas)
        if local>=3: frames.append(dict(phase=phase,packet=packet))
        finished=(local>=8 or now-opened_at>=35) if args.single else elapsed>=24
        if finished or cv2.waitKey(1)&255 in [ord('q'),27]:stop.set()
    seguimiento.emit=receive
    try:
        seguimiento.run(argparse.Namespace(camera=args.camera,width=640,height=480,pinch=.35),stop)
    finally:
        cv2.destroyAllWindows()
    report={'label':args.label,'source':'webcam real','mirrored':True,'human_compliance':'no confirmada automáticamente','phases':[],'frames':frames}
    for phase in range(3):
        selected=[f['packet'] for f in frames if f['phase']==phase]
        stats={'phase':phases[phase], 'frame_count':len(selected),'detected_counts':{},'hands':{}}
        for packet in selected:
            count=sum(bool(h.get('present')) for h in packet.get('hands',[]))
            stats['detected_counts'][str(count)]=stats['detected_counts'].get(str(count),0)+1
        for id in range(2):
            hands=[h for p in selected for h in p.get('hands',[]) if h['id']==id and h.get('present')]
            points=[screen_point(h.get('raw_cursor',h['cursor'])) for h in hands]
            filtered=[screen_point(h['cursor']) for h in hands]
            stats['hands'][str(id)]={'raw':metrics(points),'filtered':metrics(filtered),'epochs':len(set(h.get('hand_epoch',0) for h in hands)), 'label_disagreements':sum(h.get('identity_label',h.get('handedness'))!=h.get('handedness') for h in hands)}
        orders=[]
        for packet in selected:
            pair={h['id']:h for h in packet.get('hands',[]) if h.get('present')}
            if len(pair)==2:
                orders.append(pair[0].get('raw_cursor',pair[0]['cursor'])[0]<pair[1].get('raw_cursor',pair[1]['cursor'])[0])
        stats['screen_order_changes']=sum(a!=b for a,b in zip(orders,orders[1:]))
        report['phases'].append(stats)
    report['identity_swaps']='Sin referencia humana externa no se certifican intercambios físicos; revisar IDs en ventana.'
    output=ROOT/'registros'/('estabilidad_'+args.label+'.json')
    output.parent.mkdir(exist_ok=True)
    output.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='frames'},ensure_ascii=False,indent=2),flush=True)
if __name__=='__main__':main()
