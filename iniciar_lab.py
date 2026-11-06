"""Supervisa la webcam en un proceso reiniciable y conecta Godot por archivo local."""
from __future__ import annotations
import argparse
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import json
ROOT = Path(__file__).resolve().parent

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for flag, default in [("camera", 0), ("width", 640), ("height", 480)]:
        parser.add_argument("--" + flag, type=int, default=default)
    parser.add_argument("--pinch", type=float, default=.35)
    parser.add_argument("--godot")
    parser.add_argument("--test-stream", action="store_true")
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--test-exit", type=float, default=0)
    parser.add_argument("--bench", action="store_true")
    parser.add_argument("--audit-hands", action="store_true", help="Prueba guiada de dos manos reales, sin activar objetos")
    parser.add_argument("--grip-check", action="store_true", help="Veinte intentos guiados de agarre con webcam y traza F3")
    parser.add_argument("--assistant-check",action="store_true",help="Abre Química y el asistente para comprobar la interfaz")
    args = parser.parse_args()
    logs = ROOT / "registros"
    logs.mkdir(exist_ok=True)
    worker = None
    game = None
    def stop_worker():
        nonlocal worker
        if worker is not None:
            worker_stop.touch()
            try:
                worker.wait(timeout=1)
            except subprocess.TimeoutExpired:
                worker.kill()
                worker.wait()
            worker = None
    with tempfile.TemporaryDirectory(prefix="hack4edu_") as folder, (logs / "inicio_directo.log").open("w", encoding="utf-8") as log, (logs / "godot_directo.log").open("w", encoding="utf-8") as game_log:
        directory = Path(folder)
        state = directory / "estado.json"
        stop = directory / "salir.flag"
        pause = directory / "pausa.flag"
        retry = Path(str(state) + ".retry")
        worker_stop = directory / "worker.stop"
        command = [args.godot or str(ROOT / "runtime/Godot.exe"), "--path", str(ROOT / "godot"), "--rendering-method", "gl_compatibility"]
        if args.headless:
            command.append("--headless")
        command += ["--", "--state-file", str(state), "--stop-file", str(stop), "--pause-file", str(pause)]
        if args.bench:
            command.append("--bench")
        if args.audit_hands:
            command.append("--audit-hands")
        if args.grip_check:
            command.append("--grip-check")
        if args.assistant_check:
            command.append("--assistant-check")
        if args.test_stream:
            command.append("--test-stream")
        if args.test_exit:
            command += ["--test-exit", str(args.test_exit)]
        worker_command = [sys.executable, "-u", str(ROOT / "seguimiento.py"), "--state-file", str(state), "--stop-file", str(worker_stop)]
        for key in ["camera", "width", "height", "pinch"]:
            worker_command += ["--" + key, str(getattr(args, key))]
        if args.test_stream:
            worker_command.append("--test-stream")
        try:
            game = subprocess.Popen(command, cwd=ROOT, stdout=game_log, stderr=subprocess.STDOUT)
            failed = False
            last_status = ""
            while game.poll() is None and not stop.exists():
                if retry.exists():
                    stop_worker()
                    retry.unlink(missing_ok=True)
                    failed = False
                if pause.exists():
                    stop_worker()
                    failed = False
                elif worker is None and not failed:
                    worker_stop.unlink(missing_ok=True)
                    state.write_text(json.dumps({"type": "status", "message": "Iniciando Python..."}), encoding="utf-8")
                    worker = subprocess.Popen(worker_command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
                elif worker is not None and worker.poll() is not None:
                    failed = True
                    worker = None
                try:
                    packet = json.loads(state.read_text(encoding="utf-8"))
                    status = packet.get("message", "Enviando fotogramas a Godot" if packet.get("type") == "frame" else "Cámara abierta")
                    if status != last_status:
                        print(status, flush=True)
                        log.write(time.strftime("%H:%M:%S ") + status + "\n")
                        log.flush()
                        last_status = status
                except (OSError, ValueError):
                    pass
                time.sleep(.05)
        finally:
            stop_worker()
            if game is not None and game.poll() is None:
                game.terminate()
                game.wait(timeout=5)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
