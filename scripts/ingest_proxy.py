#!/usr/bin/env python3
import argparse
import http.server
import json
import os
import socketserver
import urllib.error
import urllib.request


class ForwardHandler(http.server.BaseHTTPRequestHandler):
    target_base = ""
    ingest_key = ""

    def log_message(self, fmt: str, *args) -> None:
        return

    def do_POST(self) -> None:
        content_length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(content_length)
        target_url = f"{self.target_base}{self.path}"
        request = urllib.request.Request(
            target_url,
            data=body,
            method="POST",
            headers={
                "Content-Type": self.headers.get("Content-Type", "application/json"),
                "Accept": "application/json",
                "X-Manifold-Ingest-Key": self.ingest_key,
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                status = response.status
                payload = response.read()
                headers = response.headers
        except urllib.error.HTTPError as err:
            status = err.code
            payload = err.read()
            headers = err.headers
        except Exception as err:  # noqa: BLE001
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(err)}).encode("utf-8"))
            return

        self.send_response(status)
        self.send_header("Content-Type", headers.get("Content-Type", "application/json"))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self) -> None:
        # keep one endpoint for quick smoke checks
        if self.path == "/healthz":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"ok":true}')
            return
        self.send_response(404)
        self.end_headers()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bind", default=os.environ.get("VORTEX_PROXY_ADDR", "127.0.0.1:18080"))
    parser.add_argument("--target", required=True)
    parser.add_argument("--ingest-key", required=True)
    args = parser.parse_args()

    host, port_str = args.bind.rsplit(":", 1)
    port = int(port_str)
    ForwardHandler.target_base = args.target.rstrip("/")
    ForwardHandler.ingest_key = args.ingest_key

    with socketserver.TCPServer((host, port), ForwardHandler) as httpd:
        httpd.serve_forever()


if __name__ == "__main__":
    main()
