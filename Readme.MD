# Provisionar VM con Vagrant: Docker, Docker Compose y Kubernetes

Este proyecto levanta una máquina virtual (Ubuntu/Debian) con **Docker**, **Docker Compose (plugin oficial)** y **Kubernetes** (`kubeadm`, `kubelet`, `kubectl`) usando **Vagrant**.

> **Nota:** La carpeta del proyecto del host se comparte por defecto en la VM bajo `/vagrant`. Coloca ahí tu `docker-compose.yml` u otros archivos que quieras usar dentro de la VM.

---

## 1) Requisitos previos

- **VirtualBox 7.1.x** (o compatible)
- **Vagrant 2.4.x** (o compatible)
- (Opcional) **Plugin** para alinear *Guest Additions* automáticamente:
  ```bash
  vagrant plugin install vagrant-vbguest
  ```
- (Windows) PowerShell o Git Bash. En Git, es recomendable `core.autocrlf=input` para evitar saltos de línea CRLF en scripts:
  ```bash
  git config --global core.autocrlf input
  ```

---

## 2) Estructura mínima del proyecto

```
tu-carpeta/
├─ Vagrantfile
└─ script.sh        # script de aprovisionamiento (instala Docker/Compose/K8s)
```


## 3) Puesta en marcha

Desde la carpeta que contiene el `Vagrantfile`:

```bash
# (Opcional) Alinear Guest Additions para evitar problemas de carpetas compartidas
vagrant plugin install vagrant-vbguest

# Crear y aprovisionar la VM (esto corre script.sh como root)
vagrant up

# Entrar a la VM por SSH
vagrant ssh
```

Dentro de la VM, valida versiones rápidas:

```bash
docker --version
docker compose version
containerd --version
kubeadm version
kubectl version --client
```

---

## 4) Uso básico de Docker y Docker Compose

Ejemplo rápido:

```bash
# Probar Docker (en la VM)
docker run --rm hello-world

# Si tienes un docker-compose.yml en /vagrant
cd /vagrant
docker compose up -d
docker compose ps
docker compose logs -f
docker compose down
```

---

## 5) Problemas frecuentes y soluciones

### APT bloqueado o permisos insuficientes
- Asegúrate de que el *provisioner* corre como root:
  ```ruby
  config.vm.provision "shell", path: "script.sh", privileged: true
  ```
- Si tu script incluye una espera activa para los *locks* de `apt/dpkg` y detiene `apt-daily*`, evita choques con `cloud-init` en el primer arranque.

### Mismatch de Guest Additions (carpetas no montan, errores de red)
- Instala el plugin `vagrant-vbguest` y luego `vagrant reload`.
- O usa una box más reciente (e.g., `ubuntu/jammy64`, `bento/ubuntu-22.04`).

### `docker: permission denied` con usuario `vagrant`
- Ejecuta `newgrp docker` o cierra y abre sesión (o `vagrant ssh` de nuevo).

### `bash^M` (saltos de línea de Windows)
- Convierte el script a LF:
  ```bash
  sed -i -e 's/\r$//' script.sh
  ```

### Re-provisionar sin recrear
```bash
vagrant provision
```

---

## 6) Comandos útiles de Vagrant

```bash
vagrant up                 # Crea y arranca la VM (provisiona si es primera vez)
vagrant ssh                # Acceder por SSH
vagrant status             # Estado de la VM
vagrant halt               # Apagar la VM
vagrant reload             # Reiniciar la VM
vagrant reload --provision # Reiniciar y re-ejecutar provisioners
vagrant provision          # Re-ejecutar solo provisioners
vagrant destroy -f         # Eliminar la VM
```

---

## 7) Notas finales

- Este setup está pensado para ambientes de laboratorio y pruebas locales.
- Para entornos de trabajo diarios, considera
  - fijar versiones de Docker/Kubernetes según tus necesidades,
  - guardar artefactos (imágenes, manifiestos) en `/vagrant`,
  - y versionar tu proyecto con Git.

