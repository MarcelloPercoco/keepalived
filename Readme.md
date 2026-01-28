# Alpine Keepalived Ultra-Light

[![Docker Image Build](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/docker-build.yml/badge.svg)](https://github.com/YOUR_USERNAME/YOUR_REPO/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Alpine Version](https://img.shields.io/badge/Alpine-3.23-blue)

A high-performance, ultra-lightweight Keepalived container based on **Alpine Linux 3.23**. This image is stripped of heavy frameworks (no Python, no Osixia-bloat) to provide a minimal footprint and maximum security.

---

## 🚀 Features

* **Ultra-lightweight**: ~15MB total size (compared to 100MB+ for Python-based alternatives).
* **Modern Engine**: Built on Alpine 3.23 with Keepalived 2.3.4.
* **Hybrid Configuration**: Supports both automatic generation via Environment Variables and custom configuration via Volume mounting.
* **Real-time Logging**: Logs are natively redirected to `stdout/stderr` for seamless integration with `docker logs`.
* **CI/CD Ready**: Designed for automated builds via GitHub Actions and GHCR.

---

## 🛠 Usage & Deployment

### 1. Simple Mode (Environment Variables)
Perfect for standard Master/Backup setups. Configuration is generated automatically at startup.

```yaml
services:
  keepalived:
    image: ghcr.io/your-username/keepalived:latest
    cap_add:
      - NET_ADMIN
      - NET_RAW
    network_mode: host # Required for VRRP
    environment:
      - STATE=MASTER
      - INTERFACE=eth0
      - VIRTUAL_IP=192.168.1.100/24
      - PRIORITY=101
      - ROUTER_ID=51
```

### 2. Advanced Mode (Custom File)
If you need complex features like Unicast Peers, multiple VRRP instances, or health-check scripts, mount your own configuration.

```yaml
services:
  keepalived:
    image: ghcr.io/your-username/keepalived:latest
    cap_add:
      - NET_ADMIN
      - NET_RAW
    network_mode: host
    volumes:
      - ./my-keepalived.conf:/etc/keepalived/keepalived.conf:ro
```

---

### Configuration Reference (Tabella per il README)
```text
## ⚙️ Configuration Reference

| Variable | Description | Default |
| :--- | :--- | :--- |
| `STATE` | Initial VRRP state (`MASTER` or `BACKUP`) | `MASTER` |
| `INTERFACE` | Network interface to bind the VRRP instance | `eth0` |
| `VIRTUAL_IP` | The VIP address (CIDR format recommended) | `192.168.1.1` |
| `PRIORITY` | VRRP priority value (Higher value = Higher priority) | `100` |
| `ROUTER_ID` | Unique VRRP Router ID (0-255) | `51` |
```
