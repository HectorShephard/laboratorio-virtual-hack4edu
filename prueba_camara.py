"""Prueba local de seguimiento de UNA mano y agarre 2D para Hack4Edu.

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
    """Distancia pulgar-indice dividida por ancho de palma, en pixeles."""
    def distance(a, b):
        return math.hypot((points[a].x - points[b].x) * width,
                          (points[a].y - points[b].y) * height)
    return distance(4, 8) / max(distance(5, 17), 1.0)


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
    cv2, mp, np = load_dependencies()
    model = ensure_model()
    from mediapipe.tasks import python
    from mediapipe.tasks.python import vision
    options = vision.HandLandmarkerOptions(
        base_options=python.BaseOptions(model_asset_buffer=model.read_bytes()),
        running_mode=vision.RunningMode.VIDEO, num_hands=1,
        min_hand_detection_confidence=0.5, min_hand_presence_confidence=0.5,
        min_tracking_confidence=0.5)
    if args.check:
        with vision.HandLandmarker.create_from_options(options) as detector:
            result = detector.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB,
                                                       data=np.zeros((480, 640, 3), dtype=np.uint8)), 0)
            assert not result.hand_landmarks
        print("OK: dependencias y modelo funcionan. Falta probar tu camara.")
        return
    capture, first = open_camera(cv2, args.camera, args.width, args.height)
    height, width = first.shape[:2]
    center, radius = (width * .68, height * .62), max(24, min(width, height) // 12)
    interaction = Interaction(args.pinch)
    config = {"python": platform.python_version(), "sistema": platform.platform(),
              "mediapipe": mp.__version__, "opencv": cv2.__version__,
              "camara_indice": args.camera, "ancho_real": width, "alto_real": height,
              "umbral_pinza": args.pinch, "manos": 1, "modelo_sha256": sha256(model)}
    rows, measure_start, before = [], None, (0, 0, 0)
    notice = "ESPACIO: medir 60 s | Q: salir | R: centrar ficha"
    frames, display_fps, fps_start = 0, 0, time.perf_counter()
    start = time.perf_counter()
    timestamp = -1
    pending = first
    window = "Hack4Edu - prueba local de manos"
    cv2.namedWindow(window, cv2.WINDOW_NORMAL)
    cv2.resizeWindow(window, max(800, width), max(600, height))
    print("Muestra UNA mano. Haz pinza sobre la ficha, muevela y abre los dedos para soltar.")
    print("ESPACIO: medir 60 segundos. Q/ESC: salir y guardar una medicion parcial.")
    try:
        with vision.HandLandmarker.create_from_options(options) as detector:
            while True:
                if pending is None:
                    ok, frame = capture.read()
                    if not ok:
                        raise RuntimeError("Se interrumpio la captura de camara.")
                else:
                    frame, pending = pending, None
                frame = cv2.flip(frame, 1)
                rgb = np.ascontiguousarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
                timestamp = max(timestamp + 1, int((time.perf_counter() - start) * 1000))
                infer_start = time.perf_counter()
                result = detector.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb), timestamp)
                inference_ms = (time.perf_counter() - infer_start) * 1000
                ratio, raw_cursor = None, None
                if result.hand_landmarks:
                    points = result.hand_landmarks[0]
                    coords = [(int(p.x * width), int(p.y * height)) for p in points]
                    for a, b in CONNECTIONS:
                        cv2.line(frame, coords[a], coords[b], (80, 220, 80), 2, cv2.LINE_AA)
                    for p in coords:
                        cv2.circle(frame, p, 4, (80, 240, 255), -1)
                    ratio = pinch_ratio(points, width, height)
                    raw_cursor = ((coords[4][0] + coords[8][0]) / 2,
                                  (coords[4][1] + coords[8][1]) / 2)
                center = interaction.update(raw_cursor, ratio, center, radius, width, height)
                now = time.perf_counter()
                frames += 1
                if now - fps_start >= .5:
                    display_fps = frames / (now - fps_start)
                    frames, fps_start = 0, now
                if measure_start is not None:
                    elapsed = now - measure_start
                    rows.append({"segundo": round(elapsed, 4), "mano_detectada": int(raw_cursor is not None),
                                 "inferencia_ms": round(inference_ms, 3),
                                 "razon_pinza": round(ratio, 4) if ratio is not None else "",
                                 "pinza_cerrada": int(interaction.closed), "objeto_agarrado": int(interaction.held)})
                    if elapsed >= 60:
                        save_report(rows, elapsed, config, before, interaction, True)
                        measure_start, rows = None, []
                        notice = "Informe guardado en resultados. ESPACIO: repetir"
                cx, cy = map(int, center)
                color = (80, 220, 80) if interaction.held else (245, 170, 40)
                cv2.circle(frame, (cx, cy), radius, color, -1, cv2.LINE_AA)
                cv2.putText(frame, "FICHA", (cx - 25, cy + 5), cv2.FONT_HERSHEY_SIMPLEX, .45, (20, 20, 20), 1)
                if interaction.cursor is not None:
                    cursor = tuple(map(int, interaction.cursor))
                    cv2.circle(frame, cursor, 10, (255, 255, 255), 2, cv2.LINE_AA)
                cv2.rectangle(frame, (0, 0), (width, 92), (25, 25, 25), -1)
                state = "SIN MANO" if raw_cursor is None else ("PINZA" if interaction.closed else "SIN PINZA")
                cv2.putText(frame, f"{state} | FPS: {display_fps:.1f} | IA: {inference_ms:.1f} ms", (10, 22),
                            cv2.FONT_HERSHEY_SIMPLEX, .52, (255, 255, 255), 1, cv2.LINE_AA)
                elapsed_label = f"Midiendo: {int(now - measure_start)}/60 s" if measure_start is not None else notice
                cv2.putText(frame, elapsed_label, (10, 47), cv2.FONT_HERSHEY_SIMPLEX, .43, (180, 235, 255), 1, cv2.LINE_AA)
                cv2.putText(frame, f"Pinzas: {interaction.pinches} | Agarres: {interaction.grabs} | Sueltas: {interaction.releases}",
                            (10, 71), cv2.FONT_HERSHEY_SIMPLEX, .48, (255, 255, 255), 1, cv2.LINE_AA)
                cv2.imshow(window, frame)
                key = cv2.waitKey(1) & 0xFF
                if key in (ord("q"), ord("Q"), 27):
                    break
                if cv2.getWindowProperty(window, cv2.WND_PROP_VISIBLE) < 1:
                    break
                if key == ord(" "):
                    if measure_start is not None:
                        save_report(rows, now - measure_start, config, before, interaction, False)
                    rows, measure_start = [], time.perf_counter()
                    before = (interaction.pinches, interaction.grabs, interaction.releases)
                if key in (ord("r"), ord("R")):
                    center = (width * .68, height * .62)
                    interaction.held = False
    finally:
        capture.release()
        cv2.destroyAllWindows()
        if measure_start is not None and rows:
            save_report(rows, time.perf_counter() - measure_start, config, before, interaction, False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--camera", type=int, default=0, help="Indice de camara, normalmente 0")
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--height", type=int, default=480)
    parser.add_argument("--pinch", type=float, default=.35, help="Umbral de pinza relativo al ancho de palma")
    parser.add_argument("--check", action="store_true", help="Verifica dependencias y modelo sin abrir la camara")
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
