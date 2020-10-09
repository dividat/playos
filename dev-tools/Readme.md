# Dev tools

## Captive portal

Simulate a captive portal with [./captive-portal.py](captive-portal.py).

When accessing `http://localhost:8000`, you will initially be redirected to
`/portal` to login. Once you complete the form, you will get back to `/`, no
longer redirected to `/portal`.
