from __future__ import annotations

import json
import os
import re
from collections import Counter
from io import BytesIO
from typing import Any
from zipfile import ZIP_DEFLATED, ZipFile

import requests


class AIUnavailableError(RuntimeError):
    pass


BUILTIN_AGENT_INSTRUCTIONS = {
    "einstein": "Tu es Einstein, l’assistant transversal d’ÉCRIN. Réponds avec curiosité, tact et clarté.",
    "coach": "Tu es un coach de travail bienveillant. Aide à clarifier un objectif et à choisir un prochain petit pas, sans jugement.",
    "memory": "Tu aides à organiser et comprendre la mémoire numérique. Distingue les faits fournis des suggestions et n’invente pas de documents consultés.",
    "writer": "Tu es un assistant de rédaction en français. Adapte le ton et la structure au besoin exprimé.",
    "vision": "Tu aides à décrire des images et des documents à partir des informations fournies. Signale les limites et ne prétends pas avoir vu un média absent.",
    "developer": "Tu es un assistant de développement. Explique les choix, préserve les données, propose des changements vérifiables et n’exécute pas de code.",
    "personal": "Tu es un assistant personnel. Aide à organiser les idées et tâches exprimées par l’utilisateur, sans prétendre être humain ni ressentir des émotions.",
}


def normalize_text(text: str) -> str:
    return re.sub(r"\s+", " ", text or "").strip()


def extract_keywords(text: str, limit: int = 10) -> list[str]:
    cleaned = re.sub(r"[^A-Za-zÀ-ÖØ-öø-ÿ\s-]", " ", text.lower())
    words = [
        w
        for w in cleaned.split()
        if len(w) > 3
        and w not in {"avec", "dans", "pour", "plus", "sans", "cette", "entre", "ayant", "avoir"}
    ]
    counts = Counter(words)
    return [word for word, _ in counts.most_common(limit)]


def build_summary(text: str) -> str:
    sentence = normalize_text(text)
    if not sentence:
        return "Aucune donnée détectée."
    words = sentence.split()
    if len(words) <= 25:
        return sentence
    return " ".join(words[:25]) + "..."


def _fallback_classification(text: str) -> dict[str, Any]:
    sample = (text or "").lower()
    tags: list[str] = []
    if any(k in sample for k in ["email", "contact", "telephone", "numéro", "adresse"]):
        tags.append("coordonnées")
    if any(k in sample for k in ["projet", "objectif", "livrable", "tâche", "fonctionnalité"]):
        tags.append("projet")
    if any(k in sample for k in ["client", "demande", "besoin", "contrat", "vente"]):
        tags.append("client")
    if any(k in sample for k in ["bug", "erreur", "incident", "correctif", "fix"]):
        tags.append("incident")
    if not tags:
        tags = ["général"]

    return {
        "category": tags[0],
        "tags": tags,
        "keywords": extract_keywords(text),
        "summary": build_summary(text),
    }


def _call_openai(text: str) -> dict[str, Any] | None:
    api_key = os.getenv("OPENAI_API_KEY")
    model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
    if not api_key:
        return None

    try:
        response = requests.post(
            "https://api.openai.com/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": model,
                "temperature": 0.3,
                "messages": [
                    {
                        "role": "system",
                        "content": (
                            "Tu es Ecrin, un assistant IA pour organiser l'information. "
                            "Retourne uniquement un objet JSON valide avec: "
                            "category, tags, keywords, summary. "
                            "category doit être un mot-clé court. tags est une liste de 2 à 5 termes. "
                            "keywords est une liste de 5 à 10 mots-clés. summary est un résumé clair en français."
                        ),
                    },
                    {"role": "user", "content": text},
                ],
            },
            timeout=30,
        )
        response.raise_for_status()
        payload = response.json()
        content = payload["choices"][0]["message"]["content"]
        parsed = json.loads(content)
        return {
            "category": str(parsed.get("category") or "général"),
            "tags": [str(tag) for tag in (parsed.get("tags") or ["général"])][:5],
            "keywords": [str(kw) for kw in (parsed.get("keywords") or [])][:10],
            "summary": str(parsed.get("summary") or build_summary(text)),
        }
    except Exception:
        return None


