# MCP wiring for attendees

This folder contains a ready-to-copy MCP configuration for the microhack. The file lives under `.mcp\` intentionally; copy it to your host-specific location instead of committing `.vscode\mcp.json`.

## Azure MCP Server

Verified invocation:

```powershell
npx -y @azure/mcp@latest server start
```

VS Code users can also install the **Azure MCP Server** extension: `ms-azuretools.vscode-azure-mcp-server`. Sign in with Azure CLI or the VS Code Azure account flow before using Azure tools.

## GitHub MCP Server

GitHub provides a hosted remote MCP server:

```json
{
  "servers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/"
    }
  }
}
```

Copilot CLI includes the GitHub MCP server with read-only tools by default. Use `/mcp show github-mcp-server` in a Copilot CLI session to verify. For custom Copilot CLI configuration, use `~\.copilot\mcp-config.json` and the `mcpServers` shape from `.mcp\mcp.json`.

## Enable in VS Code

1. Copy `.mcp\mcp.json` to `.vscode\mcp.json`.
2. If your VS Code MCP host expects the `servers` root key, rename `mcpServers` to `servers`.
3. Open Copilot Chat Agent mode and start the Azure/GitHub servers.
4. Keep tokens in environment variables or VS Code secret prompts, never in source control.

## Local GitHub MCP fallback

If remote MCP is not available, use the public container image with `GITHUB_PERSONAL_ACCESS_TOKEN` stored in your environment:

```json
{
  "mcpServers": {
    "github-local": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "-e", "GITHUB_PERSONAL_ACCESS_TOKEN", "ghcr.io/github/github-mcp-server"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}"
      }
    }
  }
}
```
