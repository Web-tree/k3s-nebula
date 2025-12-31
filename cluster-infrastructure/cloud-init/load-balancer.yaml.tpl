#cloud-config
package_update: true

final_message: "The system is finally up, after $UPTIME seconds"

output:
  all: "| tee -a /var/log/cloud-init-output.log"
packages:
  - haproxy

write_files:
  - path: /etc/haproxy/haproxy.cfg
    content: |
      global
          log /dev/log    local0
          log /dev/log    local1 notice
          chroot /var/lib/haproxy
          stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
          stats timeout 30s
          user haproxy
          group haproxy
          daemon

      defaults
          log     global
          mode    tcp
          option  tcplog
          option  dontlognull
          timeout connect 10s
          timeout client  86400s
          timeout server  86400s
          timeout tunnel  86400s
          errorfile 400 /etc/haproxy/errors/400.http
          errorfile 403 /etc/haproxy/errors/403.http
          errorfile 408 /etc/haproxy/errors/408.http
          errorfile 500 /etc/haproxy/errors/500.http
          errorfile 502 /etc/haproxy/errors/502.http
          errorfile 503 /etc/haproxy/errors/503.http
          errorfile 504 /etc/haproxy/errors/504.http

      frontend k3s_frontend
          bind *:6443
          mode tcp
          option tcplog
          default_backend k3s_backend

      frontend http_frontend
          bind *:80
          mode tcp
          option tcplog
          default_backend http_backend

      frontend https_frontend
          bind *:443
          mode tcp
          option tcplog
          default_backend https_backend

      backend k3s_backend
          mode tcp
          option tcp-check
          balance roundrobin
          default-server inter 10s downinter 5s rise 2 fall 2
          
          %{ for ip in control_plane_ips ~}
          server k3s-${ip} ${ip}:6443 check
          %{ endfor ~}

      backend http_backend
          mode tcp
          option tcp-check
          balance roundrobin
          default-server inter 10s downinter 5s rise 2 fall 2
          
          %{ for ip in control_plane_ips ~}
          server http-${ip} ${ip}:80 check
          %{ endfor ~}

      backend https_backend
          mode tcp
          option tcp-check
          balance roundrobin
          default-server inter 10s downinter 5s rise 2 fall 2
          
          %{ for ip in control_plane_ips ~}
          server https-${ip} ${ip}:443 check
          %{ endfor ~}

  - path: /etc/ssh/sshd_config.d/99-hardening.conf
    content: |
      PasswordAuthentication no
      PermitRootLogin prohibit-password
      ChallengeResponseAuthentication no

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

runcmd:
  - sysctl --system
  - ufw allow 22/tcp
  - ufw allow 6443/tcp
  - ufw allow 80/tcp
  - ufw allow 443/tcp
  - ufw --force enable
  - systemctl restart sshd
  - systemctl enable haproxy
  - systemctl restart haproxy
