# Upstream

- Source: https://github.com/AvdLee/Swift-Concurrency-Agent-Skill, directory `skills/swift-concurrency/`
- Commit: d5770817d2622e1585b1f7eaebc791a9cb0959c8 (2026-09-14)
- License: MIT, copied to `LICENSE` from the repository root.

Local changes:

- `SKILL.md`, Fast Path: build settings are read from `project.yml` (and resolved with `xcodebuild -showBuildSettings`) instead of the generated, gitignored Xcode project. The settings table and the Xcode 26 note say the same.
