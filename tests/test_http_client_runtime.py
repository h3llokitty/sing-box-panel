"""Optional real startup test: SING_BOX_TEST_BIN=/path/to/1.14+/sing-box."""
import http.server
import json
import os
import runpy
import subprocess
import tempfile
import threading
import time
import unittest
from pathlib import Path

BIN = os.environ.get("SING_BOX_TEST_BIN")
ROOT = Path(__file__).resolve().parents[1]
migrate = runpy.run_path(str(ROOT / "render-client-profile.py"))["migrate_rule_set_http_clients"]


@unittest.skipUnless(BIN, "set SING_BOX_TEST_BIN to run a real rule-set download")
class HttpClientRuntimeTests(unittest.TestCase):
    def test_service_downloads_rules_without_detouring_to_empty_direct(self):
        downloaded = threading.Event()

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                payload = json.dumps({"version": 1, "rules": [{"domain": ["example.test"]}]}).encode()
                self.send_response(200)
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
                downloaded.set()

            def log_message(self, *args):
                pass

        server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            config = {"log": {"level": "info"},
                      "outbounds": [{"type": "direct", "tag": "direct"}],
                      "route": {"final": "direct", "rule_set": [{
                          "type": "remote", "tag": "test", "format": "source",
                          "url": f"http://127.0.0.1:{server.server_port}/rules.json",
                          "download_detour": "direct",
                      }]}}
            migrate(config)
            with tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "config.json"
                log = Path(directory) / "startup.log"
                path.write_text(json.dumps(config))
                with log.open("w") as stream:
                    process = subprocess.Popen([BIN, "run", "-c", str(path)], cwd=directory,
                                               stdout=stream, stderr=stream)
                    try:
                        deadline = time.monotonic() + 10
                        while time.monotonic() < deadline:
                            output = log.read_text()
                            if "sing-box started" in output or process.poll() is not None:
                                break
                            time.sleep(0.05)
                        output = log.read_text()
                        self.assertIn("sing-box started", output, output)
                        self.assertTrue(downloaded.is_set(), output)
                        self.assertNotIn("deprecated", output.lower(), output)
                        self.assertNotIn("empty direct outbound", output, output)
                    finally:
                        if process.poll() is None:
                            process.terminate()
                        process.wait(timeout=5)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)
