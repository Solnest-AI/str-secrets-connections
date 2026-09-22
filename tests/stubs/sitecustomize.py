# Loaded automatically by Python's `site` when tests/stubs is on PYTHONPATH.
# `time` is a built-in module and cannot be shadowed from sys.path, so the
# helper's 15-second poll sleep is neutralised here instead. Tests only.
import time
time.sleep = lambda _seconds: None
