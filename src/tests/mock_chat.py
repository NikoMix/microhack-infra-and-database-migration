"""Offline Agent Framework-compatible chat client for tests."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class MockAgentResult:
    """Canned agent result."""

    text: str


class MockAgent:
    """Minimal async agent surface."""

    def __init__(self, name: str, response: str) -> None:
        self.name = name
        self._response = response

    async def run(self, prompt: str) -> MockAgentResult:
        return MockAgentResult(text=f"{self._response} ({self.name}: {prompt[:24]})")


class MockChatClient:
    """Test double implementing the same as_agent surface as Agent Framework clients."""

    def __init__(self, response: str = "mock advisory") -> None:
        self.response = response
        self.agent_names: list[str] = []

    def as_agent(self, *, name: str, instructions: str, **kwargs: object) -> MockAgent:
        self.agent_names.append(name)
        return MockAgent(name=name, response=self.response)
