#cloud-config
hostname: ${hostname}
fqdn: ${hostname}
manage_resolv_conf: true
preserve_hostname: false

final_message: "The system is finally up, after $UPTIME seconds"

output:
  all: "| tee -a /var/log/cloud-init-output.log"

package_update: true
packages:
  - curl
  - wget

bootcmd:
  - modprobe br_netfilter
  - modprobe overlay

write_files:
  - path: /etc/modules-load.d/k3s.conf
    content: |
      br_netfilter
      overlay

  - path: /etc/sysctl.d/99-k3s.conf
    content: |
      net.ipv4.ip_forward = 1
      net.bridge.bridge-nf-call-ip6tables = 1
      net.bridge.bridge-nf-call-iptables = 1

  - path: /etc/ssh/sshd_config.d/99-hardening.conf
    content: |
      PasswordAuthentication no
      PermitRootLogin prohibit-password
      ChallengeResponseAuthentication no

  - path: /usr/local/bin/setup-firewall.sh
    permissions: "0755"
    content: |
      #!/bin/bash
      ufw allow 22/tcp
      ufw allow 10250/tcp
      ufw allow 8472/udp
      ufw allow 80/tcp
      ufw allow 443/tcp
      ufw --force enable

  - path: /usr/local/bin/check-status.sh
    permissions: "0755"
    content: |
      #!/bin/bash
      if [ -f /var/lib/cloud/instance/boot-finished ]; then
        echo "Cloud-init finished successfully"
        exit 0
      else
        echo "Cloud-init still running or failed"
        exit 1
      fi

  - path: /usr/local/bin/install-k3s-agent.sh
    permissions: "0755"
    content: |
      #!/bin/bash
      set -e

      # Install k3s agent
      curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${k3s_version}" K3S_URL="https://${load_balancer_ip}:6443" K3S_TOKEN="${cluster_token}" sh -s - agent \
        --node-ip "${private_ip}" \
        --flannel-iface "enp7s0"

runcmd:
  - sysctl --system
  - /usr/local/bin/setup-firewall.sh
  - systemctl restart sshd
  - /usr/local/bin/install-k3s-agent.sh
