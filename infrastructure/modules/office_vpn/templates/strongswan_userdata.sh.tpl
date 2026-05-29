#!/bin/bash
# =============================================================================
# CGW simulator bootstrap - policy-based IPsec to AWS VPN tunnel 1
# =============================================================================
# Boot order:
# 1. EC2 launches with Internet access
# 2. Ensure SSM Agent is active first (so debugging works)
# 3. Install Libreswan
# 4. Wait for aws_eip_association to attach the stable EIP
# 5. Configure IPsec with leftid = EIP (matches AWS CGW)
# 6. Start tunnel
# =============================================================================

set +e # do not exit on first failure - we want the log to capture everything
exec > /var/log/cgw-bootstrap.log 2>&1
echo "[bootstrap] starting at $(date)"

retry() {
    local attempts=$1
    shift
    local n=1
    until "$@"; do
        if [ "$n" -ge "$attempts" ]; then
            echo "[bootstrap] command failed after $attempts attempts: $*"
            return 1
        fi
        echo "[bootstrap] command failed, retry $n/$attempts: $*"
        sleep $((n * 10))
        n=$((n + 1))
    done
}

TOKEN=$(curl -fsSL -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 600")

IDENTITY_DOC=$(curl -fsSL -H "X-aws-ec2-metadata-token: $TOKEN" \
    "http://169.254.169.254/latest/dynamic/instance-identity/document")
AWS_REGION=$(echo "$IDENTITY_DOC" | sed -n 's/.*"region"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
AWS_REGION="$${AWS_REGION:-ap-southeast-1}"
echo "[bootstrap] detected AWS region: $AWS_REGION"

install_ssm_agent() {
    echo "[bootstrap] ensuring amazon-ssm-agent is active"
    if command -v dnf >/dev/null 2>&1; then
        rpm -q amazon-ssm-agent >/dev/null 2>&1 || retry 3 dnf install -y amazon-ssm-agent || true
    elif command -v apt-get >/dev/null 2>&1; then
        retry 3 curl -fsSL "https://s3.$AWS_REGION.amazonaws.com/amazon-ssm-$AWS_REGION/latest/debian_amd64/amazon-ssm-agent.deb" -o /tmp/amazon-ssm-agent.deb || \
            retry 3 curl -fsSL "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb" -o /tmp/amazon-ssm-agent.deb
        dpkg -i /tmp/amazon-ssm-agent.deb || retry 3 apt-get install -f -y
    fi

    systemctl daemon-reload
    systemctl enable amazon-ssm-agent || true
    systemctl restart amazon-ssm-agent || true

    if systemctl is-active --quiet amazon-ssm-agent; then
        echo "[bootstrap] SSM Agent is active"
        return 0
    fi

    echo "[bootstrap] WARNING: SSM Agent is still not active"
    systemctl status amazon-ssm-agent --no-pager || true
    return 1
}

install_ssm_agent

install_packages() {
    if command -v dnf >/dev/null 2>&1; then
        retry 5 dnf install -y bind-utils tcpdump iptables ca-certificates libreswan
    elif command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        retry 5 apt-get update
        retry 5 apt-get install -y dnsutils tcpdump iptables curl ca-certificates libreswan
    else
        echo "[bootstrap] FATAL: no supported package manager found"
        exit 1
    fi
}

install_packages
systemctl daemon-reload

if command -v ipsec >/dev/null 2>&1; then
    DAEMON=ipsec
else
    echo "[bootstrap] FATAL: Libreswan/ipsec could not be installed"
    exit 1
fi

# -----------------------------------------------------------------------------
# 2. Kernel parameters
# -----------------------------------------------------------------------------
# IMPORTANT: rp_filter MUST stay at strict (1) on eth0 to keep SSM Agent's
# long-poll connections stable. Loose rp_filter (2) on all interfaces + IPsec
# IP forwarding causes the kernel to drop SSM Agent return packets after the
# tunnel comes up, which manifests as the agent going into "hibernation" and
# the instance showing ConnectionLost a few minutes after Online.
# Only relax rp_filter for the IPsec virtual interface where it's actually needed.
cat > /etc/sysctl.d/99-vpn.conf <<EOF
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
# Default rp_filter = 1 (strict) for all interfaces, including eth0 (SSM path).
# IPsec/xfrm interfaces handle their own reverse path via policy, no need for
# loose mode globally.
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1
EOF
sysctl -p /etc/sysctl.d/99-vpn.conf

# -----------------------------------------------------------------------------
# 2b. iptables FORWARD rules — REQUIRED for the CGW to route office traffic into
#     the tunnel. AL2023 ships Docker, which sets the FORWARD chain default
#     policy to DROP. Without explicit ACCEPT rules for office<->AWS, packets
#     from the workstation are dropped at the CGW even though the IPsec tunnel
#     is UP and ip_forward=1 (the CGW itself can ping AWS, but forwarded traffic
#     from the office private subnet cannot).
# -----------------------------------------------------------------------------
echo "[bootstrap] adding iptables FORWARD rules for ${office_cidr} <-> ${aws_internal_cidr}"
iptables -C FORWARD -s ${office_cidr} -d ${aws_internal_cidr} -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -s ${office_cidr} -d ${aws_internal_cidr} -j ACCEPT
iptables -C FORWARD -s ${aws_internal_cidr} -d ${office_cidr} -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -s ${aws_internal_cidr} -d ${office_cidr} -j ACCEPT

# Persist the rules so they survive a reboot (iptables-services may not be
# installed; fall back to a tiny systemd unit that re-applies on boot).
if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save || true
elif command -v service >/dev/null 2>&1 && [ -f /etc/sysconfig/iptables ]; then
    iptables-save > /etc/sysconfig/iptables || true
else
    # Re-apply just the two FORWARD rules on boot (idempotent via -C check).
    cat > /usr/local/sbin/cgw-forward.sh <<'SCRIPT'
#!/bin/bash
iptables -C FORWARD -s OFFICE_CIDR -d AWS_CIDR -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -s OFFICE_CIDR -d AWS_CIDR -j ACCEPT
iptables -C FORWARD -s AWS_CIDR -d OFFICE_CIDR -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -s AWS_CIDR -d OFFICE_CIDR -j ACCEPT
SCRIPT
    sed -i "s|OFFICE_CIDR|${office_cidr}|g; s|AWS_CIDR|${aws_internal_cidr}|g" /usr/local/sbin/cgw-forward.sh
    chmod +x /usr/local/sbin/cgw-forward.sh
    cat > /etc/systemd/system/cgw-forward.service <<'UNIT'
[Unit]
Description=Restore CGW iptables FORWARD rules
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/cgw-forward.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
    systemctl daemon-reload
    systemctl enable cgw-forward.service || true
fi

# -----------------------------------------------------------------------------
# 3. Wait for EIP attachment (replaces auto public IP with the stable EIP that
#    AWS-side has registered as our Customer Gateway IP)
# -----------------------------------------------------------------------------
echo "[bootstrap] waiting for EIP ${cgw_eip} to be attached..."
for i in $(seq 1 60); do
    CURRENT_IP=$(curl -fsSL -H "X-aws-ec2-metadata-token: $TOKEN" \
        "http://169.254.169.254/latest/meta-data/public-ipv4" 2>/dev/null || echo "")
    if [ "$CURRENT_IP" = "${cgw_eip}" ]; then
        echo "[bootstrap] EIP attached after $((i*5))s - public IP = $CURRENT_IP"
        break
    fi
    echo "[bootstrap] current public IP=$CURRENT_IP, retry $i/60..."
    sleep 5
done

# Public IP changed (auto -> EIP). The SSM agent registered against the old
# IP and may now show as ConnectionLost. Restart it so it re-registers cleanly.
echo "[bootstrap] restarting SSM agent after EIP swap"
systemctl restart amazon-ssm-agent || true

# SSM agent enters "hibernation" if it fails to register on first boot
# (common cause: DNS timeout during strongSwan/libreswan install racing with
# cloud-init network setup). Once hibernated, it does NOT retry on its own.
# A simple "systemctl restart" is NOT enough — must verify DNS first, then
# restart so the agent's first attempt sees a working network path.
echo "[bootstrap] verifying DNS + SSM endpoint reachable before kicking agent"
for i in $(seq 1 30); do
    if getent hosts "ssm.$AWS_REGION.amazonaws.com" >/dev/null 2>&1 && \
       curl -fsSL --max-time 5 "https://ssm.$AWS_REGION.amazonaws.com" >/dev/null 2>&1; then
        echo "[bootstrap] DNS + SSM endpoint OK after $((i*5))s"
        break
    fi
    echo "[bootstrap] DNS or SSM endpoint not ready, retry $i/30..."
    sleep 5
done

# Kill (not just restart) — hibernation state survives systemctl restart on
# some agent versions. Stopping + starting forces a fully fresh process.
echo "[bootstrap] resetting SSM agent (kill any hibernation state)"
systemctl stop amazon-ssm-agent || true
sleep 2
systemctl start amazon-ssm-agent

# Watchdog: re-check every 5 min and restart if agent is not responding
# (defensive against future hibernation triggers like maintenance reboots).
cat > /etc/systemd/system/ssm-keepalive.service <<'EOF'
[Unit]
Description=Restart amazon-ssm-agent if not active
After=amazon-ssm-agent.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'systemctl is-active amazon-ssm-agent || systemctl restart amazon-ssm-agent'
EOF

cat > /etc/systemd/system/ssm-keepalive.timer <<'EOF'
[Unit]
Description=Run ssm-keepalive every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now ssm-keepalive.timer

# -----------------------------------------------------------------------------
# 4. Write ipsec.conf (Libreswan, policy-based, tunnel 1 only)
# -----------------------------------------------------------------------------
cat > /etc/ipsec.conf <<EOF
config setup
    uniqueids=no
    protostack=netkey
    # Libreswan 4+ disables IKEv1 by default - re-enable it for AWS S2S VPN.
    ikev1-policy=accept

conn aws-tunnel-1
    type=tunnel
    authby=secret
    keyexchange=ike
    ikev2=never
    # Libreswan 4.12+ removes weak DH group 2 (modp1024). Use group 14 (modp2048).
    # AWS S2S VPN default supports modp2048 across multiple cipher suites.
    ike=aes256-sha256;modp2048,aes128-sha256;modp2048,aes256-sha1;modp2048
    phase2=esp
    phase2alg=aes256-sha256;modp2048,aes128-sha256;modp2048
    pfs=yes
    ikelifetime=28800s
    salifetime=3600s
    keyingtries=%forever
    dpdaction=restart
    dpddelay=10s
    dpdtimeout=30s
    left=%defaultroute
    leftnexthop=%defaultroute
    leftid=${cgw_eip}
    leftsubnet=${office_cidr}
    right=${tunnel1_address}
    rightid=${tunnel1_address}
    rightsubnet=${aws_internal_cidr}
    auto=start
EOF

# -----------------------------------------------------------------------------
# 5. Pre-shared key
# -----------------------------------------------------------------------------
cat > /etc/ipsec.secrets <<EOF
${cgw_eip} ${tunnel1_address} : PSK "${tunnel1_preshared_key}"
EOF
chmod 600 /etc/ipsec.secrets

# -----------------------------------------------------------------------------
# 6. Start daemon
# -----------------------------------------------------------------------------
systemctl enable $DAEMON
systemctl reset-failed $DAEMON || true
systemctl restart $DAEMON
sleep 5
ipsec auto --add aws-tunnel-1 || true
ipsec auto --up aws-tunnel-1 || true

# -----------------------------------------------------------------------------
# 7. Diagnostic snapshot
# -----------------------------------------------------------------------------
sleep 15
echo "[bootstrap] === $DAEMON status ==="
systemctl status $DAEMON --no-pager || true
echo "[bootstrap] === ipsec status ==="
ipsec status || true
echo "[bootstrap] === ipsec auto status ==="
ipsec auto --status || true
echo "[bootstrap] === ip xfrm state ==="
ip xfrm state || true

echo "[bootstrap] done at $(date)"
