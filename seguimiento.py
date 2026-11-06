"""Puente local de MediaPipe a Godot por stdin/stdout; no abre conexiones de red."""
from __future__ import annotations

import argparse
from collections import deque
import json
import sys
import threading
import time
import os
from pathlib import Path
from uuid import uuid4

import prueba_camara as common
from hand_pipeline import HandPipeline
STREAM_ID = uuid4().hex


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
    from test_hand_pipeline import transport_frames
    samples = transport_frames()
    seq = 0
    while not stop.wait(1 / 30):
        sample = samples[seq % len(samples)]
        primary = sample['hands'][0]
        emit(dict(sample, seq=seq, captured_unix=time.time(), stream_id=STREAM_ID,
                  present=any(h['present'] for h in sample['hands']),
                  cursor=primary.get('cursor', [.5, .5]),
                  pinched=primary.get('pinched', False), landmarks=primary.get('landmarks', []),
                  inference_ms=0, pipeline_ms=0, tracking_hz=30, camera_hz=30))
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
        running_mode=vision.RunningMode.VIDEO, num_hands=2,
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
    completions = deque(maxlen=60)
    pipeline = HandPipeline(args.pinch)
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
                # Inferencia sin espejo; solo se espejan las coordenadas de presentación.
                rgb = np.ascontiguousarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
                timestamp = max(last_ts + 1, int(captured_perf * 1000))
                last_ts = timestamp
                infer_start = time.perf_counter()
                result = detector.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb), timestamp)
                end = time.perf_counter()
                completions.append(end)
                tracking_hz = (len(completions) - 1) / (completions[-1] - completions[0]) if len(completions) > 1 and completions[-1] > completions[0] else 0.0
                detections = []
                for index, (hand, handedness) in enumerate(zip(result.hand_landmarks, result.handedness)):
                    category = handedness[0]
                    detections.append(dict(points=hand, world=result.hand_world_landmarks[index] if index<len(result.hand_world_landmarks) else None,
                                           label=category.category_name, score=category.score,
                                           wrist=[1-hand[0].x,hand[0].y], center=[1-hand[0].x,hand[0].y]))
                if getattr(args,'state_file',None):
                    try:
                        control=json.loads(Path(args.state_file+'.owners').read_text(encoding='utf-8'))
                        pipeline.identities.locked_ids=set(control.get('held_ids',[]))
                    except (OSError,ValueError): pass
                hands = pipeline.process(detections, captured_perf, width, height)
                # Compatibilidad del banco antiguo: siempre ID 0, nunca el orden de detección.
                primary = hands[0]
                present = any(h['present'] for h in hands)
                points = primary.get('landmarks', [])
                cursor = primary.get('cursor', [.5, .5])
                closed = primary.get('pinched', False)
                hand_epoch = primary['hand_epoch']
                ratio = None
                emit({"type": "frame", "seq": seq, "stream_id": STREAM_ID, "captured_unix": captured_unix,
                      "hands": hands,
                      "raw_detections": [dict(wrist=d['wrist'],handedness=d['label'],score=d['score']) for d in detections],
                      "present": present, "cursor": cursor, "pinched": closed, "hand_epoch": hand_epoch,
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
    parser.add_argument("--state-file")
    parser.add_argument("--stop-file")
    args = parser.parse_args()
    stop = threading.Event()
    if args.state_file:
        destination = Path(args.state_file)
        counter = 0
        def publish(packet):
            nonlocal counter
            counter += 1
            data = dict(packet, message_id=counter, synthetic=args.test_stream)
            temporary = destination.with_suffix(".tmp")
            temporary.write_text(json.dumps(data, allow_nan=False), encoding="utf-8")
            for attempt in range(8):
                try:
                    os.replace(temporary, destination)
                    return
                except PermissionError:
                    time.sleep(.002)
        globals()["emit"] = publish
        def watch_file():
            while not stop.wait(.05):
                if args.stop_file and Path(args.stop_file).exists():
                    stop.set()
        threading.Thread(target=watch_file, daemon=True).start()
    else:
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
