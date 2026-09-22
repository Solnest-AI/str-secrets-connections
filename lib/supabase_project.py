# $BUNDLE/lib/supabase_project.py  (created in this task)
import json, os, secrets, sys, time, urllib.request
TOK = os.environ["SUPABASE_ACCESS_TOKEN"]; H = {"Authorization": f"Bearer {TOK}", "Content-Type": "application/json"}
def call(method, path, body=None):
    req = urllib.request.Request("https://api.supabase.com/v1" + path, method=method, headers=H, data=json.dumps(body).encode() if body else None)
    with urllib.request.urlopen(req, timeout=30) as r: return json.load(r)
projects = call("GET", "/projects")
match = [p for p in projects if p["name"] == "str-secrets-summit"]
if match: print("REF=" + match[0]["ref"]); sys.exit(0)
active = [p for p in projects if p.get("status") in ("ACTIVE_HEALTHY", "COMING_UP")]
if len(active) >= 2:
    print("CAP: free tier allows 2 active projects; existing: " + ", ".join(p["name"] for p in active)); sys.exit(3)
org = call("GET", "/organizations")[0]["slug"]
pw = secrets.token_urlsafe(24)
region = os.environ.get("SUPABASE_REGION", "us-east-1")   # Claude asks once: US East (us-east-1), Canada Central (ca-central-1), EU West (eu-west-1)
# Body per the Management API spec (api.supabase.com/api/v1-json, read 2026-09-21): required db_pass, name, organization_slug.
# organization_id, region and plan are deprecated there (plan is set on the organization and ignored), so none of them is sent.
p = call("POST", "/projects", {"name": "str-secrets-summit", "organization_slug": org, "db_pass": pw, "region_selection": {"type": "specific", "code": region}})
with open(os.environ["BUNDLE_ENV"], "a") as f: f.write(f"SUPABASE_DB_PASSWORD={pw}\n")
for _ in range(40):
    time.sleep(15); s = call("GET", f"/projects/{p['ref']}").get("status")
    if s == "ACTIVE_HEALTHY": break
print("REF=" + p["ref"])
