"""Prueba local de seguimiento de DOS manos y agarre 2D para Hack4Edu.

No graba ni transmite imagenes. Solo guarda metricas numericas al medir.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import platform
import statistics
import sys
import time
import urllib.request

ROOT = Path(__file__).resolve().parent
MODEL_URL = "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task"
MODEL_PATH = ROOT / "modelos" / "hand_landmarker.task"
MODEL_SHA256 = "fbc2a30080c3c557093b5ddfc334698132eb341044ccee322ccf8bcf3607cde1"
CONNECTIONS = [(0,1),(1,2),(2,3),(3,4),(0,5),(5,6),(6,7),(7,8),
               (5,9),(9,10),(10,11),(11,12),(9,13),(13,14),(14,15),(15,16),
               (13,17),(0,17),(17,18),(18,19),(19,20)]


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ensure_model():
    if MODEL_PATH.exists():
        if sha256(MODEL_PATH) != MODEL_SHA256:
            raise RuntimeError("El modelo no coincide con la version esperada. Borra modelos/hand_landmarker.task y repite.")
        return MODEL_PATH
    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    partial = MODEL_PATH.with_suffix(".part")
    print("Descargando el modelo oficial de Google (solo la primera vez)...", flush=True)
    try:
        with urllib.request.urlopen(MODEL_URL, timeout=60) as response, partial.open("wb") as out:
            while chunk := response.read(1024 * 1024):
                out.write(chunk)
        if sha256(partial) != MODEL_SHA256:
            raise RuntimeError("La descarga no coincide con el modelo esperado.")
        partial.replace(MODEL_PATH)
    finally:
        partial.unlink(missing_ok=True)
    return MODEL_PATH


def load_dependencies():
    try:
        import cv2
        import mediapipe as mp
        import numpy as np
        return cv2, mp, np
    except ImportError as exc:
        raise RuntimeError("Faltan dependencias. Ejecuta 1_PREPARAR.bat antes de iniciar la prueba.") from exc


def pinch_ratio(points, width, height):
    """Compatibilidad 2D con las mismas referencias robustas de palma."""
    from hand_geometry import pinch_measure
    return pinch_measure(points,width,height)['ratio']


class Interaction:
    def __init__(self, close_threshold=0.35):
        self.close_threshold = close_threshold
        self.closed = False
        self.candidate = False
        self.stable_frames = 0
        self.cursor = None
        self.held = False
        self.offset = (0, 0)
        self.grabs = 0
        self.releases = 0
        self.pinches = 0

    def update(self, raw_cursor, ratio, center, radius, width, height):
        if raw_cursor is None:
            self.cursor = None
            self.closed = self.candidate = self.held = False
            self.stable_frames = 0
            return center
        if self.cursor is None:
            self.cursor = raw_cursor
        else:
            self.cursor = tuple(a * 0.4 + b * 0.6 for a, b in zip(raw_cursor, self.cursor))
        candidate = ratio < (self.close_threshold + 0.20 if self.closed else self.close_threshold)
        self.stable_frames = self.stable_frames + 1 if candidate == self.candidate else 1
        self.candidate = candidate
        previous = self.closed
        if self.stable_frames >= 2:
            self.closed = candidate
        if self.closed and not previous:
            self.pinches += 1
            if math.dist(self.cursor, center) <= radius + 15:
                self.held = True
                self.grabs += 1
                self.offset = tuple(a - b for a, b in zip(center, self.cursor))
        if previous and not self.closed and self.held:
            self.held = False
            self.releases += 1
        if self.held:
            center = (min(width - radius, max(radius, self.cursor[0] + self.offset[0])),
                      min(height - radius, max(95 + radius, self.cursor[1] + self.offset[1])))
        return center


def percentile(values, p):
    ordered = sorted(values)
    return ordered[round((len(ordered) - 1) * p)] if ordered else None


def save_report(rows, duration, config, before, interaction, completed):
    if not rows:
        return None
    folder = ROOT / "resultados"
    folder.mkdir(exist_ok=True)
    stem = "prueba_" + time.strftime("%Y%m%d_%H%M%S") + f"_{time.time_ns() % 1000000:06d}"
    report = {
        "fecha_local": time.strftime("%Y-%m-%d %H:%M:%S"),
        "duracion_s": round(duration, 2), "completo": completed,
        "configuracion": config,
        "fotogramas_procesados": len(rows),
        "fps_bucle_promedio": round(len(rows) / max(duration, .001), 2),
        "fotogramas_con_mano_pct": round(100 * sum(r["mano_detectada"] for r in rows) / len(rows), 2),
        "inferencia_ms_mediana": round(statistics.median(r["inferencia_ms"] for r in rows), 2),
        "inferencia_ms_p95": round(percentile([r["inferencia_ms"] for r in rows], .95), 2),
        "pinzas_detectadas": interaction.pinches - before[0],
        "agarres_del_objeto": interaction.grabs - before[1],
        "sueltas_del_objeto": interaction.releases - before[2],
        "notas": ["La presencia de mano no mide precision; depende de que la mano permanezca visible.",
                  "El tiempo de inferencia no es la latencia de camara a pantalla.",
                  "Los FPS corresponden a esta prueba 2D, sin Godot ni simulacion cientifica.",
                  "No se guardan fotos ni video. Se guardan tiempos, estado de deteccion y razon de pinza."]
    }
    (folder / (stem + ".json")).write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    with (folder / (stem + ".csv")).open("w", newline="", encoding="utf-8") as out:
        writer = csv.DictWriter(out, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print("Informe guardado:", folder / (stem + ".json"), flush=True)
    return stem


def open_camera(cv2, index, width, height):
    backends = [cv2.CAP_DSHOW, cv2.CAP_MSMF] if platform.system() == "Windows" else [cv2.CAP_ANY]
    for backend in backends:
        capture = cv2.VideoCapture(index, backend)
        if capture.isOpened():
            capture.set(cv2.CAP_PROP_FRAME_WIDTH, width)
            capture.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
            capture.set(cv2.CAP_PROP_FPS, 30)
            ok, frame = capture.read()
            if ok:
                return capture, frame
        capture.release()
    raise RuntimeError("No se pudo leer la camara. Cierra Camara, Teams, Zoom y OBS; revisa permisos. Si tienes otra camara, prueba --camera 1.")


def run(args):
    from hand_pipeline import HandPipeline
    cv2, mp, np = load_dependencies()
    from mediapipe.tasks import python
    from mediapipe.tasks.python import vision
    model = ensure_model()
    options = vision.HandLandmarkerOptions(
        base_options=python.BaseOptions(model_asset_buffer=model.read_bytes()),
        running_mode=vision.RunningMode.VIDEO, num_hands=2,
        min_hand_detection_confidence=.5, min_hand_presence_confidence=.5,
        min_tracking_confidence=.5)
    if args.check:
        with vision.HandLandmarker.create_from_options(options) as detector:
            result=detector.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB,
                data=np.zeros((480,640,3),dtype=np.uint8)),0)
            assert not result.hand_landmarks
        print("OK: dependencias, modelo y detector de DOS manos. Falta probar la camara.")
        return
    capture,first=open_camera(cv2,args.camera,args.width,args.height)
    height,width=first.shape[:2]
    pipeline=HandPipeline(args.pinch)
    owners=[False,False]
    pressed=[False,False]
    armed=[False,False]
    seen=[None,None]
    needs_open=[False,False]
    offsets=[(0,0),(0,0)]
    centers=[(width*.3,height*.65),(width*.7,height*.65)]
    radius=max(24,min(width,height)//12)
    rows=[]
    start=time.perf_counter()
    measure_start=None
    timestamp=-1
    pending=first
    window="Hack4Edu - DOS manos / mismo detector del laboratorio"
    cv2.namedWindow(window,cv2.WINDOW_NORMAL)
    print("DOS manos: palma para apuntar, flexiona dedos para agarrar y abre para soltar. ESPACIO: traza; Q: salir.",flush=True)
    try:
        with vision.HandLandmarker.create_from_options(options) as detector:
            while True:
                if pending is None:
                    ok,frame=capture.read()
                    if not ok: raise RuntimeError("Se interrumpio la captura de camara.")
                else: frame,pending=pending,None
                now=time.perf_counter()
                timestamp=max(timestamp+1,int(now*1000))
                rgb=np.ascontiguousarray(cv2.cvtColor(frame,cv2.COLOR_BGR2RGB))
                result=detector.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB,data=rgb),timestamp)
                detections=[]
                for i,(points,categories) in enumerate(zip(result.hand_landmarks,result.handedness)):
                    category=categories[0]
                    detections.append(dict(points=points,world=result.hand_world_landmarks[i],
                        label=category.category_name,score=category.score,wrist=[1-points[0].x,points[0].y]))
                hands=pipeline.process(detections,now,width,height)
                frame=cv2.flip(frame,1)
                for hand in hands:
                    id=hand['id']
                    color=(80,190,245) if id==0 else (240,200,80)
                    if not hand['present'] or not hand.get('gesture_valid',True):
                        if seen[id] is not None and now-seen[id]>.55:
                            owners[id]=False
                            needs_open[id]=True
                    else:
                        seen[id]=now
                        cursor=tuple(max(0,min(1,(p-.1)/.8))*size for p,size in zip(hand['cursor'],(width,height)))
                        if hand['hand_open']: needs_open[id]=False
                        if hand['flexed'] and not needs_open[id] and not owners[id]:
                            if math.dist(cursor,centers[id])<radius+22:
                                owners[id]=True
                                offsets[id]=tuple(c-p for c,p in zip(centers[id],cursor))
                        if hand['hand_open']: owners[id]=False
                        if owners[id]: centers[id]=tuple(p+d for p,d in zip(cursor,offsets[id]))
                        pressed[id]=hand['pinched']
                        for a,b in CONNECTIONS:
                            p,q=hand['landmarks'][a],hand['landmarks'][b]
                            cv2.line(frame,(int(p[0]*width),int(p[1]*height)),(int(q[0]*width),int(q[1]*height)),color,2)
                        cv2.circle(frame,tuple(map(int,cursor)),12,color,2)
                        text=f"ID {id} {hand['flex_state']} votos {hand['flexion']['bent_votes']}/{hand['flexion']['open_votes']}"
                        cv2.putText(frame,text,(8,25+id*25),cv2.FONT_HERSHEY_SIMPLEX,.45,color,1)
                    cv2.circle(frame,tuple(map(int,centers[id])),radius,color,3 if owners[id] else 1)
                    if measure_start is not None:
                        rows.append(dict(seconds=now-measure_start,hand=hand))
                cv2.imshow(window,frame)
                if args.test_exit>0 and now-start>=args.test_exit:break
                key=cv2.waitKey(1)&255
                if key in (ord('q'),27) or cv2.getWindowProperty(window,cv2.WND_PROP_VISIBLE)<1:break
                if key==ord(' '):measure_start=now
    finally:
        capture.release()
        cv2.destroyAllWindows()
        output=ROOT/'registros'/'camara_sola_control.json'
        output.parent.mkdir(exist_ok=True)
        output.write_text(json.dumps(dict(num_hands=2,frames=rows),ensure_ascii=False),encoding='utf-8')
        print("OK: camara real, dos IDs y razones por representacion. Traza numerica:",output,flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--camera", type=int, default=0, help="Indice de camara, normalmente 0")
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--height", type=int, default=480)
    parser.add_argument("--pinch", type=float, default=.35, help="Sensibilidad relativa: .35 es base; pinza suave 2D .55/.80 y 3D .50/.75")
    parser.add_argument("--check", action="store_true", help="Verifica dependencias y modelo sin abrir la camara")
    parser.add_argument("--test-exit", type=float, default=0, help="Cerrar la prueba tras N segundos de captura")
    parser.add_argument("--download-model", action="store_true", help="Descarga solo el modelo")
    args = parser.parse_args()
    if args.width < 320 or args.height < 240 or not 0.05 <= args.pinch <= 1.0:
        parser.error("Usa ancho >= 320, alto >= 240 y --pinch entre 0.05 y 1.0")
    try:
        if args.download_model:
            print("Modelo preparado:", ensure_model())
        else:
            run(args)
    except (RuntimeError, OSError, ValueError) as exc:
        print("\nERROR:", exc, file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\nPrueba detenida.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
