# Release Prep (v0.2.0)

This runbook captures:
1. final commit grouping
2. release command sequence
3. quick verification checkpoints

## Proposed version
- **v0.2.0** (minor bump)

Rationale: metadata/dedupe/diagnostics surface additions and adapter contract expansion.

## Commit grouping plan

> Note: `CLIParser.swift`, `Commands.swift`, `README.md`, and `SPEC.md` contain changes from multiple phases.
> Use `git add -p` for those files to keep commit boundaries clean.

### Commit 1 — UX reliability: menu/settings + click path unification
**Message**
- `feat(ui): close menu before opening settings and unify notification click dismissal path`

**Primary files**
- `Sources/MungMung/UI/MenuBarContentView.swift`
- `Sources/MungMung/MungMungApp.swift`

### Commit 2 — Metadata-first contract + dedupe semantics
**Message**
- `feat(contract): add metadata fields and dedupe-key replacement semantics`

**Primary files**
- `Sources/MungMung/Models/Alert.swift`
- `Sources/MungMung/Services/AlertStore.swift`
- `Sources/MungMung/CLI/CLIParser.swift` *(metadata/dedupe hunks)*
- `Sources/MungMung/CLI/Commands.swift` *(metadata/dedupe hunks)*
- `Tests/MungMungTests/AlertTests.swift`
- `Tests/MungMungTests/AlertStoreTests.swift`
- `Tests/MungMungTests/CLIParserTests.swift` *(metadata/dedupe hunks)*
- `Tests/MungMungTests/CommandsTests.swift` *(metadata/dedupe hunks)*
- `Tests/MungMungTests/CLIIntegrationTests.swift` *(metadata/dedupe reference hunks)*

### Commit 3 — Action execution reliability
**Message**
- `feat(actions): add deterministic on_click shell context and debug controls`

**Primary files**
- `Sources/MungMung/Services/ShellHelper.swift`
- `Tests/MungMungTests/ShellHelperTests.swift`
- `Sources/MungMung/Services/NotificationManager.swift` *(runtime/hardening hunks)*
- `Tests/MungMungTests/NotificationManagerTests.swift` *(matching hunks)*

### Commit 4 — Observability + hardening
**Message**
- `feat(observability): add doctor command, lifecycle diagnostics, and release verification target`

**Primary files**
- `Sources/MungMung/CLI/CLIParser.swift` *(`doctor` routing hunks)*
- `Sources/MungMung/CLI/Commands.swift` *(`doctor`/lifecycle logging hunks)*
- `Makefile`
- `Tests/MungMungTests/CLIParserTests.swift` *(`doctor` parser test)*
- `Tests/MungMungTests/CommandsTests.swift` *(`doctor` command tests)*
- `Tests/MungMungTests/CLIIntegrationTests.swift` *(`doctor` integration tests)*

### Commit 5 — Docs + planning artifacts
**Message**
- `docs: finalize adapter contract, diagnostics docs, and phase completion artifacts`

**Primary files**
- `README.md`
- `SPEC.md`
- `CHANGELOG.md`
- `plan/mung-notify-platform/**`

## Suggested staging flow (patch mode)

```bash
# inspect
git status

# commit 1
git add Sources/MungMung/UI/MenuBarContentView.swift Sources/MungMung/MungMungApp.swift
git commit -m "feat(ui): close menu before opening settings and unify notification click dismissal path"

# commit 2 (use patch mode for shared files)
git add Sources/MungMung/Models/Alert.swift Sources/MungMung/Services/AlertStore.swift
git add -p Sources/MungMung/CLI/CLIParser.swift Sources/MungMung/CLI/Commands.swift
git add Tests/MungMungTests/AlertTests.swift Tests/MungMungTests/AlertStoreTests.swift
git add -p Tests/MungMungTests/CLIParserTests.swift Tests/MungMungTests/CommandsTests.swift Tests/MungMungTests/CLIIntegrationTests.swift
git commit -m "feat(contract): add metadata fields and dedupe-key replacement semantics"

# commit 3
git add Sources/MungMung/Services/ShellHelper.swift Tests/MungMungTests/ShellHelperTests.swift
git add -p Sources/MungMung/Services/NotificationManager.swift Tests/MungMungTests/NotificationManagerTests.swift
git commit -m "feat(actions): add deterministic on_click shell context and debug controls"

# commit 4
git add Makefile
git add -p Sources/MungMung/CLI/CLIParser.swift Sources/MungMung/CLI/Commands.swift
git add -p Tests/MungMungTests/CLIParserTests.swift Tests/MungMungTests/CommandsTests.swift Tests/MungMungTests/CLIIntegrationTests.swift
git commit -m "feat(observability): add doctor command, lifecycle diagnostics, and release verification target"

# commit 5
git add README.md SPEC.md CHANGELOG.md plan/mung-notify-platform
git commit -m "docs: finalize adapter contract, diagnostics docs, and phase completion artifacts"
```

## Release command sequence

```bash
# 0) clean + sync
git checkout main
git pull --ff-only

# 1) final verification
make verify-release

# 2) pick version
export VERSION=0.2.0

# 3) create annotated tag
git tag -a "v${VERSION}" -m "v${VERSION}"

# 4) push commits + tag
git push origin main
git push origin "v${VERSION}"

# 5) build release artifacts
make release VERSION="${VERSION}"
```

## Quick sign-off checklist
- [ ] `git status` is clean
- [ ] `make verify-release` passes
- [ ] `CHANGELOG.md` is final for `v0.2.0`
- [ ] tag `v0.2.0` exists locally and on remote
- [ ] release artifacts generated under `dist/`
