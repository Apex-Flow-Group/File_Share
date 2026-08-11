# Contributing to Apex File Share

Thank you for your interest in contributing. This document covers everything you need to get started.

---

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable releases only — merged from `develop` |
| `develop` | Active development — all PRs target this branch |
| `feature/your-feature` | New features |
| `fix/your-fix` | Bug fixes |
| `docs/your-change` | Documentation only |

**Always branch from `develop`, never from `main`.**

---

## Getting Started

```bash
# 1. Fork the repository on GitHub

# 2. Clone your fork
git clone https://github.com/YOUR_USERNAME/File_Share.git
cd File_Share

# 3. Add the upstream remote
git remote add upstream https://github.com/Apex-Flow-Group/File_Share.git

# 4. Install dependencies
flutter pub get

# 5. Create your branch
git checkout develop
git checkout -b feature/my-new-feature
```

---

## Development Workflow

### Before you start coding

Sync with the latest `develop`:
```bash
git fetch upstream
git rebase upstream/develop
```

### Code style

- Run the linter before committing:
  ```bash
  flutter analyze
  ```
- Follow the existing code style — no new `print()` calls, use `ApexLogger` instead
- Keep widgets focused — if a widget grows beyond ~200 lines consider splitting it
- Arabic strings go in `lib/l10n/app_ar.arb`, English in `lib/l10n/app_en.arb`

### Testing your changes

```bash
# Run all tests
flutter test

# Run on a specific platform
flutter run -d linux   # or windows / android / <device-id>
```

For TV changes, test with ADB over WiFi:
```bash
adb connect <tv-ip>:5555
flutter run -d <tv-ip>:5555
```

---

## Commit Messages

Use the format: `type(scope): short description`

| Type | When to use |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Code change with no functional difference |
| `perf` | Performance improvement |
| `chore` | Build scripts, dependencies, config |

Examples:
```
feat(linux): add clipboard monitoring via GTK owner-change signal
fix(transfer): prevent progress bar appearing on all devices simultaneously
docs(readme): update build instructions for Linux
```

---

## Pull Request Checklist

Before opening a PR, confirm:

- [ ] Branched from `develop`
- [ ] `flutter analyze` passes with no issues
- [ ] Tested on the platform(s) affected by your change
- [ ] Localization strings added to both `app_ar.arb` and `app_en.arb` if needed
- [ ] No hardcoded secrets, credentials, or personal data
- [ ] `CHANGELOG.md` entry added under a new `[Unreleased]` section

---

## Platform-Specific Notes

### Android
- Minimum SDK: API 21
- File access uses `FileProvider` — do not use raw `file://` URIs
- Test on both phone layout and TV layout (`PlatformDetector.isTV`)

### Windows
- Clipboard monitoring is in `windows/runner/flutter_window.cpp`
- Native changes require a full rebuild (`flutter build windows`)

### Linux
- Clipboard monitoring is in `linux/runner/my_application.cc`
- Native changes require a full rebuild (`flutter build linux`)
- GTK headers must be installed: `sudo apt install libgtk-3-dev` (Debian/Ubuntu) or `sudo dnf install gtk3-devel` (Fedora)

### Android TV
- Every interactive element needs a `FocusNode` and `onKeyEvent`
- Use `Dialog` instead of `BottomSheet` for TV overlays
- See [TV_DEVELOPMENT_GUIDE.md](TV_DEVELOPMENT_GUIDE.md) for the full reference

---

## Reporting Issues

When opening a bug report please include:

1. **Platform** — Android version / Windows version / Linux distro
2. **App version** — shown in Settings → About
3. **Steps to reproduce** — the exact steps that trigger the bug
4. **Expected behavior** — what should happen
5. **Actual behavior** — what actually happens
6. **Logs** — from `flutter run` output or `adb logcat` on Android

---

## Feature Requests

Open an issue with the `enhancement` label. Describe:
- The problem you are trying to solve
- Your proposed solution
- Any alternatives you considered

---

## License

By contributing you agree that your code will be released under the [MIT License](LICENSE).
