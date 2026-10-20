#!/usr/bin/env python3
"""End-to-end smoke test for the replacement backend. Never prints the API key."""
from __future__ import annotations

import hashlib
import json
import sys
import tempfile
from pathlib import Path

import httpx

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8787"
OUT = Path(__file__).resolve().parents[1] / "evidence" / "backend"
OUT.mkdir(parents=True, exist_ok=True)


def redact(obj):
    if isinstance(obj, dict):
        return {k: ("<redacted>" if k in {"token", "key"} else redact(v)) for k, v in obj.items()}
    if isinstance(obj, list):
        return [redact(x) for x in obj]
    return obj


def main():
    result = {"base": BASE, "checks": []}
    with httpx.Client(timeout=120) as c:
        h = c.get(BASE + "/health")
        result["health"] = {"status": h.status_code, "body": redact(h.json())}
        r = c.post(BASE + "/v1/ai/chat", json={"messages": [{"role": "user", "content": "只回复：后端连通"}], "stream": False})
        result["checks"].append({"name": "ai_chat", "status": r.status_code, "body": r.json() if r.headers.get("content-type", "").startswith("application/json") else r.text[:200]})
        r = c.post(BASE + "/v1/sync/pair", json={"code": "123456", "name": "smoke"})
        pair = r.json()
        token = pair.get("token")
        result["checks"].append({"name": "pair", "status": r.status_code, "body": redact(pair)})
        if token:
            r = c.post(BASE + "/v1/sync/clipboard", json={"token": token, "items": [{"text": "smoke clipboard"}]})
            result["checks"].append({"name": "clipboard_put", "status": r.status_code, "body": redact(r.json())})
            r = c.get(BASE + "/v1/sync/clipboard", params={"token": token})
            result["checks"].append({"name": "clipboard_get", "status": r.status_code, "body": redact(r.json())})
            r = c.post(BASE + "/v1/sync/phrases", json={"token": token, "items": [{"text": "你好", "code": "nihao"}]})
            result["checks"].append({"name": "phrases", "status": r.status_code, "body": redact(r.json())})
        payload = b"wechat-input-clone smoke file\n"
        r = c.post(BASE + "/v1/transfer/upload", files={"file": ("smoke.txt", payload, "text/plain")})
        up = r.json()
        result["checks"].append({"name": "upload", "status": r.status_code, "body": up})
        if r.status_code == 200:
            r = c.get(BASE + f"/v1/transfer/{up['id']}")
            result["checks"].append({"name": "download", "status": r.status_code, "sha256_match": hashlib.sha256(r.content).hexdigest() == up["sha256"], "bytes": len(r.content)})
        r = c.post(BASE + "/v1/ai/polish", json={"text": "嗯 那个 我们 明天 下午 三点 开会 吧"})
        result["checks"].append({"name": "ai_polish", "status": r.status_code, "body": r.json() if r.headers.get("content-type", "").startswith("application/json") else r.text[:200]})
    (OUT / "smoke.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
