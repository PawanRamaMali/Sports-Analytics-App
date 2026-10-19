import os
import shutil
import socket
import subprocess
import time
from pathlib import Path

import pytest
from playwright.sync_api import expect

HOST = "127.0.0.1"
PORT = int(os.environ.get("UI_PORT", "3839"))
PROJECT_ROOT = Path(__file__).resolve().parents[2]

# Shiny renders after a round trip to R, so allow more than the 5s default.
expect.set_options(timeout=15_000)


def _port_open():
    with socket.socket() as s:
        s.settimeout(0.5)
        return s.connect_ex((HOST, PORT)) == 0


def _rscript():
    path = os.environ.get("RSCRIPT") or shutil.which("Rscript")
    if not path:
        pytest.exit("Rscript not found. Add it to PATH or set the RSCRIPT env var.", returncode=2)
    return path


@pytest.fixture(scope="session", autouse=True)
def shiny_app(tmp_path_factory):
    if _port_open():
        pytest.exit(f"Port {PORT} is already in use; stop the other process first.", returncode=2)

    # The app gets its own users file and a copy of the seasons.
    tmp = tmp_path_factory.mktemp("app")
    shutil.copytree(PROJECT_ROOT / "data" / "seasons", tmp / "seasons")
    env = {**os.environ, "UI_PORT": str(PORT),
           "SPORTS_DATA_DIR": str(tmp / "seasons"), "SPORTS_USERS_FILE": str(tmp / "users.csv")}
    # A log file, not a pipe: a full pipe would block the app.
    log_path = tmp / "app.log"
    log = open(log_path, "wb")
    proc = subprocess.Popen([_rscript(), "tests/ui/start_app.R"], cwd=PROJECT_ROOT, env=env,
                            stdout=log, stderr=subprocess.STDOUT)
    try:
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            if proc.poll() is not None:
                err = log_path.read_text(errors="replace")
                pytest.exit(f"Shiny app exited early (code {proc.returncode}):\n{err}", returncode=2)
            if _port_open():
                break
            time.sleep(0.25)
        else:
            pytest.exit(f"Shiny app did not accept connections on {HOST}:{PORT} within 120s.", returncode=2)
        yield proc
    finally:
        # Rscript.exe starts R in a child process; /T stops both.
        if os.name == "nt":
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)], capture_output=True)
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
        log.close()


@pytest.fixture(scope="session")
def base_url():
    return f"http://{HOST}:{PORT}"


@pytest.fixture(scope="session")
def browser_context_args(browser_context_args):
    return {**browser_context_args, "viewport": {"width": 1400, "height": 900}}
