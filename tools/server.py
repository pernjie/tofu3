"""
Dev tool: JSON data browser server for Patrons of the Night.

Serves a browser UI for viewing and editing game data JSON files.
Run from project root: python tools/server.py
"""

import http.server
import json
import sys
import webbrowser
from pathlib import Path
from urllib.parse import unquote

PORT = 8099

# Resolve project root: either cwd (if data/ exists) or parent of tools/
SCRIPT_DIR = Path(__file__).resolve().parent
if (Path.cwd() / "data").is_dir():
    PROJECT_ROOT = Path.cwd()
elif (SCRIPT_DIR.parent / "data").is_dir():
    PROJECT_ROOT = SCRIPT_DIR.parent
else:
    print("Error: Cannot find project root (no data/ directory found).")
    sys.exit(1)

DATA_DIR = PROJECT_ROOT / "data"


def get_type_dirs() -> list[str]:
    """Return sorted list of subdirectory names in data/."""
    return sorted(
        entry.name
        for entry in DATA_DIR.iterdir()
        if entry.is_dir()
    )


def get_json_files(type_name: str) -> list[dict]:
    """Load all JSON files for a given type, excluding _schema.json.

    For 'stalls', walks subdirectories recursively.
    Each returned dict includes a '_file_path' key (relative to project root).
    """
    type_dir = DATA_DIR / type_name
    if not type_dir.is_dir():
        return []

    results = []
    for json_path in sorted(type_dir.rglob("*.json")):
        if json_path.name == "_schema.json":
            continue
        try:
            data = json.loads(json_path.read_text(encoding="utf-8"))
            data["_file_path"] = str(json_path.relative_to(PROJECT_ROOT))
            results.append(data)
        except (json.JSONDecodeError, OSError) as e:
            print(f"Warning: Skipping {json_path}: {e}")

    return results


def write_json_file(file_path_rel: str, data: dict) -> None:
    """Write JSON data back to disk.

    Strips _file_path from the content. Preserves $schema as the first key.
    Pretty-prints with 2-space indent.
    """
    abs_path = PROJECT_ROOT / file_path_rel

    # Safety: only allow writing within data/
    try:
        abs_path.resolve().relative_to(DATA_DIR.resolve())
    except ValueError:
        raise ValueError(f"Path {file_path_rel} is outside data/ directory")

    # Strip _file_path, capture and strip $schema
    schema_value = data.pop("$schema", None)
    data.pop("_file_path", None)

    # Rebuild with $schema as first key
    output = {}
    if schema_value is not None:
        output["$schema"] = schema_value
    output.update(data)

    abs_path.write_text(
        json.dumps(output, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


class Handler(http.server.BaseHTTPRequestHandler):
    def _send_json(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_error_json(self, status, message):
        self._send_json({"error": message}, status)

    def do_GET(self):
        path = unquote(self.path)

        # Serve browser.html at root
        if path == "/" or path == "/index.html":
            html_path = SCRIPT_DIR / "browser.html"
            if not html_path.is_file():
                self.send_error(404, "browser.html not found")
                return
            body = html_path.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        # API: list type directories
        if path == "/api/types":
            self._send_json(get_type_dirs())
            return

        # API: get all data for a type
        if path.startswith("/api/data/"):
            type_name = path[len("/api/data/"):]
            type_dir = DATA_DIR / type_name
            if not type_dir.is_dir():
                self._send_error_json(404, f"Unknown type: {type_name}")
                return
            self._send_json(get_json_files(type_name))
            return

        self.send_error(404)

    def do_PUT(self):
        path = unquote(self.path)

        if path == "/api/data":
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            try:
                data = json.loads(body)
            except json.JSONDecodeError as e:
                self._send_error_json(400, f"Invalid JSON: {e}")
                return

            file_path = data.get("_file_path")
            if not file_path:
                self._send_error_json(400, "Missing _file_path field")
                return

            try:
                write_json_file(file_path, data)
            except ValueError as e:
                self._send_error_json(403, str(e))
                return
            except OSError as e:
                self._send_error_json(500, f"Write failed: {e}")
                return

            self._send_json({"ok": True})
            return

        self.send_error(404)

    def log_message(self, format, *args):
        # Quieter logging: just method + path
        print(f"  {args[0]}" if args else "")


class ReusableHTTPServer(http.server.HTTPServer):
    allow_reuse_address = True


def main():
    server = ReusableHTTPServer(("localhost", PORT), Handler)
    url = f"http://localhost:{PORT}/"
    print(f"Data browser server running at {url}")
    print(f"Project root: {PROJECT_ROOT}")
    print("Press Ctrl+C to stop.\n")
    webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.shutdown()


if __name__ == "__main__":
    main()