def _call_ollama(text: str) -> dict[str, Any] | None:
    base_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
    model = os.getenv("OLLAMA_MODEL", "llama3.1")
    if not base_url:
        return None

    try:
        response = requests.post(
            f"{base_url.rstrip('/')}/api/generate",
            json={
                "model": model,
                "stream": False,
                "prompt": (
                    "Tu es Ecrin, un assistant IA pour organiser l'information. "
                    "Retourne uniquement en JSON: {category, tags, keywords, summary}. "
                    "Le résumé doit être en français.\n\nTexte: "
                    f"{text}"
                ),
            },
            timeout=30,
        )
        response.raise_for_status()
        payload = response.json()
        content = payload.get("response", "")
        parsed = json.loads(content)
        return {
            "category": str(parsed.get("category") or "général"),
            "tags": [str(tag) for tag in (parsed.get("tags") or ["général"])][:5],
            "keywords": [str(kw) for kw in (parsed.get("keywords") or [])][:10],
            "summary": str(parsed.get("summary") or build_summary(text)),
        }
    except Exception:
        return None


def get_ai_backend() -> str:
    if os.getenv("OPENAI_API_KEY"):
        return "openai"
    if os.getenv("OLLAMA_MODEL") or os.getenv("OLLAMA_BASE_URL"):
        return "ollama"
    return "heuristic"


def get_ai_configuration() -> dict[str, Any]:
    backend = get_ai_backend()
    model = {
        "openai": os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
        "ollama": os.getenv("OLLAMA_MODEL", "llama3.1"),
        "heuristic": None,
    }[backend]
    return {
        "provider": backend,
        "model": model,
        "conversation": backend in {"openai", "ollama"},
        "project_generation": backend in {"openai", "ollama"},
        "provider_configured": backend in {"openai", "ollama"},
    }


def classify_content(text: str) -> dict[str, Any]:
    ai_result = _call_openai(text) or _call_ollama(text)
    if ai_result:
        ai_result["keywords"] = ai_result.get("keywords") or extract_keywords(text)
        ai_result["summary"] = ai_result.get("summary") or build_summary(text)
        ai_result["tags"] = ai_result.get("tags") or [ai_result.get("category", "général")]
        return ai_result
    return _fallback_classification(text)


def create_notice(title: str, content: str) -> dict[str, Any]:
    payload = classify_content(content)
    notice = {
        "title": (title or "Nouvelle notice").strip() or "Nouvelle notice",
        "summary": payload["summary"],
        "category": payload["category"],
        "tags": payload["tags"],
        "keywords": payload["keywords"],
        "content": content.strip(),
    }
    return notice


def _fallback_document(text: str, kind: str) -> dict[str, Any]:
    classification = _fallback_classification(text)
    if kind == "guide":
        content = (
            "## Objectif\n"
            f"{classification['summary']}\n\n"
            "## Étapes proposées\n"
            "1. Relire les informations disponibles et préciser le résultat attendu.\n"
            "2. Réunir les ressources et les personnes nécessaires.\n"
            "3. Réaliser l’action par étapes en vérifiant chaque résultat.\n"
            "4. Noter les points à suivre et confirmer que l’objectif est atteint.\n\n"
            "## À vérifier\n"
            "Les étapes ci-dessus sont un canevas général : adaptez-les aux informations "
            "et aux contraintes de la source."
        )
        title = f"Guide — {classification['category']}"
    else:
        content = (
            f"## Résumé\n{classification['summary']}\n\n"
            f"## Informations clés\n{', '.join(classification['keywords']) or 'Aucune information clé détectée.'}\n\n"
            "## Source\n"
            f"{normalize_text(text)}"
        )
        title = f"Notice — {classification['category']}"

    return {
        "title": title,
        "content": content,
        "summary": classification["summary"],
        "category": classification["category"],
        "tags": classification["tags"],
        "keywords": classification["keywords"],
    }


