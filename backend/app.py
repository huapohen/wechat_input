#!/usr/bin/env python3
"""WeType-clone replacement backend.

The original WeChat Input cloud is not usable. This service provides the
replaceable surface used by the Flutter/Android/iOS clients:

  /v1/ai/*        OpenAI-compatible DeepSeek proxy (server-side key only)
  /v1/asr         optional local ASR hook (device ASR is the default)
  /v1/sync/*      pairing, clipboard, phrases, settings
  /v1/transfer/*  file relay with SHA-256

No Tencent endpoint, token, certificate or private protocol is used.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import secrets
import sqlite3
import time
from pathlib import Path
from typing import Any

import httpx
from fastapi import FastAPI, File, Header, HTTPException, Query, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse, StreamingResponse
from pydantic import BaseModel, Field

ROOT = Path(__file__).resolve().parent
DATA = Path(os.environ.get("WETYPE_DATA_DIR", ROOT / "data"))
DATA.mkdir(parents=True, exist_ok=True)
DB = DATA / "wetype.db"
FILES = DATA / "files"
FILES.mkdir(parents=True, exist_ok=True)

BASE_URL = os.environ.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com").rstrip("/")
MODEL = os.environ.get("DEEPSEEK_MODEL", "deepseek-chat")
API_KEY = os.environ.get("DEEPSEEK_API_KEY", "").strip()
APP_TOKEN = os.environ.get("WETYPE_APP_TOKEN", "").strip()
ASR_PROVIDER = os.environ.get("WETYPE_ASR_PROVIDER", "device").strip()
MAX_UPLOAD = int(os.environ.get("WETYPE_MAX_UPLOAD", str(50 * 1024 * 1024)))

# Local-only fallback: the user's key file is never copied into the repo.
# The file may contain a base URL, a model label, and a bare sk-... key.
KEY_FILE = Path("/Users/lwblx/Documents/ds_api")
if KEY_FILE.exists():
    try:
        lines = [x.strip() for x in KEY_FILE.read_text(encoding="utf-8").splitlines() if x.strip()]
        for line in lines:
            if not API_KEY and line.startswith("sk-"):
                API_KEY = line
            if line.startswith("http") and os.environ.get("DEEPSEEK_BASE_URL") is None:
                BASE_URL = line.rstrip("/")
            m = re.match(r"^(?:模型|model)\s*[:：]\s*(.+)$", line, re.I)
            if m and os.environ.get("DEEPSEEK_MODEL") is None:
                MODEL = m.group(1).strip()
    except Exception:
        pass


def key_fingerprint() -> dict[str, Any]:
    if not API_KEY:
        return {"configured": False}
    return {
        "configured": True,
        "prefix": API_KEY[:6] + "…",
        "sha256_12": hashlib.sha256(API_KEY.encode()).hexdigest()[:12],
        "length": len(API_KEY),
    }


def db():
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    with db() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS devices(
              id INTEGER PRIMARY KEY, token TEXT UNIQUE, code TEXT, name TEXT,
              created REAL, last_seen REAL
            );
            CREATE TABLE IF NOT EXISTS clipboard(
              id INTEGER PRIMARY KEY, token TEXT, text TEXT, created REAL, sha256 TEXT
            );
            CREATE TABLE IF NOT EXISTS phrases(
              id INTEGER PRIMARY KEY, token TEXT, text TEXT, code TEXT, UNIQUE(token,text)
            );
            CREATE TABLE IF NOT EXISTS settings(
              token TEXT PRIMARY KEY, payload TEXT, updated REAL
            );
            CREATE TABLE IF NOT EXISTS transfers(
              id TEXT PRIMARY KEY, token TEXT, name TEXT, size INTEGER, sha256 TEXT,
              path TEXT, created REAL
            );
            """
        )


init_db()

