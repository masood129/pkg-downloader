#!/usr/bin/env python3
"""
Offline Linux Package Downloader - Web GUI Server
Pure Python 3 standard library - No external pip dependencies required.
"""

import http.server
import socketserver
import json
import os
import sys
import subprocess
import threading
import time
import uuid
import signal
import urllib.parse
import mimetypes

PORT = 5000
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STATIC_DIR = os.path.join(BASE_DIR, "static")
OUTPUT_DIR = os.path.join(BASE_DIR, "output")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Active and completed jobs
JOBS = {}
JOBS_LOCK = threading.Lock()

DISTROS_METADATA = {
    "ubuntu": {
        "name": "Ubuntu",
        "releases": [
            {"id": "26.04", "name": "Ubuntu 26.04 LTS (Resolute Raccoon)", "codename": "resolute"},
            {"id": "24.04", "name": "Ubuntu 24.04 LTS (Noble Numbat)", "codename": "noble"},
            {"id": "22.04", "name": "Ubuntu 22.04 LTS (Jammy Jellyfish)", "codename": "jammy"},
            {"id": "20.04", "name": "Ubuntu 20.04 LTS (Focal Fossa)", "codename": "focal"},
            {"id": "18.04", "name": "Ubuntu 18.04 LTS (Bionic Beaver)", "codename": "bionic"}
        ],
        "default_release": "24.04",
        "components": [
            {"id": "main", "name": "main (Officially Supported Free)", "default": True},
            {"id": "universe", "name": "universe (Community Maintained Free)", "default": True},
            {"id": "restricted", "name": "restricted (Proprietary Drivers)", "default": True},
            {"id": "multiverse", "name": "multiverse (Non-free / Restricted)", "default": True}
        ],
        "mirrors": [
            {"id": "ir", "name": "🇮🇷 Iran (ir.archive.ubuntu.com - Ultra Fast)", "url": "http://ir.archive.ubuntu.com/ubuntu/"},
            {"id": "global", "name": "🌍 Official Global (archive.ubuntu.com)", "url": "http://archive.ubuntu.com/ubuntu/"},
            {"id": "de", "name": "🇩🇪 Germany (de.archive.ubuntu.com)", "url": "http://de.archive.ubuntu.com/ubuntu/"},
            {"id": "us", "name": "🇺🇸 USA (us.archive.ubuntu.com)", "url": "http://us.archive.ubuntu.com/ubuntu/"},
            {"id": "custom", "name": "✏️ Custom Mirror URL", "url": ""}
        ],
        "default_mirror": "http://ir.archive.ubuntu.com/ubuntu/"
    },
    "debian": {
        "name": "Debian",
        "releases": [
            {"id": "12", "name": "Debian 12 (Bookworm - Stable)", "codename": "bookworm"},
            {"id": "11", "name": "Debian 11 (Bullseye - Oldstable)", "codename": "bullseye"},
            {"id": "10", "name": "Debian 10 (Buster)", "codename": "buster"}
        ],
        "default_release": "12",
        "components": [
            {"id": "main", "name": "main (Official Free Software)", "default": True},
            {"id": "contrib", "name": "contrib (Free with non-free deps)", "default": True},
            {"id": "non-free", "name": "non-free (Proprietary)", "default": True},
            {"id": "non-free-firmware", "name": "non-free-firmware (Firmware)", "default": True}
        ],
        "mirrors": [
            {"id": "global", "name": "🌍 Official Global (deb.debian.org)", "url": "http://deb.debian.org/debian/"},
            {"id": "ftp", "name": "🌍 Worldwide FTP (ftp.debian.org)", "url": "http://ftp.debian.org/debian/"},
            {"id": "de", "name": "🇩🇪 Germany (ftp.de.debian.org)", "url": "http://ftp.de.debian.org/debian/"},
            {"id": "us", "name": "🇺🇸 USA (ftp.us.debian.org)", "url": "http://ftp.us.debian.org/debian/"},
            {"id": "custom", "name": "✏️ Custom Mirror URL", "url": ""}
        ],
        "default_mirror": "http://deb.debian.org/debian/"
    }
}