def _parse_generated_document(content: str, text: str, kind: str) -> dict[str, Any] | None:
    try:
        parsed = json.loads(content)
        if not isinstance(parsed, dict):
            return None
        title = str(parsed.get("title") or "").strip()
        body = str(parsed.get("content") or "").strip()
        if not title or not body:
            return None
        classification = _fallback_classification(text)
        return {
            "title": title,
            "content": body,
            "summary": str(parsed.get("summary") or classification["summary"]),
            "category": str(parsed.get("category") or classification["category"]),
            "tags": [str(tag) for tag in (parsed.get("tags") or classification["tags"])][:5],
            "keywords": [
                str(keyword)
                for keyword in (parsed.get("keywords") or classification["keywords"])
            ][:10],
        }
    except (json.JSONDecodeError, TypeError, ValueError):
        return None


def _call_openai_document(text: str, kind: str) -> dict[str, Any] | None:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return None
    label = "guide pratique" if kind == "guide" else "notice synthétique"
    try:
        response = requests.post(
            "https://api.openai.com/v1/chat/completions",
            headers={
                "Authorization": "Bearer " + api_key,
                "Content-Type": "application/json",
            },
            json={
                "model": os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
                "temperature": 0.3,
                "response_format": {"type": "json_object"},
                "messages": [
                    {
                        "role": "system",
                        "content": (
                            "Tu es Ecrin, assistant de rédaction en français. Crée un "
                            f"{label} à partir de la source. N'invente aucun fait; indique "
                            "clairement les étapes génériques ou informations manquantes. "
                            "Retourne un objet JSON avec title, content, summary, category, "
                            "tags (liste), keywords (liste)."
                        ),
                    },
                    {"role": "user", "content": text},
                ],
            },
            timeout=45,
        )
        response.raise_for_status()
        payload = response.json()
        content = payload["choices"][0]["message"]["content"]
        return _parse_generated_document(content, text, kind)
    except (requests.RequestException, KeyError, IndexError, TypeError, ValueError):
        return None


def _call_ollama_document(text: str, kind: str) -> dict[str, Any] | None:
    base_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
    label = "guide pratique" if kind == "guide" else "notice synthétique"
    if not base_url:
        return None
    try:
        response = requests.post(
            f"{base_url.rstrip('/')}/api/generate",
            json={
                "model": os.getenv("OLLAMA_MODEL", "llama3.1"),
                "stream": False,
                "format": "json",
                "prompt": (
                    "Tu es Ecrin, assistant de rédaction en français. Crée un "
                    f"{label} à partir de la source. N'invente aucun fait; indique "
                    "clairement les étapes génériques ou informations manquantes. "
                    "Retourne un objet JSON avec title, content, summary, category, "
                    "tags (liste), keywords (liste).\n\nSource:\n"
                    f"{text}"
                ),
            },
            timeout=45,
        )
        response.raise_for_status()
        payload = response.json()
        content = payload.get("response", "") if isinstance(payload, dict) else ""
        return _parse_generated_document(content, text, kind)
    except (requests.RequestException, KeyError, TypeError, ValueError):
        return None


def generate_document(text: str, kind: str) -> dict[str, Any]:
    generated = _call_openai_document(text, kind) or _call_ollama_document(text, kind)
    return generated or _fallback_document(text, kind)


