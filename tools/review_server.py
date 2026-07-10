#!/usr/bin/env python3
"""Local server for enemy card review with regeneration API."""
import http.server
import json
import os
import sys
import urllib.request
import urllib.error
import base64
import time
from pathlib import Path

ROOT = Path(r"F:\godot fair duet\create\phase-war")
TOOLS_DIR = ROOT / "tools"
HTML_FILE = TOOLS_DIR / "enemy_card_review.html"
ENEMY_ICONS_DIR = ROOT / "assets" / "card_icons" / "enemy"

# Hardcoded API key from config.yaml
API_KEY = "sk-thpXTkWon9RiLMdnsZgqlQUH7XI6SdlhLYsx7eQToj7GtIPv"
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"


class ReviewHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # suppress logs

    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            with open(HTML_FILE, "r", encoding="utf-8") as f:
                html_content = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(html_content.encode("utf-8"))
        elif self.path.startswith("/assets/"):
            file_path = ROOT / self.path.lstrip("/")
            if file_path.exists() and file_path.is_file():
                ext = file_path.suffix.lower()
                ct = "application/octet-stream"
                if ext == ".png": ct = "image/png"
                elif ext == ".jpg": ct = "image/jpeg"
                elif ext == ".css": ct = "text/css"
                elif ext == ".js": ct = "application/javascript"
                self.send_response(200)
                self.send_header("Content-Type", ct)
                self.send_header("Cache-Control", "no-cache")
                self.end_headers()
                with open(file_path, "rb") as f:
                    self.wfile.write(f.read())
            else:
                self.send_error(404)
        else:
            self.send_error(404)

    def do_POST(self):
        if self.path == "/api/regenerate-card":
            self.handle_regenerate()
        else:
            self.send_error(404)

    def handle_regenerate(self):
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            data = json.loads(body.decode("utf-8"))

            card_id = data.get("card_id", "")
            display_name = data.get("display_name", "")
            prompt = data.get("prompt", "")
            icon_filename = data.get("icon_filename", "")
            is_boss = data.get("is_boss", False)

            print(f"\n[REGEN] {display_name} ({card_id}) - boss={is_boss}")
            print(f"  Prompt: {prompt[:100]}...")

            if not API_KEY:
                raise Exception("API key not configured")

            api_url = BASE_URL + "/images/generations"
            payload = {
                "model": MODEL,
                "prompt": prompt,
                "size": "512x512",
                "n": 1,
            }
            headers = {
                "Authorization": "Bearer " + API_KEY,
                "Content-Type": "application/json",
            }

            req = urllib.request.Request(api_url,
                data=json.dumps(payload).encode(),
                headers=headers,
                method="POST"
            )

            with urllib.request.urlopen(req, timeout=120) as resp:
                resp_bytes = resp.read()
                result = json.loads(resp_bytes.decode("utf-8"))

            if "data" not in result or len(result["data"]) == 0:
                raise Exception("No image returned from API")

            img_data = result["data"][0]
            image_url = img_data.get("url")
            b64_data = img_data.get("b64_json")

            if not image_url and not b64_data:
                raise Exception("No image data in API response")

            save_path = ENEMY_ICONS_DIR / icon_filename

            if b64_data:
                img_bytes = base64.b64decode(b64_data)
            else:
                img_req = urllib.request.Request(image_url, headers={"Authorization": "Bearer " + API_KEY})
                with urllib.request.urlopen(img_req, timeout=30) as resp:
                    img_bytes = resp.read()

            with open(save_path, "wb") as f:
                f.write(img_bytes)

            print(f"  SAVED: {save_path}")

            ts = int(time.time())

            rel_path = "/" + str(save_path.relative_to(ROOT)) + "?ts=" + str(ts)
            response_body = json.dumps({
                "success": True,
                "card_id": card_id,
                "display_name": display_name,
                "save_path": str(save_path),
                "new_path": rel_path,
                "timestamp": ts,
            }, ensure_ascii=False)

            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            self.wfile.write(response_body.encode("utf-8"))

        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8", errors="replace") if hasattr(e, 'read') else str(e)
            print(f"  HTTP ERROR: {e.code} - {err_body[:200]}")
            error_resp = json.dumps({"error": "API error: " + str(e.code) + " " + err_body[:200]}, ensure_ascii=False)
            self.send_response(e.code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            self.wfile.write(error_resp.encode("utf-8"))
        except Exception as e:
            print(f"  ERROR: {e}")
            import traceback
            traceback.print_exc()
            error_body = json.dumps({"error": str(e)}, ensure_ascii=False)
            self.send_response(500)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            self.wfile.write(error_body.encode("utf-8"))


if __name__ == "__main__":
    port = 8765
    server = http.server.HTTPServer(("127.0.0.1", port), ReviewHandler)
    print("=" * 60)
    print("Enemy Card Review Server")
    print("=" * 60)
    print("URL: http://127.0.0.1:" + str(port))
    print("API Key: " + ("Found" if API_KEY else "NOT FOUND"))
    print("Icons dir: " + str(ENEMY_ICONS_DIR))
    print("Press Ctrl+C to stop")
    print("=" * 60)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")
        server.server_close()
