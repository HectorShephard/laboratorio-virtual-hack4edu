"""Puente local de MediaPipe a Godot por stdin/stdout; no abre conexiones de red."""
from __future__ import annotations

import argparse
from collections import deque
import json
import sys
import threading
import time

import prueba_camara as common


def emit(packet):
    print(json.dumps(packet, separators=(",", ":"), allow_nan=False), flush=True)


def parent_monitor(stop):
    """El fin del pipe o el mensaje stop cierra el proceso hijo."""
    try:
        for line in sys.stdin:
            if line.strip() == "stop":
                break
    finally:
        stop.set()


def fake_stream(stop):
    """Entrada de control para validar la comunicacion; nunca se presenta como camara."""
    emit({"type": "ready", "synthetic": True, "width": 640, "height": 480})
    seq = 0
    while not stop.wait(1 / 30):
        phase = (seq % 180) / 180
        # Ciclo de acercamiento, pinza, desplazamiento y suelta.
        closed = 0.15 < phase < 0.70
        progress = max(0, min(1, (phase - 0.22) / 0.40))
        cursor = [0.487 + 0.28 * progress, 0.50 - 0.05 * progress]
        emit({"type": "frame", "seq": seq, "captured_unix": time.time(),
              "present": True, "cursor": cursor, "pinched": closed,
              "ratio": .2 if closed else .8, "landmarks": [], "inference_ms": 0,
              "pipeline_ms": 0, "tracking_hz": 30, "camera_hz": 30})
        seq += 1


def run(args, stop):
    emit({"type": "status", "message": "Cargando MediaPipe..."})
    cv2, mp, np = common.load_dependencies()
    from mediapipe.tasks import python
    from mediapipe.tasks.python import vision
    model = common.ensure_model()
    # El motor 3D recibe los puntos; Python no dibuja otra ventana de video.
    cv2.setNumThreads(1)
    options = vision.HandLandmarkerOptions(
        base_options=python.BaseOptions(model_asset_buffer=model.read_bytes()),
        running_mode=vision.RunningMode.VIDEO, num_hands=1,
        min_hand_detection_confidence=.5, min_hand_presence_confidence=.5,
        min_tracking_confidence=.5)
    emit({"type": "status", "message": "Abriendo camara..."})
    if stop.is_set():
        raise RuntimeError("Se cerro la comunicacion con Godot antes de abrir la camara.")
    capture, first = common.open_camera(cv2, args.camera, args.width, args.height)
    height, width = first.shape[:2]
    camera_times = deque(maxlen=60)
    emit({"type": "ready", "synthetic": False, "width": width, "height": height,
          "python": sys.version.split()[0], "mediapipe": mp.__version__})
    seq, last_ts = -1, -1
    closed = False
    candidate, stable_frames = False, 0
    completions = deque(maxlen=60)
    try:
        emit({"type": "status", "message": "Preparando detector de manos..."})
        with vision.HandLandmarker.create_from_options(options) as detector:
            while not stop.is_set():
                # Abrir y leer la camara en el mismo hilo: igual que la prueba 2D.
                ok, frame = capture.read()
                captured_perf, captured_unix = time.perf_counter(), time.time()
                if not ok:
                    raise RuntimeError("No se pudo leer la camara. Cierra otras apps de video y ejecuta 4_PROBAR_CAMARA_SOLA.bat.")
                seq += 1
                camera_times.append(captured_perf)
                camera_hz = (len(camera_times) - 1) / (camera_times[-1] - camera_times[0]) if len(camera_times) > 1 and camera_times[-1] > camera_times[0] else 0.0
                start = time.perf_counter()
                rgb = np.ascontiguousarray(cv2.cvtColor(cv2.flip(frame, 1), cv2.COLOR_BGR2RGB))
                timestamp = max(last_ts + 1, int(captured_perf * 1000))
                last_ts = timestamp
                infer_start = time.perf_counter()
                result = detector.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb), timestamp)
                end = time.perf_counter()
                completions.append(end)
                tracking_hz = (len(completions) - 1) / (completions[-1] - completions[0]) if len(completions) > 1 and completions[-1] > completions[0] else 0.0
                points, cursor, ratio = [], [0.5, 0.5], None
                present = bool(result.hand_landmarks)
                if present:
                    hand = result.hand_landmarks[0]
                    points = [[round(p.x, 5), round(p.y, 5), round(p.z, 5)] for p in hand]
                    cursor = [(hand[4].x + hand[8].x) / 2, (hand[4].y + hand[8].y) / 2]
                    ratio = common.pinch_ratio(hand, width, height)
                    target = ratio < (args.pinch + .20 if closed else args.pinch)
                    stable_frames = stable_frames + 1 if target == candidate else 1
                    candidate = target
                    if stable_frames >= 2:
                        closed = target
                else:
                    closed = candidate = False
                    stable_frames = 0
                emit({"type": "frame", "seq": seq, "captured_unix": captured_unix,
                      "present": present, "cursor": cursor, "pinched": closed,
                      "ratio": ratio, "landmarks": points,
                      "inference_ms": round((end - infer_start) * 1000, 3),
                      "pipeline_ms": round((end - start) * 1000, 3),
                      "tracking_hz": round(tracking_hz, 2), "camera_hz": round(camera_hz, 2)})
    finally:
        stop.set()
        capture.release()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--camera", type=int, default=0)
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--height", type=int, default=480)
    parser.add_argument("--pinch", type=float, default=.35)
    parser.add_argument("--test-stream", action="store_true", help="Datos SIMULADOS para comprobaciones tecnicas")
    args = parser.parse_args()
    stop = threading.Event()
    threading.Thread(target=parent_monitor, args=(stop,), daemon=True).start()
    try:
        if args.test_stream:
            fake_stream(stop)
        else:
            run(args, stop)
    except BrokenPipeError:
        return 0
    except (Exception, KeyboardInterrupt) as exc:
        try:
            emit({"type": "error", "message": str(exc) or "Seguimiento detenido."})
        except BrokenPipeError:
            pass
        print(str(exc), file=sys.stderr, flush=True)
        return 1
    finally:
        stop.set()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