class Job:
    def __init__(self, job_id, config):
        self.job_id = job_id
        self.config = config
        self.status = "running"  # running, completed, failed, cancelled
        self.logs = []
        self.listeners = []
        self.process = None
        self.start_time = time.time()
        self.end_time = None
        self.result_file = None
        self.error_message = None

    def add_log(self, text):
        entry = {"time": time.strftime("%H:%M:%S"), "text": text}
        self.logs.append(entry)
        with JOBS_LOCK:
            dead = []
            for q in self.listeners:
                try:
                    q.put(entry)
                except Exception:
                    dead.append(q)
            for d in dead:
                self.listeners.remove(d)

    def to_dict(self):
        return {
            "job_id": self.job_id,
            "status": self.status,
            "config": self.config,
            "start_time": self.start_time,
            "end_time": self.end_time,
            "duration": round((self.end_time or time.time()) - self.start_time, 1),
            "result_file": self.result_file,
            "error_message": self.error_message,
            "log_count": len(self.logs)
        }

def ensure_docker_image(distro, release):
    """Ensures the docker image pkg-downloader:<distro>-<release> exists."""
    image_tag = f"pkg-downloader:{distro}-{release}"
    check_cmd = ["docker", "image", "inspect", image_tag]
    if subprocess.run(check_cmd, capture_output=True).returncode != 0:
        # Build image
        build_cmd = [
            "docker", "build",
            "--network=host",
            "--build-arg", f"DISTRO={distro}",
            "--build-arg", f"DISTRO_VERSION={release}",
            "-t", image_tag,
            BASE_DIR
        ]
        subprocess.run(build_cmd, capture_output=True, check=True)
    return image_tag

def run_download_job(job):
    cfg = job.config
    pkg = cfg.get("package", "").strip()
    distro = cfg.get("distro", "ubuntu")
    release = cfg.get("release", "24.04")
    version = cfg.get("version", "").strip()
    arch = cfg.get("arch", "amd64")
    mirror = cfg.get("mirror", "").strip()
    components = cfg.get("components", "")
    format_type = cfg.get("format", "zip")
    include_recommends = cfg.get("include_recommends", False)
    include_suggests = cfg.get("include_suggests", False)

    job.add_log(f"🚀 Initializing download task for package: {pkg}")
    if version:
        job.add_log(f"📌 Selected exact version: {version}")
    job.add_log(f"🐧 Target OS: {distro} {release} ({arch})")

    # Prepare command
    cmd = [
        os.path.join(BASE_DIR, "download.sh"),
        "-p", pkg,
        "-d", distro,
        "-r", release,
        "-a", arch,
        "-f", format_type,
        "-o", OUTPUT_DIR,
        "--job-id", job.job_id
    ]

    if version:
        cmd.extend(["-v", version])
    if mirror:
        cmd.extend(["-m", mirror])
    if components:
        cmd.extend(["-c", components])
    if include_recommends:
        cmd.append("--include-recommends")
    if include_suggests:
        cmd.append("--include-suggests")

    job.add_log(f"📦 Executing runner: {' '.join(cmd)}")

    try:
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            cwd=BASE_DIR,
            start_new_session=True
        )
        job.process = process

        for line in iter(process.stdout.readline, ''):
            if job.status == "cancelled":
                break
            clean_line = line.rstrip('\r\n')
            if clean_line:
                job.add_log(clean_line)

        process.stdout.close()
        return_code = process.wait()

        job.end_time = time.time()
        if job.status == "cancelled":
            job.add_log("🛑 Download cancelled.")
        elif return_code == 0:
            job.status = "completed"
            job.add_log("🎉 Process finished successfully!")
            files = [f for f in os.listdir(OUTPUT_DIR) if f.startswith(pkg) and (f.endswith(".zip") or f.endswith(".tar.gz"))]
            if files:
                files.sort(key=lambda x: os.path.getmtime(os.path.join(OUTPUT_DIR, x)), reverse=True)
                job.result_file = files[0]
        else:
            job.status = "failed"
            job.error_message = f"Process exited with code {return_code}"
            job.add_log(f"❌ Error: {job.error_message}")

    except Exception as e:
        if job.status != "cancelled":
            job.status = "failed"
            job.error_message = str(e)
            job.end_time = time.time()
            job.add_log(f"❌ Fatal Exception: {str(e)}")

class RequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=STATIC_DIR, **kwargs)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == "/":
            self.path = "/index.html"
            return super().do_GET()

        elif path == "/api/distros":
            self.send_json(DISTROS_METADATA)

        elif path == "/api/jobs":
            with JOBS_LOCK:
                job_list = [j.to_dict() for j in reversed(list(JOBS.values()))]
            self.send_json(job_list)

        elif path.startswith("/api/job/"):
            job_id = path.split("/")[-1]
            with JOBS_LOCK:
                job = JOBS.get(job_id)
            if job:
                self.send_json(job.to_dict())
            else:
                self.send_error(404, "Job not found")

        elif path.startswith("/api/logs/"):
            job_id = path.split("/")[-1]
            self.handle_sse_logs(job_id)

        elif path == "/api/files":
            self.handle_list_files()

        elif path.startswith("/download/"):
            filename = urllib.parse.unquote(path.replace("/download/", ""))
            filepath = os.path.join(OUTPUT_DIR, filename)
            if os.path.exists(filepath) and os.path.isfile(filepath):
                self.serve_download(filepath, filename)
            else:
                self.send_error(404, "File not found")

        else:
            return super().do_GET()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == "/api/check-package":
            data = self.read_json_body()
            self.handle_check_package(data)

        elif path == "/api/download":
            data = self.read_json_body()
            self.handle_start_download(data)

        elif path.startswith("/api/cancel/"):
            job_id = path.split("/")[-1]
            self.handle_cancel_job(job_id)

        elif path.startswith("/api/delete-file/"):
            filename = urllib.parse.unquote(path.replace("/api/delete-file/", ""))
            self.handle_delete_file(filename)

        elif path == "/api/open-folder":
            self.handle_open_folder()

        else:
            self.send_error(404, "Not found")

    def read_json_body(self):
        length = int(self.headers.get('Content-Length', 0))
        if length > 0:
            raw = self.rfile.read(length).decode('utf-8')
            try:
                return json.loads(raw)
            except Exception:
                return {}
        return {}

    def send_json(self, data, status=200):
        body = json.dumps(data).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(body)

    def handle_check_package(self, data):
        pkg = data.get("package", "").strip()
        distro = data.get("distro", "ubuntu")
        release = data.get("release", "24.04")
        mirror = data.get("mirror", "").strip()
        components = data.get("components", "")

        if not pkg:
            self.send_json({"error": "Package name required"}, 400)
            return

        try:
            image_tag = ensure_docker_image(distro, release)
        except Exception as e:
            self.send_json({"error": f"Failed to prepare Docker image: {str(e)}", "found": False, "versions": []})
            return

        check_cmd = [
            "docker", "run", "--rm", "--network=host",
            "-v", f"{BASE_DIR}/entrypoint.sh:/usr/local/bin/entrypoint.sh:ro",
            image_tag,
            "-p", pkg,
            "--check-versions"
        ]
        if mirror:
            check_cmd.extend(["-m", mirror])
        if components:
            check_cmd.extend(["-c", components])

        try:
            res = subprocess.run(
                check_cmd,
                capture_output=True,
                text=True,
                timeout=30
            )

            versions = []
            seen_versions = set()
            for line in res.stdout.strip().split('\n'):
                parts = [p.strip() for p in line.split('|')]
                if len(parts) >= 3:
                    v_str = parts[1]
                    source_str = parts[2]
                    tokens = source_str.split()
                    source_label = tokens[1] if len(tokens) >= 2 else (tokens[0] if tokens else "repository")
                    if v_str and v_str not in seen_versions:
                        seen_versions.add(v_str)
                        versions.append({
                            "version": v_str,
                            "source": source_label,
                            "full_source": source_str
                        })

            self.send_json({
                "package": pkg,
                "found": len(versions) > 0,
                "versions": versions,
                "distro": f"{distro} {release}",
                "count": len(versions)
            })
        except Exception as e:
            self.send_json({"error": str(e), "package": pkg, "found": False, "versions": []})

    def handle_start_download(self, data):
        pkg = data.get("package", "").strip()
        if not pkg:
            self.send_json({"error": "Package name is required"}, 400)
            return

        job_id = str(uuid.uuid4())[:8]
        job = Job(job_id, data)

        with JOBS_LOCK:
            JOBS[job_id] = job

        t = threading.Thread(target=run_download_job, args=(job,), daemon=True)
        t.start()

        self.send_json({
            "status": "started",
            "job_id": job_id,
            "config": data
        })

    def handle_cancel_job(self, job_id):
        with JOBS_LOCK:
            job = JOBS.get(job_id)
        if not job:
            self.send_json({"error": "Job not found"}, 404)
            return

        if job.status == "running":
            job.status = "cancelled"
            job.end_time = time.time()
            job.add_log("🛑 Download cancelled by user.")

            # 1. Kill process group
            if job.process and job.process.pid:
                try:
                    os.killpg(os.getpgid(job.process.pid), signal.SIGTERM)
                    time.sleep(0.3)
                    os.killpg(os.getpgid(job.process.pid), signal.SIGKILL)
                except Exception:
                    pass

            # 2. Force remove docker container
            try:
                subprocess.run(["docker", "rm", "-f", f"pkg-dl-{job_id}"], capture_output=True, timeout=5)
            except Exception:
                pass

        self.send_json({"status": "cancelled", "job_id": job_id})

    def handle_sse_logs(self, job_id):
        with JOBS_LOCK:
            job = JOBS.get(job_id)
        if not job:
            self.send_error(404, "Job not found")
            return

        import queue
        q = queue.Queue()

        with JOBS_LOCK:
            for l in job.logs:
                q.put(l)
            job.listeners.append(q)

        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream; charset=utf-8')
        self.send_header('Cache-Control', 'no-cache')
        self.send_header('Connection', 'keep-alive')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()

        try:
            while True:
                try:
                    entry = q.get(timeout=0.5)
                    msg = f"data: {json.dumps(entry)}\n\n"
                    self.wfile.write(msg.encode('utf-8'))
                    self.wfile.flush()
                except queue.Empty:
                    # Heartbeat
                    self.wfile.write(b": heartbeat\n\n")
                    self.wfile.flush()

                if job.status in ["completed", "failed", "cancelled"] and q.empty():
                    final_msg = f"data: {json.dumps({'time': time.strftime('%H:%M:%S'), 'text': f'[STATUS:{job.status}]', 'done': True, 'result_file': job.result_file})}\n\n"
                    self.wfile.write(final_msg.encode('utf-8'))
                    self.wfile.flush()
                    break
        except Exception:
            pass
        finally:
            with JOBS_LOCK:
                if q in job.listeners:
                    job.listeners.remove(q)

    def handle_list_files(self):
        files = []
        if os.path.exists(OUTPUT_DIR):
            for name in os.listdir(OUTPUT_DIR):
                if name.endswith(".zip") or name.endswith(".tar.gz"):
                    path = os.path.join(OUTPUT_DIR, name)
                    stat = os.stat(path)
                    files.append({
                        "name": name,
                        "size": stat.st_size,
                        "size_human": format_size(stat.st_size),
                        "mtime": stat.st_mtime,
                        "date": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(stat.st_mtime)),
                        "download_url": f"/download/{urllib.parse.quote(name)}"
                    })
            files.sort(key=lambda x: x["mtime"], reverse=True)
        self.send_json(files)

    def handle_delete_file(self, filename):
        filepath = os.path.join(OUTPUT_DIR, filename)
        if os.path.exists(filepath) and os.path.isfile(filepath):
            os.remove(filepath)
            self.send_json({"success": True, "deleted": filename})
        else:
            self.send_json({"error": "File not found"}, 404)

    def handle_open_folder(self):
        try:
            if sys.platform.startswith("linux"):
                subprocess.Popen(["xdg-open", OUTPUT_DIR])
            elif sys.platform == "darwin":
                subprocess.Popen(["open", OUTPUT_DIR])
            self.send_json({"success": True, "path": OUTPUT_DIR})
        except Exception as e:
            self.send_json({"error": str(e)}, 500)

    def serve_download(self, filepath, filename):
        stat = os.stat(filepath)
        content_type, _ = mimetypes.guess_type(filepath)
        if not content_type:
            content_type = "application/octet-stream"

        self.send_response(200)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(stat.st_size))
        self.send_header('Content-Disposition', f'attachment; filename="{filename}"')
        self.end_headers()

        with open(filepath, 'rb') as f:
            while chunk := f.read(65536):
                self.wfile.write(chunk)

def format_size(size_bytes):
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.1f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.1f} TB"

def main():
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), RequestHandler) as httpd:
        print(f"🚀 Offline Package Downloader GUI running at: http://localhost:{PORT}")
        print("Press Ctrl+C to stop.")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down server...")

if __name__ == "__main__":
    main()
