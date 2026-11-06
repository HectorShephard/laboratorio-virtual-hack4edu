"""Resumen por fase de la última auditoría guiada detector -> Godot."""
import collections
import math
import json
import argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--log',default='registros/auditoria_manos_ventana.log')
parser.add_argument('--output',default='docs/LAB1_AUDITORIA_MANOS.json')
args=parser.parse_args()
log=(ROOT/args.log).read_text(encoding='utf-8-sig')
line=next(line for line in reversed(log.splitlines()) if 'REAL:' in line)
stem=Path(line.split('REAL:',1)[1].strip())
summary=json.loads(stem.with_suffix('.json').read_text(encoding='utf-8-sig'))
phases={}
previous={}
accepted_jumps=collections.Counter()
by_frame={}
for text in stem.with_suffix('.jsonl').read_text(encoding='utf-8-sig').splitlines():
    row=json.loads(text)
    if 'id' not in row:continue
    frame=by_frame.setdefault(row['seq'],dict(raw=len(row.get('raw_detections',[])),accepted=0))
    frame['accepted']+=int(row['accepted'])
    if row['phase'].startswith('preparar_'):continue
    id=str(row['id'])
    prior=previous.get(id,{})
    if row['seq']==prior.get('seq',-2)+1 and row['accepted'] and prior.get('accepted') and len(row['accepted_cursor'])==2 and len(prior.get('accepted_cursor',[]))==2:
        if math.dist(row['accepted_cursor'],prior['accepted_cursor'])>.14:
            accepted_jumps[id]+=1
    previous[id]=row
    phase=phases.setdefault(row['phase'],{})
    counts=phase.setdefault(id,dict(frames=0,raw=0,assigned=0,accepted=0,events=collections.Counter(),detector_labels=collections.Counter(),identity_labels=collections.Counter()))
    counts['frames']+=1
    counts['raw']+=int(row['raw_present'])
    counts['assigned']+=int(row['assigned'])
    counts['accepted']+=int(row['accepted'])
    counts['events'].update(row['events'])
    if row['raw_present']:
        counts['detector_labels'].update([row['detector_label']])
        counts['identity_labels'].update([row['identity_label']])
for phase in phases.values():
    for stats in phase.values():stats['accepted_over_assigned_pct']=round(100*stats['accepted']/stats['assigned'],2) if stats['assigned'] else None
simultaneous=dict(raw_two_frames=sum(f['raw']==2 for f in by_frame.values()),accepted_two_frames=sum(f['accepted']==2 for f in by_frame.values()))
report=dict(source='webcam real y aceptación real de Godot',raw_file=str(stem.relative_to(ROOT))+'.jsonl',summary=summary,simultaneous=simultaneous,accepted_jumps_recomputed={id:accepted_jumps[id] for id in ['0','1']},phases=phases,physical_hand_confirmed=None,limitations='Las fases son instrucciones visuales. Los cambios de etiqueta o de época no prueban un intercambio de identidad física. El vertido humano completo sigue pendiente.',same_rules_for_both=True)
(ROOT/args.output).write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps(report,indent=2,ensure_ascii=False))
