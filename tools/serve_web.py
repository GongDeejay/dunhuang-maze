#!/usr/bin/env python3
"""本地 Web 冒烟服务器（含 Godot 所需 COOP/COEP 头）"""
from __future__ import annotations

import argparse
import http.server
import socketserver
from pathlib import Path


class GodotWebHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        if self.path.endswith(".html") or self.path == "/":
            self.send_header("Cache-Control", "no-cache")
        super().end_headers()


def main() -> None:
    parser = argparse.ArgumentParser(description="Serve Godot web export with COOP/COEP")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8060)
    parser.add_argument(
        "--dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "web",
        help="Path to web export directory",
    )
    args = parser.parse_args()
    web_dir = args.dir.resolve()
    if not web_dir.is_dir():
        raise SystemExit(f"Web directory not found: {web_dir}")

    import os

    os.chdir(web_dir)
    with socketserver.TCPServer((args.host, args.port), GodotWebHandler) as httpd:
        url = f"http://{args.host}:{args.port}/index.html"
        print(f"Serving {web_dir}")
        print(f"Open: {url}")
        print("Headers: COOP=same-origin, COEP=require-corp")
        httpd.serve_forever()


if __name__ == "__main__":
    main()
