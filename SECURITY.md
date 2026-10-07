# Security Policy

## Supported Versions

Only the latest released version of Putter is actively supported with security fixes.

| Version | Supported          |
| ------- | ------------------ |
| 0.21    | :white_check_mark: |
| < 0.21  | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in Putter, please do not open a public issue.

Use GitHub's private vulnerability reporting feature for this repository instead.

Please include:

- a clear description of the issue,
- steps to reproduce it,
- the affected Putter version,
- any relevant logs or screenshots,
- and, if known, the potential impact.

Security reports will be reviewed as soon as reasonably possible.

## Scope

Putter is a local Windows utility that reads and modifies PuTTY session data in the current user's registry.

Security issues involving unintended registry modification, unsafe import behavior, arbitrary code execution, privilege escalation, or unintended disclosure of local data are considered in scope.