def answer_question(
    question: str,
    *,
    agent_id: str = "einstein",
    instructions: str = "",
    history: list[dict[str, str]] | None = None,
) -> str:
    if len(question) > 12000 or len(instructions) > 4000:
        raise AIUnavailableError("La demande ou les consignes dépassent la limite autorisée.")
    if not re.fullmatch(r"[a-z0-9-]{1,48}", agent_id):
        raise AIUnavailableError("L’identifiant de l’agent est invalide.")
    recent_history = (history or [])[-20:]
    if any(
        turn.get("role") not in {"user", "assistant"}
        or len(turn.get("content", "")) > 12000
        for turn in recent_history
    ):
        raise AIUnavailableError("L’historique de conversation est invalide.")
    role = BUILTIN_AGENT_INSTRUCTIONS.get(
        agent_id,
        "Tu es un agent personnalisé de l’atelier ÉCRIN. Respecte les consignes de rôle fournies.",
    )
    if instructions.strip():
        role = f"{role}\n\nConsignes de l’utilisateur :\n{instructions.strip()}"

    if os.getenv("OPENAI_API_KEY"):
        url = "https://api.openai.com/v1/chat/completions"
        headers = {
            "Authorization": "Bearer " + os.environ["OPENAI_API_KEY"],
            "Content-Type": "application/json",
        }
        payload = {
            "model": os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
            "temperature": 0.4,
            "messages": [
                {
                    "role": "system",
                    "content": (
                        f"{role}\nRéponds en français, de façon claire et utile. "
                        "N’invente pas de faits; précise les limites ou les informations "
                        "manquantes. Tu ne disposes d’aucun outil d’exécution."
                    ),
                },
                *[
                    {"role": turn["role"], "content": turn["content"]}
                    for turn in recent_history
                ],
                {"role": "user", "content": question},
            ],
        }
        try:
            response = requests.post(url, headers=headers, json=payload, timeout=45)
            response.raise_for_status()
            content = response.json()["choices"][0]["message"]["content"]
            if not isinstance(content, str):
                raise ValueError("Le fournisseur IA a renvoyé un contenu invalide.")
            answer = content.strip()
        except (requests.RequestException, KeyError, IndexError, TypeError, ValueError) as error:
            raise AIUnavailableError("Le fournisseur IA n’a pas pu répondre.") from error
    elif os.getenv("OLLAMA_MODEL") or os.getenv("OLLAMA_BASE_URL"):
        base_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434").rstrip("/")
        try:
            response = requests.post(
                f"{base_url}/api/generate",
                json={
                    "model": os.getenv("OLLAMA_MODEL", "llama3.1"),
                    "stream": False,
                    "prompt": (
                        f"{role}\nRéponds en français, de façon claire et utile. "
                        "N’invente pas de faits; précise les limites ou les informations "
                        "manquantes. Tu ne disposes d’aucun outil d’exécution.\n\n"
                        + "".join(
                            f"{turn['role']} : {turn['content']}\n"
                            for turn in recent_history
                        )
                        + f"user : {question}"
                    ),
                },
                timeout=45,
            )
            response.raise_for_status()
            content = response.json().get("response", "")
            answer = content.strip() if isinstance(content, str) else ""
        except (requests.RequestException, KeyError, TypeError, ValueError) as error:
            raise AIUnavailableError("Le fournisseur IA n’a pas pu répondre.") from error
    else:
        raise AIUnavailableError("Configurez OpenAI ou Ollama sur le serveur pour utiliser Einstein.")

    if not answer:
        raise AIUnavailableError("Le fournisseur IA a renvoyé une réponse vide.")
    return answer


