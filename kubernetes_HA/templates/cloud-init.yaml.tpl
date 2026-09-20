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