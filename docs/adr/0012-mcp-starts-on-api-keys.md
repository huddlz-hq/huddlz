# MCP starts on API keys; OAuth comes later

huddlz serves agents one Streamable HTTP MCP endpoint at `/mcp`, built on Ash AI, and for now it accepts the same bearer credentials as the JSON API: an API key the person creates on their API keys page, or a JWT from the API sign-in. Every tool, discovery included, needs a signed-in person, so results follow their home search location and the same visibility rules as the website. What an agent does is that person using huddlz: nothing records it separately, and revoking the key or suspending the account ends it.

OAuth was the first plan (#517), but the OAuth server library requires the Ash Authentication 5.0 release candidate, which would have moved everyone's sign-in onto prerelease code. The clients that can use a pasted key (Claude Code, Codex CLI and other local agents) get working tools now; hosted connectors such as Claude.ai and ChatGPT, which only accept OAuth, wait for #639.

## Considered options

- **OAuth from the start** (#517). Deferred: it needs the prerelease authentication stack and its own security review, and the tools do not depend on it.
- **A separate, MCP-only credential.** Rejected for now: API keys already exist, are revocable and expire; scoping a key to MCP can come later with OAuth scopes.

## Consequences

An API key acts as the whole account, so a key given to an agent can do anything the JSON API allows, not only what the MCP tools offer. The setup guide says so. When OAuth lands it becomes a second way to put the same person behind `/mcp`; the tools do not change.
