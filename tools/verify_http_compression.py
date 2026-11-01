#!/usr/bin/env python3
"""Verify actual Nginx Brotli/gzip/identity responses, decoded bytes and cache headers."""
import argparse
import gzip
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--nginx", default="nginx")
    args = parser.parse_args()
    source = args.directory.resolve()
    policy = Path(__file__).resolve().parents[1] / "deploy/nginx-performance.conf"
    with tempfile.TemporaryDirectory(prefix="dunhuang-http-verify-") as name:
        root = Path(name)
        (root / "logs").mkdir()
        www = root / "www"
        www.mkdir()
        for path in source.iterdir():
            if path.is_file():
                shutil.copyfile(path, www / path.name)
        # Older releases without a Brotli companion must continue to work.
        legacy = www / "game-deadbeef.pck"
        legacy.write_bytes(b"older game pack" * 100)
        legacy.with_suffix(".pck.gz").write_bytes(gzip.compress(legacy.read_bytes()))
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        config = root / "nginx.conf"
        config.write_text(f'''pid {root}/nginx.pid;
error_log {root}/error.log;
events {{ }}
http {{
    access_log off;
    gzip on;
    gzip_types application/wasm application/octet-stream application/javascript;
    server {{
        listen 127.0.0.1:{port};
        root {www};
        include {policy};
    }}
}}
''')
        command = [args.nginx, "-p", str(root), "-c", str(config), "-e", str(root / "error.log")]
        subprocess.run(command + ["-t"], check=True)
        server = subprocess.Popen(command + ["-g", "daemon off;"])
        try:
            for _ in range(100):
                try:
                    with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                        break
                except OSError:
                    time.sleep(0.05)
            else:
                raise RuntimeError("Nginx did not start")
            names = [next(www.glob("engine-*.wasm")).name, next(p for p in www.glob("game-*.pck") if p != legacy).name]
            for asset in names:
                expected = (www / asset).read_bytes()
                for accept, encoding in [("br, gzip", "br"), ("gzip", "gzip"), ("identity", None), ("br;q=0, gzip", "gzip"), ("br;q=0.5, gzip", "br")]:
                    request = urllib.request.Request(f"http://127.0.0.1:{port}/{asset}", headers={"Accept-Encoding": accept})
                    with urllib.request.urlopen(request) as response:
                        body = response.read()
                        assert response.headers.get("Content-Encoding") == encoding, (accept, dict(response.headers))
                        assert response.headers.get_content_type() == ("application/wasm" if asset.endswith(".wasm") else "application/octet-stream")
                        assert "immutable" in response.headers["Cache-Control"]
                        assert "accept-encoding" in ",".join(response.headers.get_all("Vary", [])).lower()
                        assert response.headers["Cross-Origin-Opener-Policy"] == "same-origin"
                        assert response.headers["Cross-Origin-Embedder-Policy"] == "require-corp"
                        if encoding == "br":
                            body = subprocess.run(["brotli", "-d", "-c"], input=body, capture_output=True, check=True).stdout
                        elif encoding == "gzip":
                            body = gzip.decompress(body)
                        assert body == expected, "Decoded payload changed"
                print(f"{asset}: Brotli, gzip, identity, q=0 fallback and exact decoded bytes passed", flush=True)
            request = urllib.request.Request(f"http://127.0.0.1:{port}/{legacy.name}", headers={"Accept-Encoding": "br, gzip"})
            with urllib.request.urlopen(request) as response:
                assert response.headers["Content-Encoding"] == "gzip"
                assert gzip.decompress(response.read()) == legacy.read_bytes()
            try:
                urllib.request.urlopen(f"http://127.0.0.1:{port}/{names[0]}.br")
                raise AssertionError("Internal compression URL was directly accessible")
            except urllib.error.HTTPError as error:
                assert error.code == 404
            print("Missing companion fallback and internal-only compressed paths passed", flush=True)
        finally:
            server.terminate()
            server.wait(timeout=10)


if __name__ == "__main__":
    main()
