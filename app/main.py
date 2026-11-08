from __future__ import annotations

import hmac
import os
from typing import Any, Literal

from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from fastapi.responses import Response
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from app.services import (
    AIUnavailableError,
    answer_question,
    classify_content,
    create_notice,
    extract_keywords,
    generate_project_archive,
    generate_document,
    get_ai_configuration,
    get_ai_backend,
)

app = FastAPI(title="Ecrin", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory="static"), name="static")

notes: list[dict[str, Any]] = []


class TextInput(BaseModel):
    text: str = Field(..., min_length=1, max_length=12000)


class ConversationTurn(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(..., min_length=1, max_length=12000)


class AskPayload(BaseModel):
    text: str = Field(..., min_length=1, max_length=12000)
    agent_id: str = Field(default="einstein", min_length=1, max_length=48, pattern=r"^[a-z0-9-]+$")
    instructions: str = Field(default="", max_length=4000)
    history: list[ConversationTurn] = Field(default_factory=list, max_length=20)


class ProjectPayload(BaseModel):
    description: str = Field(..., min_length=1, max_length=10000)
    stack: Literal["swiftui", "web"] = "swiftui"


class NotePayload(BaseModel):
    title: str = Field(default="Nouvelle notice")
    content: str = Field(..., min_length=1)


class GeneratePayload(BaseModel):
    text: str = Field(..., min_length=1)
    kind: Literal["notice", "guide"]


@app.get("/")
async def index() -> HTMLResponse:
    from pathlib import Path

    return HTMLResponse(Path("static/index.html").read_text(encoding="utf-8"))


@app.get("/api/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "ecrin", "ai_backend": get_ai_backend()}


@app.get("/api/ai/config")
async def ai_configuration() -> dict[str, Any]:
    return {
        **get_ai_configuration(),
        "authentication_required": bool(os.getenv("ECRIN_API_TOKEN")),
    }


def require_ai_access(authorization: str | None = Header(default=None)) -> None:
    expected_token = os.getenv("ECRIN_API_TOKEN")
    if not expected_token:
        raise HTTPException(
            status_code=503,
            detail="Configurez ECRIN_API_TOKEN sur le serveur pour sécuriser les fonctions IA.",
        )
    scheme, separator, supplied_token = (authorization or "").partition(" ")
    if (
        not separator
        or scheme.lower() != "bearer"
        or not hmac.compare_digest(supplied_token, expected_token)
    ):
        raise HTTPException(status_code=401, detail="Authentification ÉCRIN requise.")


@app.get("/api/notes")
async def get_notes() -> dict[str, list[dict[str, Any]]]:
    return {"items": notes}


@app.post("/api/notes")
async def add_note(payload: NotePayload) -> dict[str, Any]:
    notice = create_notice(payload.title, payload.content)
    notes.insert(0, notice)
    return {"message": "notice enregistrée", "item": notice}


@app.post("/api/scan")
async def scan_text(payload: TextInput) -> dict[str, Any]:
    classification = classify_content(payload.text)
    return {
        "status": "ok",
        "keywords": classification["keywords"],
        "summary": classification["summary"],
        "category": classification["category"],
        "tags": classification["tags"],
        "extracted": extract_keywords(payload.text),
    }


@app.post("/api/classify")
async def classify_text(payload: TextInput) -> dict[str, Any]:
    return {
        "status": "ok",
        **classify_content(payload.text),
    }


@app.post("/api/generate")
async def generate_text(payload: GeneratePayload) -> dict[str, Any]:
    return {
        "status": "ok",
        **generate_document(payload.text, payload.kind),
    }


@app.post("/api/ask")
async def ask_question(
    payload: AskPayload,
    _authorized: None = Depends(require_ai_access),
) -> dict[str, str]:
    try:
        answer = answer_question(
            payload.text,
            agent_id=payload.agent_id,
            instructions=payload.instructions,
            history=[turn.model_dump() for turn in payload.history],
        )
        return {"status": "ok", "answer": answer, "provider": get_ai_backend()}
    except AIUnavailableError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error


@app.post("/api/projects/generate")
async def generate_project(
    payload: ProjectPayload,
    _authorized: None = Depends(require_ai_access),
) -> Response:
    try:
        archive = generate_project_archive(payload.description, payload.stack)
    except AIUnavailableError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error
    return Response(
        content=archive,
        media_type="application/zip",
        headers={"Content-Disposition": 'attachment; filename="ecrin-projet.zip"'},
    )


@app.get("/ui")
async def ui() -> HTMLResponse:
    from pathlib import Path

    return HTMLResponse(Path("static/index.html").read_text(encoding="utf-8"))
