"""Provider factory tests that never import real Agent Framework clients."""

from __future__ import annotations

from typing import Any, ClassVar

import migration_copilot.inference as inference
import pytest
from migration_copilot.inference import InferenceConfigurationError, ProviderConfig, get_chat_client


class DummyClient:
    """Captures constructor arguments from provider selection."""

    calls: ClassVar[list[dict[str, Any]]] = []

    def __init__(self, **kwargs: Any) -> None:
        self.kwargs = kwargs
        DummyClient.calls.append(kwargs)

    def as_agent(self, *, name: str, instructions: str, **kwargs: Any) -> object:
        return object()


@pytest.fixture(autouse=True)
def clear_calls(monkeypatch: pytest.MonkeyPatch) -> None:
    DummyClient.calls.clear()
    monkeypatch.setattr(inference, "_openai_client_class", lambda: DummyClient)
    monkeypatch.setattr(inference, "_foundry_client_class", lambda: DummyClient)
    monkeypatch.setattr(inference, "_default_credential", lambda: "credential")


def test_github_models_selection() -> None:
    client = get_chat_client(
        ProviderConfig(
            provider="github_models", github_token="ghp_x", github_model="openai/gpt-4o-mini"
        )
    )
    assert isinstance(client, DummyClient)
    assert DummyClient.calls[0]["base_url"] == inference.GITHUB_MODELS_BASE_URL
    assert DummyClient.calls[0]["model"] == "openai/gpt-4o-mini"


def test_azure_openai_key_selection() -> None:
    get_chat_client(
        ProviderConfig(
            provider="azure_openai",
            azure_openai_endpoint="https://example.openai.azure.com",
            model_deployment_name="gpt-4o-mini",
            azure_openai_api_key="key",
        )
    )
    assert DummyClient.calls[0]["azure_endpoint"] == "https://example.openai.azure.com"
    assert DummyClient.calls[0]["api_key"] == "key"


def test_azure_openai_aad_selection() -> None:
    get_chat_client(
        ProviderConfig(
            provider="azure_openai",
            azure_openai_endpoint="https://example.openai.azure.com",
            model_deployment_name="gpt-4o-mini",
        )
    )
    assert DummyClient.calls[0]["credential"] == "credential"


def test_foundry_selection() -> None:
    get_chat_client(
        ProviderConfig(
            provider="foundry",
            project_endpoint="https://example.services.ai.azure.com/api/projects/p",
            model_deployment_name="gpt-4o-mini",
        )
    )
    assert DummyClient.calls[0]["project_endpoint"].endswith("/p")
    assert DummyClient.calls[0]["model"] == "gpt-4o-mini"


def test_missing_env_message() -> None:
    with pytest.raises(InferenceConfigurationError, match="GITHUB_TOKEN"):
        get_chat_client(ProviderConfig(provider="github_models", github_model="openai/gpt-4o-mini"))
