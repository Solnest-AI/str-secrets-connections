"""KIE.ai MCP — one key, every model.

KIE exposes ~133 models (image, video, chat, music, upscale, avatar) through a single
unified API: POST /jobs/createTask {model, input} → poll /jobs/recordInfo. This server
wraps that so Claude can generate with ANY KIE model through a few generic tools.

Built from the proven logic in clone-ad/scripts/kie_generate.py. Auth: KIE_API_KEY
(env, or KIE_ENV_PATH file, or the repo .env). 1 credit = $0.005.
"""
from __future__ import annotations

import json
import os
import subprocess
import time
import urllib.request
from pathlib import Path
from typing import Any

from mcp.server.fastmcp import FastMCP

KIE_API = "https://api.kie.ai/api/v1"
KIE_UPLOAD = "https://kieai.redpandaai.co/api/file-stream-upload"
SCRIPT_DIR = Path(__file__).resolve().parent

mcp = FastMCP("kie")

# --- curated, slug-verified registry (any other KIE slug also works via create_task) ---
REGISTRY: dict = json.loads((SCRIPT_DIR / "models.json").read_text())
MODELS: dict = REGISTRY["models"]
ASPECT_TO_SIZE: dict = REGISTRY["aspect_to_image_size"]


# ---------- auth ----------
def _load_env() -> None:
    if os.environ.get("KIE_API_KEY"):
        return
    candidates = []
    if os.environ.get("KIE_ENV_PATH"):
        candidates.append(Path(os.environ["KIE_ENV_PATH"]))
    candidates += [
        Path.home() / "Solnest AI Automator" / ".env",
        SCRIPT_DIR.parent.parent.parent / ".env",  # repo root
    ]
    for p in candidates:
        if p.exists():
            for line in p.read_text().splitlines():
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))
            if os.environ.get("KIE_API_KEY"):
                return


def _key() -> str:
    _load_env()
    k = os.environ.get("KIE_API_KEY")
    if not k:
        raise RuntimeError("KIE_API_KEY not set (env, KIE_ENV_PATH, or repo .env).")
    return k