def generate_project_archive(description: str, stack: str) -> bytes:
    if len(description) > 10000:
        raise AIUnavailableError("La description du projet dépasse la limite autorisée.")
    if stack not in {"swiftui", "web"}:
        raise AIUnavailableError("Cette technologie n’est pas encore prise en charge.")

    if os.getenv("OPENAI_API_KEY"):
        headers = {
            "Authorization": "Bearer " + os.environ["OPENAI_API_KEY"],
            "Content-Type": "application/json",
        }
        try:
            response = requests.post(
                "https://api.openai.com/v1/chat/completions",
                headers=headers,
                json={
                    "model": os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
                    "temperature": 0.2,
                    "response_format": {"type": "json_object"},
                    "messages": [
                        {
                            "role": "system",
                            "content": (
                                "Génère le squelette textuel d’un petit projet logiciel conforme à la demande. "
                                "Retourne un objet JSON avec une propriété files, tableau de 1 à 30 objets "
                                "{path, content}. Chaque fichier est du texte source ou documentation. "
                                "N’inclus ni binaire, ni secret, ni commande d’installation ou script destructif. "
                                "N’exécute rien. Les chemins doivent être relatifs."
                            ),
                        },
                        {
                            "role": "user",
                            "content": f"Technologie: {stack}\nDescription: {description}",
                        },
                    ],
                },
                timeout=90,
            )
            response.raise_for_status()
            payload = response.json()
            generated = payload["choices"][0]["message"]["content"]
            files = json.loads(generated)["files"]
        except (requests.RequestException, json.JSONDecodeError, KeyError, IndexError, TypeError) as error:
            raise AIUnavailableError("La génération du projet a renvoyé un format invalide.") from error
    elif os.getenv("OLLAMA_MODEL") or os.getenv("OLLAMA_BASE_URL"):
        base_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434").rstrip("/")
        try:
            response = requests.post(
                f"{base_url}/api/generate",
                json={
                    "model": os.getenv("OLLAMA_MODEL", "llama3.1"),
                    "stream": False,
                    "format": "json",
                    "prompt": (
                        "Génère le squelette textuel d’un petit projet logiciel conforme à la demande. "
                        "Retourne un objet JSON avec une propriété files, tableau de 1 à 30 objets "
                        "{path, content}. Chaque fichier est du texte source ou documentation. "
                        "N’inclus ni binaire, ni secret, ni commande ou script destructif. N’exécute rien. "
                        "Les chemins doivent être relatifs.\n"
                        f"Technologie: {stack}\nDescription: {description}"
                    ),
                },
                timeout=90,
            )
            response.raise_for_status()
            payload = response.json()
            generated = payload.get("response", "") if isinstance(payload, dict) else ""
            files = json.loads(generated)["files"]
        except (requests.RequestException, json.JSONDecodeError, KeyError, TypeError) as error:
            raise AIUnavailableError("La génération du projet a renvoyé un format invalide.") from error
    else:
        raise AIUnavailableError("Configurez OpenAI ou Ollama sur le serveur pour générer un projet.")

    if not isinstance(files, list) or not 1 <= len(files) <= 30:
        raise AIUnavailableError("Le fournisseur a renvoyé un nombre de fichiers invalide.")

    archive = BytesIO()
    total_size = 0
    seen_paths: set[str] = set()
    try:
        with ZipFile(archive, "w", ZIP_DEFLATED) as project_zip:
            for entry in files:
                if not isinstance(entry, dict):
                    raise AIUnavailableError("Le fournisseur a renvoyé un fichier invalide.")
                path = entry.get("path")
                content = entry.get("content")
                if (
                    not isinstance(path, str)
                    or not isinstance(content, str)
                    or not path
                    or "\\" in path
                    or path.startswith("/")
                    or any(part in {"", ".", ".."} for part in path.split("/"))
                    or re.match(r"^[A-Za-z]:", path)
                ):
                    raise AIUnavailableError("Le projet contient un chemin de fichier invalide.")
                if path in seen_paths:
                    raise AIUnavailableError("Le projet contient des chemins de fichier en double.")
                if len(content.encode("utf-8")) > 100_000:
                    raise AIUnavailableError("Un fichier généré dépasse la taille maximale.")
                seen_paths.add(path)
                total_size += len(content.encode("utf-8"))
                if total_size > 1_000_000:
                    raise AIUnavailableError("Le projet généré dépasse la taille maximale.")
                project_zip.writestr(path, content)
    except (OSError, ValueError) as error:
        raise AIUnavailableError("Impossible de préparer l’archive du projet.") from error
    return archive.getvalue()
