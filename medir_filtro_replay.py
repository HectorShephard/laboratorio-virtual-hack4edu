"""Compara filtros sobre las MISMAS muestras numéricas previas; no afirma quietud humana."""
import importlib.util
import json
import math
import statistics
from pathlib import Path
from hand_filters import OneEuro

ROOT=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('old_filter',ROOT/'registros/agarre_antes/hand_filters.py')
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
baseline=json.loads((ROOT/'registros/estabilidad_antes.json').read_text(encoding='utf-8'))

def metric(points):
    steps=sorted(math.dist(a,b) for a,b in zip(points,points[1:]))
    return round(steps[round(.95*(len(steps)-1))],3) if steps else None

def screen(point):return [max(0,min(1,(p-.1)/.8))*size for p,size in zip(point,(1100,720))]

rows=[]
for phase in (0,1):
    for id in (0,1):
        before=module.OneEuro()
        after=OneEuro(minimum=1,beta=3)
        static=OneEuro(minimum=1,beta=0)
        raw_points=[]
        old_points=[]
        new_points=[]
        zero_points=[]
        for item in baseline['frames']:
            if item['phase']!=phase:continue
            packet=item['packet']
            hand=packet['hands'][id]
            if not hand['present']:continue
            time=packet['captured_unix']
            point=hand['raw_cursor']
            raw_points.append(screen(point))
            old_points.append(screen(before.update(point,time)))
            new_points.append(screen(after.update(point,time)))
            zero_points.append(screen(static.update(point,time)))
        rows.append(dict(phase=phase,id=id,samples=len(raw_points),raw_step_p95_px=metric(raw_points),
                         previous_step_p95_px=metric(old_points),min1_beta0_step_p95_px=metric(zero_points),
                         min1_beta3_step_p95_px=metric(new_points)))
responses=[]
for beta in (0,3):
    filter=OneEuro(minimum=1,beta=beta)
    for i in range(150):filter.update([.3,.5],i/30)
    elapsed=None
    for i in range(60):
        point=filter.update([.7,.5],5+i/30)
        if elapsed is None and abs(point[0]-.7)<.04:elapsed=round(i/30*1000)
    responses.append(dict(beta=beta,synthetic_step_90pct_ms=elapsed))
report=dict(source='Replay de muestras de webcam previas; movimiento humano no confirmado como quieto',
            rows=rows,response=responses,selected=dict(min_cutoff=1,beta=3),
            note='El replay aísla el filtro. No incluye el render interpolado ni equivale a una medición física de latencia.')
(ROOT/'docs/AGARRE_FILTRO_METRICAS.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps(report,indent=2,ensure_ascii=False))