def _get(path: str) -> dict:
    req = urllib.request.Request(f"{KIE_API}{path}", headers={"Authorization": f"Bearer {_key()}"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def _post(path: str, body: dict) -> dict:
    req = urllib.request.Request(
        f"{KIE_API}{path}", data=json.dumps(body).encode(), method="POST",
        headers={"Authorization": f"Bearer {_key()}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


def _resolve(model: str) -> tuple[str, dict]:
    """Return (slug, cfg). `model` may be a registry key OR a raw KIE slug."""
    if model in MODELS:
        cfg = MODELS[model]
        return cfg["slug"], cfg
    return model, {}  # raw slug, no registry shaping


# ---------- tools ----------
@mcp.tool()
def kie_list_models() -> dict:
    """List the curated, slug-verified KIE models (image gen) + how to use any other model.

    Returns the ready-to-use models with their slugs and notes. ANY of KIE's ~133 models
    (video: kling/veo3/wan/hailuo/seedance, image: imagen4/ideogram/qwen/recraft, music: suno/
    elevenlabs, upscale: topaz, etc.) also works — pass its exact docs.kie.ai slug to
    kie_create_task. Browse all at https://docs.kie.ai (market/<provider>/<model>).
    """
    return {
        "default_model": REGISTRY.get("default_model"),
        "curated": {k: {"slug": v["slug"], "category": v.get("category"),
                        "takes_refs": bool(v.get("refs_key")), "note": v.get("note")}
                    for k, v in MODELS.items()},
        "any_slug_works": "Pass any docs.kie.ai market slug to kie_create_task — e.g. "
                          "'nanobanana2', 'google/imagen4', 'kling/v2-1-master-text-to-video', "
                          "'veo3', 'seedream/seedream-v4-text-to-image'.",
        "aspect_ratios": list(ASPECT_TO_SIZE.keys()),
    }


@mcp.tool()
def kie_credits() -> dict:
    """Check the KIE.ai account credit balance (1 credit = $0.005 USD)."""
    data = _get("/chat/credit")
    bal = data.get("data")
    return {"credits": bal, "usd_value": round(bal * 0.005, 2) if isinstance(bal, (int, float)) else None}


@mcp.tool()
def kie_upload_file(path_or_url: str) -> dict:
    """Upload a local image/file to KIE and get a hosted URL (needed for image-to-image refs).
    If given a URL already, returns it unchanged. Uploaded files expire after ~3 days.
    """
    if path_or_url.startswith(("http://", "https://")):
        return {"url": path_or_url}
    p = os.path.expanduser(path_or_url)
    if not os.path.exists(p):
        return {"error": f"file not found: {p}"}
    r = subprocess.run(
        ["curl", "-s", "-X", "POST", KIE_UPLOAD,
         "-H", f"Authorization: Bearer {_key()}",
         "-F", f"file=@{p}", "-F", "uploadPath=kie-mcp"],
        capture_output=True, text=True, timeout=120,
    )
    try:
        data = json.loads(r.stdout).get("data", {})
    except json.JSONDecodeError:
        return {"error": f"upload parse error: {r.stdout[:200]}"}
    url = data.get("fileUrl") or data.get("downloadUrl") or ""
    return {"url": url} if url else {"error": f"upload failed: {r.stdout[:200]}"}


@mcp.tool()
def kie_create_task(model: str, input: dict, callback_url: str | None = None) -> dict:
    """Create a generation task with ANY KIE model (the universal endpoint).

    Args:
        model: a curated key (e.g. 'gpt-image-2') OR a raw KIE slug (e.g. 'kling/v2-1-master-text-to-video').
        input: the model's input object, e.g. {"prompt": "...", "aspect_ratio": "1:1"}. For video/
               other models, pass whatever that model's docs.kie.ai page specifies.
        callback_url: optional webhook for completion (else poll with kie_get_task).
    Returns {task_id}. Poll kie_get_task(task_id) for the result.
    """
    slug, _ = _resolve(model)
    body: dict[str, Any] = {"model": slug, "input": input}
    if callback_url:
        body["callBackUrl"] = callback_url
    resp = _post("/jobs/createTask", body)
    task_id = (resp.get("data") or {}).get("taskId", "")
    if not task_id:
        return {"error": "createTask failed", "raw": resp}
    return {"task_id": task_id, "model": slug}


@mcp.tool()
def kie_get_task(task_id: str) -> dict:
    """Poll a KIE task once. Returns {state, result_urls}. state: WAITING/QUEUING/GENERATING/SUCCESS/FAIL."""
    data = (_get(f"/jobs/recordInfo?taskId={task_id}").get("data") or {})
    state = (data.get("state") or "").upper()
    out: dict[str, Any] = {"state": state, "result_urls": []}
    if state == "SUCCESS":
        rj = data.get("resultJson", {})
        if isinstance(rj, str):
            rj = json.loads(rj or "{}")
        urls = rj.get("resultUrls") or rj.get("result_urls") or []
        if not urls:
            for v in rj.values():
                if isinstance(v, list) and v:
                    urls = v
                    break
        out["result_urls"] = urls
    elif "FAIL" in state or "ERROR" in state:
        out["error"] = data.get("failMsg") or data.get("msg") or "task failed"
    return out


@mcp.tool()
def kie_generate_image(
    prompt: str,
    model: str = "gpt-image-2",
    aspect_ratio: str = "1:1",
    refs: list[str] | None = None,
    n: int = 1,
    max_wait_seconds: int = 360,
) -> dict:
    """Generate image(s) end-to-end: build input → create → poll → return result URLs.

    The simplest tool for making ads. Uses the curated registry to shape input per model
    (refs field, aspect vs image_size). For image-to-image, pass `refs` (local paths or URLs)
    and a model that takes refs (e.g. 'gpt-image-2-edit', 'nano-banana-pro', 'flux-pro').

    Args:
        prompt: the image prompt.
        model: curated key (default 'gpt-image-2') or a raw KIE image slug.
        aspect_ratio: 1:1 | 4:5 | 9:16 | 16:9 | 1.91:1.
        refs: reference images (local paths or URLs) for image-to-image models.
        n: how many variations to generate.
    Returns {model, result_urls, tasks}.
    """
    slug, cfg = _resolve(model)

    # upload refs if this model takes them
    ref_urls: list[str] = []
    refs_key = cfg.get("refs_key")
    if refs and refs_key:
        for f in refs:
            up = kie_upload_file(f)
            if up.get("url"):
                ref_urls.append(up["url"])

    # build input from registry shaping
    inp: dict[str, Any] = {"prompt": prompt}
    inp.update(cfg.get("defaults", {}))
    if refs_key and ref_urls:
        inp[refs_key] = ref_urls
    if cfg.get("size_mode") == "image_size":
        inp["image_size"] = ASPECT_TO_SIZE.get(aspect_ratio, "square_hd")
    else:
        inp["aspect_ratio"] = aspect_ratio

    tasks, all_urls = [], []
    for _ in range(max(1, n)):
        created = kie_create_task(model, inp)
        tid = created.get("task_id")
        if not tid:
            tasks.append({"error": created})
            continue
        # poll
        start = time.time()
        urls: list = []
        while time.time() - start < max_wait_seconds:
            res = kie_get_task(tid)
            if res["state"] == "SUCCESS":
                urls = res["result_urls"]
                break
            if "FAIL" in res["state"] or "ERROR" in res["state"]:
                break
            time.sleep(4)
        tasks.append({"task_id": tid, "state": res.get("state"), "result_urls": urls})
        all_urls.extend(urls)

    return {"model": slug, "result_urls": all_urls, "tasks": tasks}


if __name__ == "__main__":
    mcp.run()
