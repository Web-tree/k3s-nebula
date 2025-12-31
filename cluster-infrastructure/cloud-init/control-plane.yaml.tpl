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
  - unzip
  - awscli
  - xfsprogs

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

  - path: /root/.aws/config
    content: |
      [default]
      region = ${aws_region}

  - path: /root/.aws/credentials
    permissions: "0600"
    content: |
      [default]
      aws_access_key_id = ${aws_access_key_id}
      aws_secret_access_key = ${aws_secret_access_key}

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
      ufw allow 6443/tcp
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

${cert_manager_helmchart_file}

${letsencrypt_clusterissuer_file}

  - path: /usr/local/bin/install-k3s.sh
    permissions: "0755"
    content: |
      #!/bin/bash
      set -e

      # Retry logic for SSM
      get_ssm_param() {
        local name=$1
        local val=""
        for i in {1..5}; do
          val=$(aws ssm get-parameter --name "$name" --with-decryption --query "Parameter.Value" --output text 2>/dev/null)
          if [ -n "$val" ]; then
            echo "$val"
            return 0
          fi
          sleep $((2**i))
        done
        return 1
      }

      DB_CONNECTION=$(get_ssm_param "${db_connection_ssm_path}")

      # Taint logic
      TAINTS=""
      if [ "${has_worker_role}" = "false" ]; then
        TAINTS="--node-taint k3s-controlplane=true:NoSchedule"
      fi

      # Install k3s server
      curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${k3s_version}" sh -s - server \
        --datastore-endpoint="$DB_CONNECTION" \
        --token="${cluster_token}" \
        --write-kubeconfig-mode 644 \
        --disable-cloud-controller \
        --tls-san "${load_balancer_ip}" \
        --node-ip "${private_ip}" \
        --flannel-iface "enp7s0" \
        $TAINTS

      # Wait for k3s to be ready
      sleep 10
      until kubectl get nodes; do sleep 5; done

      # Label node for Longhorn disk creation
      kubectl label node ${hostname} node.longhorn.io/create-default-disk=true --overwrite

runcmd:
  - sysctl --system
  - /usr/local/bin/setup-firewall.sh
  - systemctl restart sshd
  # Mount Longhorn storage volume
  - |
    VOLUME_DEVICE=$(lsblk -o NAME,SERIAL | grep -i "volume-" | awk '{print "/dev/"$1}' | head -1)
    if [ -n "$VOLUME_DEVICE" ]; then
      # Check if filesystem exists, create if not
      if ! blkid "$VOLUME_DEVICE" | grep -q "TYPE="; then
        mkfs.ext4 -F "$VOLUME_DEVICE"
      fi
      # Create mount point
      mkdir -p /var/lib/longhorn
      # Mount the volume
      mount "$VOLUME_DEVICE" /var/lib/longhorn
      # Add to fstab for persistence
      VOLUME_UUID=$(blkid -s UUID -o value "$VOLUME_DEVICE")
      if ! grep -q "$VOLUME_UUID" /etc/fstab; then
        echo "UUID=$VOLUME_UUID /var/lib/longhorn ext4 defaults,nofail 0 2" >> /etc/fstab
      fi
      # Set proper permissions
      chmod 755 /var/lib/longhorn
    fi
  - /usr/local/bin/install-k3s.sh
