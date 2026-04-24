# Changelog

All notable changes to this repository are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Sprint 0] - 2026-04-23 — Repository foundation

### Added
- CLAUDE.md with sanitization and safety rules
- MIT LICENSE
- Expanded README with portfolio framing
- ARCHITECTURE.md (redacted)
- CONTRIBUTING.md
- docs/ skeleton and system architecture Mermaid
- CHANGELOG.md, PR template

### Fixed
- Moved concrete private scrub values (account IDs, domains, vendor names, private paths) out of committed `CLAUDE.md` and PR template into a new gitignored `CLAUDE.local.md`. The committed files now describe the scrub *structure* only.
- Removed incidental reference to the private database name from `docs/DATABASE.md`.
