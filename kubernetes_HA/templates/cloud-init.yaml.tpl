#cloud-config

hostname: ${hostname}
preserve_hostname: false
ssh_pwauth: false
package_update: false
package_upgrade: false

write_files:
  - path: /etc/modules-load.d/k8s.conf
    content: |
      overlay
      br_netfilter

  - path: /etc/sysctl.d/k8s.conf
    content: |
      net.bridge.bridge-nf-call-iptables  = 1
      net.bridge.bridge-nf-call-ip6tables = 1
      net.ipv4.ip_forward                 = 1

  - path: /etc/keepalived/keepalived.conf
    content: |
      global_defs {
        router_id ${hostname}
      }

      vrrp_script chk_apiserver {
        script "/usr/bin/curl -kfsS -o /dev/null --max-time 2 https://127.0.0.1:6443/healthz"
        interval 3
        weight -40
        fall 2
        rise 2
      }

      vrrp_instance VI_K8S {
        state ${vrrp_state}
        interface eth0
        virtual_router_id 51
        priority ${vrrp_priority}
        advert_int 1

        unicast_src_ip ${node_ip}
        unicast_peer {
      %{ for peer in peers ~}
          ${peer}
      %{ endfor ~}
        }

        authentication {
          auth_type PASS
          auth_pass ${vrrp_pass}
        }

        virtual_ipaddress {
          ${vip}/32
        }

        track_script {
          chk_apiserver
        }
      }

runcmd:
%{ for name, ip in nodemap ~}
  - echo "${ip} ${name}" >> /etc/hosts
%{ endfor ~}
  - swapoff -a
  - sed -i '/ swap / s/^/#/' /etc/fstab
  - modprobe overlay
  - modprobe br_netfilter
  - sysctl --system
  - sh -c 'for i in $(seq 1 60); do curl -fsS --max-time 5 -o /dev/null https://mirror.yandex.ru && exit 0; sleep 10; done; exit 1'
  - apt-get update
%{ if role == "master" ~}
  - DEBIAN_FRONTEND=noninteractive apt-get install -y keepalived curl iptables-persistent
  - iptables -t nat -A POSTROUTING -o eth0 ! -d 10.10.0.0/16 -j MASQUERADE
  - netfilter-persistent save
  - systemctl enable --now keepalived
%{ endif ~}