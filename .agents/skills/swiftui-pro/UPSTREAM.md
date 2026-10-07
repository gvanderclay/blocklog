# Upstream

- Source: https://github.com/twostraws/SwiftUI-Agent-Skill, directory `swiftui-pro/`
- Commit: f9800713b24580bc444931949aad4519128605e8 (2026-10-07)
- License: MIT, copied to `LICENSE` from the repository root.

Local changes:

- `references/design.md`: removed the "Creating a uniform design in this app" section, which advised a shared enum of design constants.
- Removed `skills/swiftui-pro/` and `.claude-plugin/`, the Claude Code plugin copy of this skill. Pi discovers `SKILL.md` files recursively, so the copy would load as a second `swiftui-pro`.
