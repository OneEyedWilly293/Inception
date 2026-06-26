> [!NOTE]
> *This project has been created as part of the 42 curriculum by jgueon.*

# Inception
A Docker-based infrastructure project deploying a secure WordPress stack.

## Description

### Goal
- Build a small, secure, reproducible infrastructure using Docker.

### Overview
- **NGINX**: TLS termination + reverse proxy
- **WordPress**: CMS application
- **PHP-FPM**: PHP runtime for WordPress
- **MariaDB**: database backend for WordPress data

## Architecture

### Virtual Machines vs Docker
- **VMs**: run a full OS per instance → heavier and slower.
- **Docker**: shares the host kernel → lightweight and fast.
- One service per container improves modularity and reproducibility.

### Secrets vs Environment Variables
- **Secrets**: sensitive data (passwords, usernames, keys).
- **Environment Variables**: runtime configuration values.

### Docker Network vs Host Network
- **Bridge (default)**: isolated network, requires port mapping, recommended.
- **Host**: shares host network, no isolation, no port mapping.

### Docker Volumes vs Bind Mounts
- **Volumes**: managed by Docker, persistent, portable, production-safe.
- **Bind Mounts**: direct host mapping, useful for development.

## Instructions

Make sure the following tools are installed:
- Docker
- Docker Compose
- Make

### Setup

1. Fill in the required values described in `USER_DOC.md` for:
   - `/secrets`
   - `.env`

### Hosts / DNS

Add a local DNS override to `/etc/hosts`:

```sh
127.0.0.1 jgueon.42.fr
```

### Build
```sh
git clone https://github.com/OneEyedWilly293/Inception.git
cd Inception
make up         # build and starts all services
```

### Usage
```sh
make up      # run services
make down    # stop services
make clean   # remove containers and images
make fclean  # wipe all data
make status  [service...]
make logs    [service...]
```

## Resources

### References
- https://docs.docker.com/guides/
- https://mariadb.com/docs/
- https://nginx.org/en/docs/
- https://wordpress.org/documentation/
