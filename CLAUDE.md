# Rush Hour Diner

A Roblox co-op restaurant tycoon, built entirely as code (Rojo + Luau).

- `docs/ORCHESTRATOR.md` covers the process: waves, agent rules and the acceptance checklist.
- `docs/GDD.md` is the product spec.
- `docs/ARCHITECTURE.md` covers module boundaries, public APIs, data flows and file ownership. **Read it before writing code.**
- Contracts live in `src/shared/Contracts/*` and are owned by the orchestrator. Never edit them as a sub-agent. Request changes in your report.

## Commands

- `tools/check.sh` runs StyLua, Selene, luau-lsp strict, Lune tests and `rojo build`, the same checks as CI. `tools/check.sh --fix` formats first.
- `lune run tools/test [filter]` runs only the unit tests in `tests/`.
- `rojo serve` live-syncs to Studio. Click Connect in the Rojo plugin.

## Rules

- Use `--!strict` everywhere.
- No magic numbers: they go in `src/shared/Config`. No raw colors: they go in `Config/Palette`.
- Logic and Config must stay free of Roblox globals so Lune can test them.
- The server is authoritative for everything. Validate every remote with `Server/Util/Guard`.
- Never commit secrets (API keys, cookies). Roblox IDs go in repo variables or `Config/Products`.
