# Dev tools

## Captive portal

Simulate a captive portal with [./captive-portal.py](captive-portal.py).

When accessing `http://localhost:8000`, you will initially be redirected to
`/portal` to login. Once you complete the form, you will get back to `/`, no
longer redirected to `/portal`.

In order to use the simulated captive portal, set the environment variable
before starting kiosk or controller:

    export PLAYOS_CAPTIVE_CHECK_URL="http://localhost:8000"


## Mock connman

Simulates (some of) connman's D-BUS APIs, useful for testing controller's UI.

See docs in [mock-connman.py](mock-connman.py) for more details.

## Metric plotting in Grafana

See Readme in [grafana](grafana/Readme.md).
