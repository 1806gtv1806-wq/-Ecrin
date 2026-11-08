import io
import os
import unittest
import zipfile
from unittest.mock import Mock, patch

from fastapi.testclient import TestClient

from app.main import app
from app.services import AIUnavailableError, answer_question, generate_project_archive


class AIWorkshopTests(unittest.TestCase):
    def test_agent_prompt_and_conversation_history_reach_provider(self) -> None:
        response = Mock()
        response.json.return_value = {
            "choices": [{"message": {"content": "Faisons un premier petit pas."}}]
        }
        with patch.dict(os.environ, {"OPENAI_API_KEY": "test-key"}, clear=True):
            with patch("app.services.requests.post", return_value=response) as post:
                answer = answer_question(
                    "Que faire ensuite ?",
                    agent_id="coach",
                    instructions="Reste concis.",
                    history=[{"role": "user", "content": "Je prépare un projet."}],
                )

        self.assertEqual(answer, "Faisons un premier petit pas.")
        messages = post.call_args.kwargs["json"]["messages"]
        self.assertIn("coach de travail", messages[0]["content"])
        self.assertEqual(messages[1]["content"], "Je prépare un projet.")
        self.assertIn("Reste concis.", messages[0]["content"])

    def test_project_archive_contains_only_validated_text_files(self) -> None:
        response = Mock()
        response.json.return_value = {
            "choices": [
                {
                    "message": {
                        "content": '{"files":[{"path":"Sources/App.swift","content":"import SwiftUI\\n"}]}'
                    }
                }
            ]
        }
        with patch.dict(os.environ, {"OPENAI_API_KEY": "test-key"}, clear=True):
            with patch("app.services.requests.post", return_value=response):
                archive_data = generate_project_archive("Une application de notes", "swiftui")

        with zipfile.ZipFile(io.BytesIO(archive_data)) as archive:
            self.assertEqual(archive.namelist(), ["Sources/App.swift"])
            self.assertEqual(archive.read("Sources/App.swift"), b"import SwiftUI\n")

    def test_project_archive_rejects_path_traversal(self) -> None:
        response = Mock()
        response.json.return_value = {
            "choices": [{"message": {"content": '{"files":[{"path":"../outside.txt","content":"x"}]}'}}]
        }
        with patch.dict(os.environ, {"OPENAI_API_KEY": "test-key"}, clear=True):
            with patch("app.services.requests.post", return_value=response):
                with self.assertRaises(AIUnavailableError):
                    generate_project_archive("Une application", "web")

    def test_ask_endpoint_requires_authentication(self) -> None:
        with patch.dict(os.environ, {"ECRIN_API_TOKEN": "test-token"}, clear=True):
            with TestClient(app) as client:
                response = client.post("/api/ask", json={"text": "Bonjour"})

        self.assertEqual(response.status_code, 401)
        self.assertIn("Authentification ÉCRIN requise", response.json()["detail"])

    def test_ask_endpoint_reports_unconfigured_provider(self) -> None:
        with patch.dict(
            os.environ,
            {"ECRIN_API_TOKEN": "test-token"},
            clear=True,
        ):
            with TestClient(app) as client:
                response = client.post(
                    "/api/ask",
                    json={"text": "Bonjour"},
                    headers={"Authorization": "Bearer test-token"},
                )

        self.assertEqual(response.status_code, 503)
        self.assertIn("Configurez OpenAI ou Ollama", response.json()["detail"])

    def test_project_endpoint_returns_zip_archive(self) -> None:
        with patch.dict(os.environ, {"ECRIN_API_TOKEN": "test-token"}, clear=True):
            with patch("app.main.generate_project_archive", return_value=b"PK\x03\x04test"):
                with TestClient(app) as client:
                    response = client.post(
                        "/api/projects/generate",
                        json={"description": "Une app", "stack": "swiftui"},
                        headers={"Authorization": "Bearer test-token"},
                    )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers["content-type"], "application/zip")
        self.assertIn('filename="ecrin-projet.zip"', response.headers["content-disposition"])

    def test_project_endpoint_rejects_invalid_token(self) -> None:
        with patch.dict(os.environ, {"ECRIN_API_TOKEN": "test-token"}, clear=True):
            with TestClient(app) as client:
                response = client.post(
                    "/api/projects/generate",
                    json={"description": "Une app", "stack": "swiftui"},
                    headers={"Authorization": "Bearer incorrect"},
                )

        self.assertEqual(response.status_code, 401)


if __name__ == "__main__":
    unittest.main()
