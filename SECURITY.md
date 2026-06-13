# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| latest  | Yes                |
| < latest | No                |

## Reporting a Vulnerability

**Do not open a public issue for security vulnerabilities.**

Instead, please report vulnerabilities via one of:

1. **GitHub Security Advisories:** [Report a vulnerability](https://github.com/drafthq/draft/security/advisories/new)
2. **Email:** Send details to the repository maintainer (see GitHub profile)

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Affected versions
- Potential impact

### Response Timeline

| Action | Timeline |
|--------|----------|
| Acknowledgment | 48 hours |
| Initial assessment | 5 business days |
| Fix or mitigation | 30 days (critical), 90 days (others) |
| Public disclosure | After fix is released |

### Scope

Draft is a CLI plugin (bash + markdown). Security concerns typically involve:

- Command injection in shell scripts
- Path traversal in file operations
- Sensitive data exposure in generated context files
- Supply chain risks in dependencies

### Recognition

Contributors who report valid security issues will be credited in the release notes (unless they prefer anonymity).