app = FastAPI(title="WeType Clone Backend", version="1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class Message(BaseModel):
    role: str
    content: str


class ChatReq(BaseModel):
    messages: list[Message] = Field(default_factory=list)
    model: str | None = None
    stream: bool = False
    temperature: float = 0.7
    max_tokens: int = 1200


class TextReq(BaseModel):
    text: str
    mode: str = "default"
    source: str = "auto"
    target: str = "zh"
    style: str = "自然"
    count: int = 3


class PairReq(BaseModel):
    code: str
    name: str = "device"


class SyncReq(BaseModel):
    token: str
    items: list[dict[str, Any]] = Field(default_factory=list)


class PhraseItem(BaseModel):
    text: str
    code: str = ""


class PhraseReq(BaseModel):
    token: str
    items: list[PhraseItem] = Field(default_factory=list)


class SettingsReq(BaseModel):
    token: str
    payload: dict[str, Any] = Field(default_factory=dict)


def require_token(token: str | None):
    if not token:
        raise HTTPException(401, "missing token")
    with db() as conn:
        row = conn.execute("SELECT token FROM devices WHERE token=?", (token,)).fetchone()
    if not row:
        raise HTTPException(401, "unknown token")
    return token


def check_app_token(authorization: str | None):
    if not APP_TOKEN:
        return
    expected = "Bearer " + APP_TOKEN
    if authorization != expected:
        raise HTTPException(401, "app token required")


async def deepseek(payload: dict[str, Any]) -> dict[str, Any]:
    if not API_KEY:
        raise HTTPException(503, "DEEPSEEK_API_KEY is not configured")
    headers = {"Authorization": "Bearer " + API_KEY, "Content-Type": "application/json"}
    url = BASE_URL + "/chat/completions"
    async with httpx.AsyncClient(timeout=120) as client:
        r = await client.post(url, headers=headers, json=payload)
    if r.status_code >= 400:
        detail = r.text[:500]
        raise HTTPException(502, f"upstream {r.status_code}: {detail}")
    return r.json()


@app.get("/health")
async def health():
    return {"ok": True, "model": MODEL, "base_url": BASE_URL, "key": key_fingerprint(), "asr": ASR_PROVIDER}


@app.post("/v1/ai/chat")
async def chat(req: ChatReq, authorization: str | None = Header(default=None)):
    check_app_token(authorization)
    payload: dict[str, Any] = {
        "model": req.model or MODEL,
        "messages": [m.model_dump() for m in req.messages],
        "temperature": req.temperature,
        "max_tokens": req.max_tokens,
        "stream": req.stream,
    }
    if not req.stream:
        data = await deepseek(payload)
        text = data.get("choices", [{}])[0].get("message", {}).get("content", "")
        return {"text": text, "usage": data.get("usage"), "model": data.get("model", payload["model"])}

    if not API_KEY:
        raise HTTPException(503, "DEEPSEEK_API_KEY is not configured")

    async def gen():
        headers = {"Authorization": "Bearer " + API_KEY, "Content-Type": "application/json"}
        url = BASE_URL + "/chat/completions"
        async with httpx.AsyncClient(timeout=None) as client:
            async with client.stream("POST", url, headers=headers, json=payload) as r:
                if r.status_code >= 400:
                    body = (await r.aread())[:300].decode("utf-8", "ignore")
                    yield f"event: error\ndata: {json.dumps({'error': body})}\n\n"
                    return
                async for line in r.aiter_lines():
                    if not line:
                        continue
                    if line.startswith("data:"):
                        chunk = line[5:].strip()
                        if chunk == "[DONE]":
                            yield "event: done\ndata: {}\n\n"
                            break
                        try:
                            obj = json.loads(chunk)
                            delta = obj.get("choices", [{}])[0].get("delta", {}).get("content", "")
                            if delta:
                                yield f"data: {json.dumps({'text': delta}, ensure_ascii=False)}\n\n"
                        except Exception:
                            continue

    return StreamingResponse(gen(), media_type="text/event-stream")


PROMPTS = {
    "polish": "你是中文输入法的文字整理助手。保留事实与语气，删除口水词，补全标点，必要时分段；只输出整理后的文本。",
    "rewrite": "你是中文表达助手。按用户选择的语气改写，保留原意，不添加事实；只输出候选文本。",
    "translate": "你是翻译引擎。只输出译文，不解释。",
    "summary": "你是会议纪要助手。输出简洁摘要与要点列表，不虚构。",
}


@app.post("/v1/ai/polish")
async def polish(req: TextReq, authorization: str | None = Header(default=None)):
    check_app_token(authorization)
    data = await deepseek({
        "model": MODEL,
        "messages": [
            {"role": "system", "content": PROMPTS["polish"]},
            {"role": "user", "content": req.text},
        ],
        "temperature": 0.3,
        "max_tokens": 1600,
    })
    return {"text": data.get("choices", [{}])[0].get("message", {}).get("content", "").strip()}


@app.post("/v1/ai/rewrite")
async def rewrite(req: TextReq, authorization: str | None = Header(default=None)):
    check_app_token(authorization)
    data = await deepseek({
        "model": MODEL,
        "messages": [
            {"role": "system", "content": PROMPTS["rewrite"]},
            {"role": "user", "content": f"语气：{req.style}\n原文：{req.text}\n给出 {max(1,min(req.count,5))} 个候选，每行一个，不要编号。"},
        ],
        "temperature": 0.8,
        "max_tokens": 1200,
    })
    text = data.get("choices", [{}])[0].get("message", {}).get("content", "")
    candidates = [x.strip(" -•\t") for x in text.splitlines() if x.strip()]
    return {"candidates": candidates[: max(1, min(req.count, 5))]}


@app.post("/v1/ai/translate")
async def translate(req: TextReq, authorization: str | None = Header(default=None)):
    check_app_token(authorization)
    data = await deepseek({
        "model": MODEL,
        "messages": [
            {"role": "system", "content": PROMPTS["translate"]},
            {"role": "user", "content": f"从 {req.source} 翻译到 {req.target}：\n{req.text}"},
        ],
        "temperature": 0.2,
        "max_tokens": 1200,
    })
    return {"text": data.get("choices", [{}])[0].get("message", {}).get("content", "").strip()}


@app.post("/v1/ai/summary")
async def summary(req: TextReq, authorization: str | None = Header(default=None)):
    check_app_token(authorization)
    data = await deepseek({
        "model": MODEL,
        "messages": [
            {"role": "system", "content": PROMPTS["summary"]},
            {"role": "user", "content": req.text},
        ],
        "temperature": 0.2,
        "max_tokens": 1600,
    })
    text = data.get("choices", [{}])[0].get("message", {}).get("content", "").strip()
    return {"text": text, "summary": text.splitlines()[0] if text else "", "bullets": [x.strip("-• ") for x in text.splitlines()[1:] if x.strip()]}


@app.post("/v1/asr")
async def asr(audio: UploadFile = File(...), authorization: str | None = Header(default=None)):
    check_app_token(authorization)
    # Device ASR is the default. A local ASR provider can be plugged here.
    raise HTTPException(503, "ASR provider not configured; clients use device speech recognition")


@app.post("/v1/sync/pair")
async def pair(req: PairReq):
    code = "".join(ch for ch in req.code if ch.isdigit())[:6]
    if len(code) != 6:
        raise HTTPException(400, "6-digit code required")
    token = secrets.token_urlsafe(24)
    now = time.time()
    with db() as conn:
        conn.execute("INSERT INTO devices(token,code,name,created,last_seen) VALUES(?,?,?,?,?)", (token, code, req.name, now, now))
        peer = conn.execute("SELECT token,name FROM devices WHERE code=? AND token<>? ORDER BY created DESC LIMIT 1", (code, token)).fetchone()
    return {"token": token, "code": code, "peer": dict(peer) if peer else None}


@app.post("/v1/sync/clipboard")
async def clipboard(req: SyncReq):
    require_token(req.token)
    now = time.time()
    with db() as conn:
        for item in req.items[:50]:
            text = str(item.get("text", ""))[:20000]
            if not text:
                continue
            digest = hashlib.sha256(text.encode()).hexdigest()
            conn.execute("INSERT INTO clipboard(token,text,created,sha256) VALUES(?,?,?,?)", (req.token, text, now, digest))
        rows = conn.execute("SELECT text,created,sha256 FROM clipboard WHERE token=? ORDER BY created DESC LIMIT 50", (req.token,)).fetchall()
    return {"items": [dict(r) for r in rows]}


@app.get("/v1/sync/clipboard")
async def clipboard_list(token: str = Query(...)):
    require_token(token)
    with db() as conn:
        rows = conn.execute("SELECT text,created,sha256 FROM clipboard WHERE token=? ORDER BY created DESC LIMIT 50", (token,)).fetchall()
    return {"items": [dict(r) for r in rows]}


@app.post("/v1/sync/phrases")
async def phrases(req: PhraseReq):
    require_token(req.token)
    with db() as conn:
        for item in req.items[:200]:
            if item.text.strip():
                conn.execute("INSERT OR REPLACE INTO phrases(token,text,code) VALUES(?,?,?)", (req.token, item.text[:200], item.code[:40]))
        rows = conn.execute("SELECT text,code FROM phrases WHERE token=? ORDER BY id ASC", (req.token,)).fetchall()
    return {"items": [dict(r) for r in rows]}


@app.post("/v1/sync/settings")
async def put_settings(req: SettingsReq):
    require_token(req.token)
    with db() as conn:
        conn.execute("INSERT OR REPLACE INTO settings(token,payload,updated) VALUES(?,?,?)", (req.token, json.dumps(req.payload, ensure_ascii=False), time.time()))
    return {"ok": True}


@app.get("/v1/sync/settings")
async def get_settings(token: str = Query(...)):
    require_token(token)
    with db() as conn:
        row = conn.execute("SELECT payload,updated FROM settings WHERE token=?", (token,)).fetchone()
    return {"payload": json.loads(row["payload"]) if row else {}, "updated": row["updated"] if row else None}


@app.post("/v1/transfer/upload")
async def upload(file: UploadFile = File(...), token: str = Query(""), authorization: str | None = Header(default=None)):
    check_app_token(authorization)
    if token:
        require_token(token)
    ext = Path(file.filename or "file").suffix[:10]
    tid = secrets.token_hex(16)
    dest = FILES / (tid + ext)
    h = hashlib.sha256()
    size = 0
    with open(dest, "wb") as f:
        while chunk := await file.read(1024 * 1024):
            size += len(chunk)
            if size > MAX_UPLOAD:
                dest.unlink(missing_ok=True)
                raise HTTPException(413, "file too large")
            h.update(chunk)
            f.write(chunk)
    with db() as conn:
        conn.execute("INSERT INTO transfers(id,token,name,size,sha256,path,created) VALUES(?,?,?,?,?,?,?)",
                     (tid, token, file.filename or dest.name, size, h.hexdigest(), str(dest), time.time()))
    return {"id": tid, "name": file.filename, "size": size, "sha256": h.hexdigest()}


@app.get("/v1/transfer/list")
async def transfer_list(token: str = Query("")):
    if token:
        require_token(token)
        with db() as conn:
            rows = conn.execute("SELECT id,name,size,sha256,created FROM transfers WHERE token=? ORDER BY created DESC LIMIT 100", (token,)).fetchall()
    else:
        with db() as conn:
            rows = conn.execute("SELECT id,name,size,sha256,created FROM transfers ORDER BY created DESC LIMIT 100").fetchall()
    return {"items": [dict(r) for r in rows]}


@app.get("/v1/transfer/{tid}")
async def transfer_get(tid: str):
    with db() as conn:
        row = conn.execute("SELECT * FROM transfers WHERE id=?", (tid,)).fetchone()
    if not row:
        raise HTTPException(404, "not found")
    return FileResponse(row["path"], filename=row["name"])


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=os.environ.get("WETYPE_HOST", "0.0.0.0"), port=int(os.environ.get("WETYPE_PORT", "8787")))
