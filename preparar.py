"""Prepara el modelo y una copia portable oficial de Godot para Windows."""
import hashlib
import io
from pathlib import Path
import urllib.request
import zipfile

from prueba_camara import ensure_model

ROOT = Path(__file__).resolve().parent
URL = "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip"
EXPECTED = "83decd58fdf67b9d657958a1ae6bf1929c20785315a81effe245874cdc57acb709bf868e00778a96984338c1b29dafdb453c6847747694621c6ecf5da2259993"


def main():
    ensure_model()
    destination = ROOT / "runtime" / "Godot.exe"
    if destination.exists():
        print("Godot portable ya esta preparado.")
        return
    print("Descargando Godot 4.7.2 oficial para Windows (solo la primera vez)...", flush=True)
    chunks = []
    total = 0
    with urllib.request.urlopen(URL, timeout=60) as response:
        while chunk := response.read(1024 * 1024):
            chunks.append(chunk)
            total += len(chunk)
            if len(chunks) % 10 == 0:
                print(f"  {total // (1024 * 1024)} MB descargados...", flush=True)
    data = b"".join(chunks)
    if hashlib.sha512(data).hexdigest() != EXPECTED:
        raise RuntimeError("La descarga de Godot no coincide con la suma oficial esperada.")
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        executables = [name for name in archive.namelist() if name.lower().endswith(".exe") and "console" not in name.lower()]
        if len(executables) != 1:
            raise RuntimeError("El ZIP de Godot no contiene el ejecutable esperado.")
        destination.parent.mkdir(exist_ok=True)
        temporary = destination.with_suffix(".part")
        temporary.write_bytes(archive.read(executables[0]))
        temporary.replace(destination)
    print("Godot y modelo preparados. Abre 2_PROBAR_LAB3D.bat.")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("ERROR al preparar:", exc)
        raise SystemExit(1)
