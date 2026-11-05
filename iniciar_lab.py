"""Abre la camara desde Python y conecta Godot mediante un archivo temporal local."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import traceback

import seguimiento

ROOT = Path(__file__).resolve().parent


class StateFile:
    def __init__(self, destination, log_path):
        self.destination = Path(destination)
        self.log_path = Path(log_path)
        self.counter = 0
        self.synthetic = False
        self.first_frame = True

    def log(self, message):
        print(message, flush=True)
        with self.log_path.open("a", encoding="utf-8") as output:
            output.write(time.strftime("%H:%M:%S ") + message + "\n")

    def publish(self, packet):
        self.counter += 1
        kind = packet.get("type")
        if kind == "ready":
            self.synthetic = bool(packet.get("synthetic", False))
            self.log("Camara abierta. Preparando seguimiento de manos...")
        elif kind in ("status", "error"):
            self.log(str(packet.get("message", "")))
        elif kind == "frame" and self.first_frame:
            self.first_frame = False
            self.log("Seguimiento activo: se estan enviando posiciones a Godot.")
        data = dict(packet, message_id=self.counter, synthetic=self.synthetic)
        temporary = self.destination.with_suffix(".tmp")
        temporary.write_text(json.dumps(data, separators=(",", ":"), allow_nan=False), encoding="utf-8")
        # Windows puede mantener un archivo abierto durante su breve lectura.
        for attempt in range(8):
            try:
                os.replace(temporary, self.destination)
                return
            except PermissionError:
                time.sleep(.002)
        if kind != "frame":
            raise RuntimeError("No se pudo actualizar el archivo temporal de seguimiento.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--camera", type=int, default=0)
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--height", type=int, default=480)
    parser.add_argument("--pinch", type=float, default=.35)
    parser.add_argument("--godot", help="Ruta a otra copia de Godot para pruebas tecnicas")
    parser.add_argument("--test-stream", action="store_true", help="Datos SIMULADOS; no prueba la camara")
    parser.add_argument("--headless", action="store_true", help="Comprobacion tecnica sin ventana")
    parser.add_argument("--test-exit", type=float, default=0)
    parser.add_argument("--bench", action="store_true", help="Ir directamente a la mesa de pruebas")
    args = parser.parse_args()
    if args.width < 320 or args.height < 240 or not .05 <= args.pinch <= 1:
        parser.error("Resolucion minima 320x240 y umbral de pinza entre 0.05 y 1.")
    executable = Path(args.godot) if args.godot else ROOT / "runtime" / "Godot.exe"
    if not executable.is_file():
        print("Falta Godot. Ejecuta primero 1_PREPARAR.bat.", flush=True)
        return 1
    logs = ROOT / "registros"
    logs.mkdir(exist_ok=True)
    log_path = logs / "inicio_directo.log"
    log_path.write_text("Inicio directo del laboratorio con Python " + sys.version.split()[0] + "\n", encoding="utf-8")
    process = None
    quit_event = threading.Event()
    paused = threading.Event()
    session = {"stop": None}
    old_emit = seguimiento.emit
    result = 0
    with tempfile.TemporaryDirectory(prefix="hack4edu_") as directory:
        directory = Path(directory)
        state_file = directory / "estado.json"
        stop_file = directory / "salir.flag"
        pause_file = directory / "pausa.flag"
        transport = StateFile(state_file, log_path)
        seguimiento.emit = transport.publish
        transport.publish({"type": "status", "message": "Iniciando camara desde Python..."})
        command = [str(executable), "--path", str(ROOT / "godot"), "--rendering-method", "gl_compatibility"]
        if args.headless:
            command.append("--headless")
        command += ["--", "--state-file", str(state_file), "--stop-file", str(stop_file), "--pause-file", str(pause_file)]
        if args.test_stream:
            command.append("--test-stream")
        if args.bench:
            command.append("--bench")
        if args.test_exit > 0:
            command += ["--test-exit", str(args.test_exit)]

        def watch():
            while not quit_event.wait(.05):
                if process.poll() is not None or stop_file.exists():
                    quit_event.set()
                if pause_file.exists():
                    paused.set()
                else:
                    paused.clear()
                current = session["stop"]
                if current is not None and (quit_event.is_set() or paused.is_set()):
                    current.set()

        try:
            with (logs / "godot_directo.log").open("w", encoding="utf-8") as godot_log:
                process = subprocess.Popen(command, cwd=ROOT, stdin=subprocess.DEVNULL,
                                           stdout=godot_log, stderr=subprocess.STDOUT)
                watcher = threading.Thread(target=watch, daemon=True)
                watcher.start()
                failed = False
                while not quit_event.is_set():
                    if paused.is_set():
                        failed = False
                        quit_event.wait(.1)
                        continue
                    if failed:
                        quit_event.wait(.1)
                        continue
                    capture_stop = threading.Event()
                    session["stop"] = capture_stop
                    try:
                        if args.test_stream:
                            seguimiento.fake_stream(capture_stop)
                        else:
                            # Se llama a run, no a main: no se usa stdin ni un proceso hijo oculto.
                            seguimiento.run(args, capture_stop)
                    except Exception as exc:
                        if not paused.is_set() and not quit_event.is_set():
                            transport.publish({"type": "error", "message": str(exc) or "No se pudo abrir la camara."})
                            transport.log("Usa Comparar con raton y vuelve a la camara para reintentar.")
                            with log_path.open("a", encoding="utf-8") as output:
                                traceback.print_exc(file=output)
                            failed = True
                    finally:
                        capture_stop.set()
                        session["stop"] = None
                watcher.join(timeout=1)
        except KeyboardInterrupt:
            result = 0
        except Exception as exc:
            transport.log("ERROR al iniciar: " + str(exc))
            result = 1
        finally:
            quit_event.set()
            current = session["stop"]
            if current is not None:
                current.set()
            seguimiento.emit = old_emit
            if process is not None and process.poll() is None:
                try:
                    process.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    process.terminate()
                    try:
                        process.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
    print("Laboratorio cerrado.", flush=True)
    return result


if __name__ == "__main__":
    raise SystemExit(main())
