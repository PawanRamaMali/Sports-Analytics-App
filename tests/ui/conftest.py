import os
import re
import shutil
import socket
import subprocess
import time
from pathlib import Path

import pytest
from playwright.sync_api import expect
from slugify import slugify

from report import write_reports

HOST = "127.0.0.1"
PORT = int(os.environ.get("UI_PORT", "3839"))
PROJECT_ROOT = Path(__file__).resolve().parents[2]
RESULTS_DIR = PROJECT_ROOT / "test-results"
STARTED = time.monotonic()

# One entry per test, in run order, for report.py.
_results = {}
_app_startup = {}

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
    started = time.monotonic()
    try:
        deadline = started + 120
        while time.monotonic() < deadline:
            if proc.poll() is not None:
                err = log_path.read_text(errors="replace")
                pytest.exit(f"Shiny app exited early (code {proc.returncode}):\n{err}", returncode=2)
            if _port_open():
                break
            time.sleep(0.25)
        else:
            pytest.exit(f"Shiny app did not accept connections on {HOST}:{PORT} within 120s.", returncode=2)
        _app_startup["seconds"] = time.monotonic() - started
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


# --- Reports -----------------------------------------------------------------

@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    rep = (yield).get_result()
    params = getattr(item, "callspec", None)
    # Drop pytest-playwright's browser parameter from the id.
    params = re.sub(r"^chromium-?", "", params.id) if params and params.id != "chromium" else None
    r = _results.setdefault(item.nodeid, {
        "nodeid": item.nodeid, "file": item.path.name, "name": item.originalname, "params": params,
        "outcome": "passed", "duration": 0.0, "message": "", "details": "", "screenshot": None, "trace": None,
    })
    # The first test's setup also starts the app; that is not the test's time.
    r["duration"] += max(rep.duration - (_app_startup.pop("seconds", 0) if rep.when == "setup" else 0), 0)
    if rep.failed:
        r["outcome"] = "failed" if rep.when == "call" else "error"
        crash = getattr(rep.longrepr, "reprcrash", None)
        r["message"] = crash.message if crash else rep.longreprtext.strip().splitlines()[-1]
        r["details"] = rep.longreprtext
    elif rep.skipped and r["outcome"] == "passed":
        r["outcome"] = "skipped"
        r["message"] = rep.longrepr[2] if isinstance(rep.longrepr, tuple) else str(rep.longrepr)


# A screenshot of every test's page as it was at the end, pass or fail.
@pytest.fixture(autouse=True)
def end_screenshot(request, page):
    yield
    name = re.sub(r"[^A-Za-z0-9._-]+", "_", request.node.nodeid.split("/")[-1]).strip("_")
    path = RESULTS_DIR / "screenshots" / f"{name}.png"
    try:
        page.screenshot(path=path)
    except Exception:
        return
    _results[request.node.nodeid]["screenshot"] = path.relative_to(RESULTS_DIR).as_posix()


def pytest_sessionfinish(session):
    if not _results:
        return
    for r in _results.values():
        # Where pytest-playwright keeps the trace of a failed test.
        trace = RESULTS_DIR / slugify(r["nodeid"]) / "trace.zip"
        if trace.exists():
            r["trace"] = trace.relative_to(RESULTS_DIR).as_posix()
    write_reports(list(_results.values()), RESULTS_DIR, time.monotonic() - STARTED)
