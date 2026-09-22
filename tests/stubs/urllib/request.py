"""Canned Supabase Management API for tests/test_supabase_project.sh.

Scenario comes from STUB_SCENARIO:
  existing  GET /projects already holds str-secrets-summit  -> helper prints REF=, no POST
  cap       GET /projects holds two ACTIVE_HEALTHY projects -> helper prints CAP, exit 3
  create    GET /projects is empty                          -> helper POSTs, waits, prints REF=
Every call is appended to the file named by STUB_LOG as one JSON line
({"method","url","body"}) so the test can assert what was sent.
"""
import io, json, os

SCENARIO = os.environ.get("STUB_SCENARIO", "create")
NEW_REF = "newref123456"

PROJECTS = {
    "existing": [
        {"id": "abc123ref", "ref": "abc123ref", "name": "str-secrets-summit", "status": "ACTIVE_HEALTHY"},
        {"id": "otherref1", "ref": "otherref1", "name": "personal-blog", "status": "INACTIVE"},
    ],
    "cap": [
        {"id": "ref-one", "ref": "ref-one", "name": "first-app", "status": "ACTIVE_HEALTHY"},
        {"id": "ref-two", "ref": "ref-two", "name": "second-app", "status": "COMING_UP"},
        {"id": "ref-paused", "ref": "ref-paused", "name": "paused-app", "status": "INACTIVE"},
    ],
    "create": [],
}


class Request:
    def __init__(self, url, data=None, headers=None, method="GET"):
        self.full_url = url
        self.data = data
        self.headers = dict(headers or {})
        self.method = method


class _Response(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()
        return False


def _log(req):
    path = os.environ.get("STUB_LOG")
    if not path:
        return
    body = json.loads(req.data.decode()) if req.data else None
    with open(path, "a") as f:
        f.write(json.dumps({"method": req.method, "url": req.full_url, "body": body}) + "\n")


def urlopen(req, timeout=None):
    _log(req)
    auth = req.headers.get("Authorization", "")
    if not auth.startswith("Bearer ") or len(auth) <= len("Bearer "):
        raise RuntimeError("stub: missing bearer token")
    url = req.full_url
    if req.method == "GET" and url.endswith("/v1/projects"):
        payload = PROJECTS[SCENARIO]
    elif req.method == "GET" and url.endswith("/v1/organizations"):
        payload = [{"id": "org-id-1", "slug": "org-slug-1", "name": "Test Org"}]
    elif req.method == "POST" and url.endswith("/v1/projects"):
        payload = {"id": NEW_REF, "ref": NEW_REF, "name": "str-secrets-summit", "status": "COMING_UP"}
    elif req.method == "GET" and url.endswith("/v1/projects/" + NEW_REF):
        payload = {"id": NEW_REF, "ref": NEW_REF, "name": "str-secrets-summit", "status": "ACTIVE_HEALTHY"}
    else:
        raise RuntimeError(f"stub: unexpected call {req.method} {url}")
    return _Response(json.dumps(payload).encode())
