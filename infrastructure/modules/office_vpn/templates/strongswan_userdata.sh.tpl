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
cat > /etc/sysctl.d/99-vpn.conf <<EOF
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
EOF
sysctl -p /etc/sysctl.d/99-vpn.conf

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
