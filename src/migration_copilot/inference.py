"""Modular inference provider factory for Microsoft Agent Framework clients."""

from __future__ import annotations

import os
from dataclasses import dataclass
from importlib import import_module
from typing import Any, Literal, Protocol, cast

from dotenv import load_dotenv

ProviderName = Literal["foundry", "azure_openai", "github_models"]
GITHUB_MODELS_BASE_URL = "https://models.github.ai/inference"


class InferenceConfigurationError(RuntimeError):
    """Raised when the selected inference provider is not configured."""


class ChatClientProtocol(Protocol):
    """Minimal surface shared by Agent Framework chat clients and test doubles."""

    def as_agent(self, *, name: str, instructions: str, **kwargs: Any) -> Any:
        """Create an Agent Framework-compatible agent."""
        ...


@dataclass(frozen=True)
class ProviderConfig:
    """Resolved provider configuration from environment variables."""

    provider: ProviderName
    project_endpoint: str | None = None
    model_deployment_name: str | None = None
    azure_openai_endpoint: str | None = None
    azure_openai_api_key: str | None = None
    azure_openai_api_version: str | None = None
    github_token: str | None = None
    github_model: str | None = None

    @classmethod
    def from_env(cls) -> ProviderConfig:
        """Build provider configuration from environment variables."""
        load_dotenv()
        provider_raw = os.getenv("INFERENCE_PROVIDER", "github_models").strip().lower()
        if provider_raw not in {"foundry", "azure_openai", "github_models"}:
            raise InferenceConfigurationError(
                "INFERENCE_PROVIDER must be one of: foundry, azure_openai, github_models."
            )
        provider = cast(ProviderName, provider_raw)
        return cls(
            provider=provider,
            project_endpoint=os.getenv("AZURE_AI_PROJECT_ENDPOINT"),
            model_deployment_name=os.getenv("AZURE_AI_MODEL_DEPLOYMENT_NAME")
            or os.getenv("AZURE_OPENAI_CHAT_DEPLOYMENT_NAME"),
            azure_openai_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
            azure_openai_api_key=os.getenv("AZURE_OPENAI_API_KEY"),
            azure_openai_api_version=os.getenv("AZURE_OPENAI_API_VERSION"),
            github_token=os.getenv("GITHUB_TOKEN"),
            github_model=os.getenv("GITHUB_MODELS_MODEL"),
        )


def _missing(*names: str) -> InferenceConfigurationError:
    return InferenceConfigurationError(
        f"Missing required environment variable(s): {', '.join(names)}"
    )


def _default_credential() -> Any:
    try:
        from azure.identity.aio import DefaultAzureCredential
    except ImportError as exc:  # pragma: no cover - install-time guard
        raise InferenceConfigurationError(
            "azure-identity is required for Microsoft Entra authentication."
        ) from exc
    return DefaultAzureCredential()


def _openai_client_class() -> type[Any]:
    try:
        from agent_framework.openai import OpenAIChatClient
    except ImportError as exc:  # pragma: no cover - install-time guard
        raise InferenceConfigurationError(
            "agent-framework OpenAI provider is unavailable. Install with `pip install -e .`."
        ) from exc
    return OpenAIChatClient


def _foundry_client_class() -> type[Any]:
    try:
        from agent_framework.foundry import FoundryChatClient
    except ImportError as foundry_exc:  # pragma: no cover - compatibility guard
        try:
            azure_module = import_module("agent_framework.azure")
            legacy_name = "AzureAIAgentClient"
            legacy_client = getattr(azure_module, legacy_name)
        except (AttributeError, ImportError) as azure_exc:
            raise InferenceConfigurationError(
                "Foundry provider is unavailable. Current docs use "
                "agent_framework.foundry.FoundryChatClient."
            ) from azure_exc
        if foundry_exc:
            return cast(type[Any], legacy_client)
    return cast(type[Any], FoundryChatClient)


def _instantiate_openai(
    client_class: type[Any], *, model: str, **kwargs: Any
) -> ChatClientProtocol:
    try:
        return cast(ChatClientProtocol, client_class(model=model, **kwargs))
    except TypeError:
        return cast(ChatClientProtocol, client_class(model_id=model, **kwargs))


def get_chat_client(config: ProviderConfig | None = None) -> ChatClientProtocol:
    """Return a configured Microsoft Agent Framework chat client.

    The public-preview API changed after early `AzureOpenAIChatClient` and
    `AzureAIAgentClient` examples: current Python docs use `FoundryChatClient`
    for Foundry projects and `OpenAIChatClient` with explicit Azure routing for
    Azure OpenAI.
    """
    resolved = config or ProviderConfig.from_env()
    if resolved.provider == "foundry":
        if not resolved.project_endpoint:
            raise _missing("AZURE_AI_PROJECT_ENDPOINT")
        if not resolved.model_deployment_name:
            raise _missing("AZURE_AI_MODEL_DEPLOYMENT_NAME")
        client_class = _foundry_client_class()
        try:
            return cast(
                ChatClientProtocol,
                client_class(
                    project_endpoint=resolved.project_endpoint,
                    model=resolved.model_deployment_name,
                    credential=_default_credential(),
                ),
            )
        except TypeError:
            return cast(
                ChatClientProtocol,
                client_class(
                    project_endpoint=resolved.project_endpoint,
                    model_deployment_name=resolved.model_deployment_name,
                    credential=_default_credential(),
                ),
            )

    if resolved.provider == "azure_openai":
        if not resolved.azure_openai_endpoint:
            raise _missing("AZURE_OPENAI_ENDPOINT")
        if not resolved.model_deployment_name:
            raise _missing("AZURE_OPENAI_CHAT_DEPLOYMENT_NAME")
        kwargs: dict[str, Any] = {
            "azure_endpoint": resolved.azure_openai_endpoint,
            "api_version": resolved.azure_openai_api_version,
        }
        if resolved.azure_openai_api_key:
            kwargs["api_key"] = resolved.azure_openai_api_key
        else:
            kwargs["credential"] = _default_credential()
        return _instantiate_openai(
            _openai_client_class(), model=resolved.model_deployment_name, **kwargs
        )

    if not resolved.github_token:
        raise _missing("GITHUB_TOKEN")
    if not resolved.github_model:
        raise _missing("GITHUB_MODELS_MODEL")
    return _instantiate_openai(
        _openai_client_class(),
        model=resolved.github_model,
        base_url=GITHUB_MODELS_BASE_URL,
        api_key=resolved.github_token,
    )
