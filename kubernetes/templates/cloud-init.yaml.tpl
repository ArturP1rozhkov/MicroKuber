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
%{ for name, ip in node_map ~}
  - echo "${ip} ${name}" >> /etc/hosts
%{ endfor ~}

  - swapoff -a
  - sed -i '/ swap / s/^/#/' /etc/fstab
  - modprobe overlay
  - modprobe br_netfilter
  - sysctl --system
%{ if role == "master" ~}
  - iptables -t nat -A POSTROUTING ! -d 10.10.0.0/16 -j MASQUERADE
%{ endif ~}
  - until apt-get update; do echo "waiting for network (NAT via master)..."; sleep 10; done
  - DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
  - DEBIAN_FRONTEND=noninteractive apt-get install -y containerd apt-transport-https ca-certificates curl gpg
  - mkdir -p /etc/containerd
  - containerd config default > /etc/containerd/config.toml
  - sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
  - systemctl enable --now containerd
  - systemctl restart containerd
%{ if role == "master" ~}
  - echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
  - DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
  - netfilter-persistent save
%{ endif ~}
  - mkdir -p -m 755 /etc/apt/keyrings
  - curl -fsSL https://pkgs.k8s.io/core:/stable:/${k8s_minor}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  - echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${k8s_minor}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
  - apt-get update
  - DEBIAN_FRONTEND=noninteractive apt-get install -y kubelet kubeadm kubectl
  - apt-mark hold kubelet kubeadm kubectl
