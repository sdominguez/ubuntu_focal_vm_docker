#!/usr/bin/env bash
set -euo pipefail

echo "=== [0] Comprobando distribución ==="
if ! [ -r /etc/os-release ]; then
  echo "No se encontró /etc/os-release. Este script soporta Debian/Ubuntu."
  exit 1
fi
. /etc/os-release
ID_LIKE="${ID_LIKE:-$ID}"
if ! echo "$ID_LIKE" | grep -qiE 'debian|ubuntu'; then
  echo "Distribución no soportada: $ID $VERSION_CODENAME"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "=== [1] Actualizando sistema y utilidades base ==="
apt-get update -y
apt-get install -y \
  ca-certificates curl gnupg lsb-release apt-transport-https \
  software-properties-common net-tools git

echo "=== [2] Instalando Docker Engine + Buildx + Compose (plugin) ==="
install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/"${ID}"/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
fi

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${ID} \
  $(. /etc/os-release; echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

echo "=== [2.1] Configurando Docker para Kubernetes (cgroup=systemd, logs, overlay2) ==="
mkdir -p /etc/docker
cat >/etc/docker/daemon.json <<'JSON'
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": { "max-size": "100m" },
  "storage-driver": "overlay2"
}
JSON

echo "=== [2.2] Configurando containerd (SystemdCgroup=true) ==="
mkdir -p /etc/containerd
containerd config default | sed -E 's/SystemdCgroup = false/SystemdCgroup = true/' >/etc/containerd/config.toml

systemctl daemon-reload
systemctl enable containerd docker
systemctl restart containerd docker

echo "=== [2.3] Añadiendo usuario vagrant al grupo docker ==="
if id -u vagrant >/dev/null 2>&1; then
  usermod -aG docker vagrant || true
fi

echo "=== [3] Preparativos del kernel y red para Kubernetes ==="
cat >/etc/modules-load.d/k8s.conf <<EOF
br_netfilter
EOF
modprobe br_netfilter || true

cat >/etc/sysctl.d/99-kubernetes-cri.conf <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

echo "=== [4] Deshabilitando SWAP (requisito kubeadm) ==="
swapoff -a
# Comentamos cualquier entrada de swap en /etc/fstab
sed -ri 's/^([^#].*\s+swap\s+.*)$/# \1/' /etc/fstab || true

echo "=== [5] Instalando Kubernetes (kubelet, kubeadm, kubectl) ==="
# Repositorio oficial (pkgs.k8s.io)
install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]; then
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
    | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  chmod a+r /etc/apt/keyrings/kubernetes-apt-keyring.gpg
fi

cat >/etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /
EOF

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

systemctl enable kubelet
systemctl restart kubelet || true # Es normal que espere a kubeadm init/join

echo "=== [6] Verificaciones rápidas ==="
docker --version || true
docker compose version || true
containerd --version || true
kubeadm version || true
kubectl version --client || true

echo "=== Listo. Docker + Compose + Kubernetes instalados. ==="
echo "   Nota: ejecuta 'newgrp docker' (o reabre sesión) para usar docker sin sudo."
