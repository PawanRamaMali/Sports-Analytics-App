# UI tests (pytest + Playwright)

Everything runs on 127.0.0.1 with the locally installed Chrome. Nothing is
sent to an external service.

## Install

    python -m venv .venv
    .venv\Scripts\activate            # source .venv/bin/activate elsewhere
    pip install -r tests/ui/requirements-test.txt

No `playwright install` is needed: `pytest.ini` passes `--browser-channel
chrome`, so the tests use the installed Chrome. Set
`PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` if pip tries to fetch a browser.

If `Rscript` is not on PATH, set `RSCRIPT` to its full path, e.g.
`set RSCRIPT=C:\Program Files\R\R-4.5.1\bin\Rscript.exe`.

## Run (from the repo root)

    pytest tests/ui -v                              # headless
    pytest tests/ui -v --headed --slowmo 300        # watch it run
    pytest tests/ui/test_admin.py                   # one file
    pytest tests/ui -k lock                         # tests whose name matches

`conftest.py` starts the app with `tests/ui/start_app.R` on port 3839 (set
`UI_PORT` to change it) and stops it afterwards. The app gets a temporary
copy of `data/seasons` and its own users file with `e2e-admin` and
`e2e-analyst` (see `helpers.py`), so a run never touches `data/`. The port
must be free.

| File | Covers |
|---|---|
| `test_auth.py` | sign-in page, errors, Enter key, analyst menu, sign out |
| `test_analysis.py` | Players, Player profile, Compare, Teams, Leaders, Player types |
| `test_admin.py` | adding users, password rules, self-delete guard, CSV import, fetch validation |
| `test_edge_cases.py` | lockout after five failures, username trimming and case, empty search, the three-player limit, bad season names, missing file, duplicate players, duplicate usernames |

## Debug

- `PWDEBUG=1 pytest tests/ui -k lock --headed` opens the Playwright Inspector.
- A failed test leaves a screenshot and a trace under `test-results/`;
  open the trace with `playwright show-trace test-results/<test>/trace.zip`.

## Find element IDs

Shiny ids are `<module>-<id>`, e.g. `players-table` for `ns("table")` in
`modules/players_module.R`. Inspect the element in the browser to confirm.
Navbar screens are tabs (`screen()`), selectize inputs go through `pick()`,
reactable rows through `table_rows()`.

## Check that a test catches a bug

In `modules/welcome_module.R`, change `failures() >= 5` to `failures() >= 50`
and run `pytest tests/ui -k lock`: it must fail. Revert afterwards.
