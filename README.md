*This project has been created as part of the 42 curriculum by ntahadou.*

# Inception — System Administration & Containerization Project

![Docker](https://img.shields.io/badge/Docker-24.0+-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Docker Compose](https://img.shields.io/badge/Docker_Compose-v2+-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Debian](https://img.shields.io/badge/Debian-Bookworm-A81D33?style=for-the-badge&logo=debian&logoColor=white)
![NGINX](https://img.shields.io/badge/NGINX-TLS_1.2%2F1.3-009639?style=for-the-badge&logo=nginx&logoColor=white)
![WordPress](https://img.shields.io/badge/WordPress-PHP_8.2--FPM-21759B?style=for-the-badge&logo=wordpress&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB-10.x-003545?style=for-the-badge&logo=mariadb&logoColor=white)

---

## 1. Description

### Project Overview & Goal
**Inception** is a system administration and DevOps project at **42 School**. The core goal of the project is to deepen knowledge of system administration and containerization by building a multi-container web application infrastructure using **Docker** and **Docker Compose**, running completely inside isolated virtual environments based on **Debian Bookworm**.

The infrastructure consists of three mandatory core services running in dedicated, custom-built containers:
1. **NGINX**: Public-facing web server and reverse proxy enforcing **TLS v1.2 / TLS v1.3** encryption on port `443`.
2. **WordPress + PHP-FPM**: Web application processing dynamic PHP requests and executing core WordPress operations via WP-CLI.
3. **MariaDB**: Relational database management system storing WordPress site data, completely isolated from public network access.

### Use of Docker & Project Sources
The project uses **Docker** to create lightweight, reproducible, and isolated execution environments. Every container is built using custom `Dockerfile` files located in `srcs/requirements/`:
- `srcs/requirements/nginx/`: Contains the NGINX `Dockerfile`, configuration templates, and dynamic certificate generation entrypoint.
- `srcs/requirements/wordpress/`: Contains the WordPress `Dockerfile` installing PHP 8.2 FPM, WP-CLI, and automated setup scripts.
- `srcs/requirements/mariadb/`: Contains the MariaDB `Dockerfile`, server configuration (`50-server.cnf`), and database bootstrap scripts.

### Main Design Choices
- **Debian Bookworm Base Image**: Chosen for stability, security updates, and modern package maintainability across all services.
- **Strict Single-Responsibility Principle**: Each service operates in its own container, preventing monolithic dependencies.
- **Security-First Architecture**: TLS encryption on port `443`, zero exposed database ports, Docker secrets for sensitive passwords (`/run/secrets/`), and administrator username restrictions.
- **Zero-Touch Automation**: Entrypoint scripts automate certificate generation, WordPress core installation, subscriber user creation, and database privilege configuration without manual user interaction.

---

### Architectural Comparisons

#### 1. Virtual Machines vs Docker
| Parameter | Virtual Machines (VMs) | Docker Containers |
| :--- | :--- | :--- |
| **Virtualization Level** | Hardware-level virtualization. Emulates full virtual hardware (CPU, RAM, NIC). | OS-level virtualization (Containerization). |
| **Kernel Usage** | Each VM runs its own dedicated guest operating system kernel. | Containers share the host operating system kernel via Linux `cgroups` and `namespaces`. |
| **Resource Overhead** | High CPU, memory, and disk usage due to guest OS overhead. | Extremely lightweight; minimal memory footprint and near-zero CPU overhead. |
| **Startup Time** | Slow (tens of seconds to minutes). | Instantaneous (milliseconds to seconds). |
| **Isolation** | Strong hardware isolation. | Strong process-level and namespace isolation. |

#### 2. Secrets vs Environment Variables
| Parameter | Environment Variables (`.env`) | Docker Secrets (`/run/secrets/`) |
| :--- | :--- | :--- |
| **Storage Mechanism** | Plain text key-value pairs loaded into container process environment space. | Files mounted into temporary, RAM-backed filesystems (`tmpfs`) at `/run/secrets/`. |
| **Visibility & Security** | Visible via `docker inspect`, `env` commands, or process table dumps (`ps aux`). | Never exposed in environment variables or `docker inspect` outputs. |
| **Ideal Use Case** | Non-sensitive runtime parameters (e.g. `DOMAIN_NAME`, `WP_TITLE`, `MYSQL_DATABASE`). | Sensitive credentials (e.g. `db_password`, `db_root_password`, `credentials`). |
| **Disk Exposure** | May persist in host shell history or environment inspection logs. | Exists in host filesystem files with strict file permissions (`600`) and stays in RAM inside containers. |

#### 3. Docker Network vs Host Network
| Parameter | Docker Network (Custom Bridge) | Host Network (`network_mode: host`) |
| :--- | :--- | :--- |
| **Isolation** | Creates an isolated virtual bridge network (`inception`) with separate IP subnets. | Shares the host network namespace directly with no container isolation. |
| **Port Exposure** | Only explicitly published ports (`443:443`) are reachable from outside. | All ports opened by containers bind directly to host network interfaces. |
| **Service Discovery** | Provides internal DNS resolution by container names (`nginx`, `wordpress`, `mariadb`). | Containers must connect via `localhost` and manage host port conflicts. |
| **Security** | High security; database and FastCGI ports (3306, 9000) remain strictly internal. | Low security; internal services risk exposing ports on host interfaces. |

#### 4. Docker Volumes vs Bind Mounts
| Parameter | Docker Named Volumes | Docker Bind Mounts (Local Driver Bind) |
| :--- | :--- | :--- |
| **Storage Location** | Managed automatically by Docker inside `/var/lib/docker/volumes/`. | Explicitly mapped to host directory paths (`/home/ntahadou/data/...`). |
| **Host Interaction** | Host filesystem layout is obscured; managed via Docker CLI (`docker volume`). | Direct host visibility and access; host users can inspect, edit, or back up files directly. |
| **Control & Lifecycle** | Managed independently of host file structure. | Tied to specific host filesystem paths declared in `docker-compose.yml` and `Makefile`. |
| **Inception Usage** | Used via `driver_opts` with `o: bind` to pin persistence directly to `/home/ntahadou/data`. | Ensures WordPress content and MariaDB database files survive container purges. |

---

## 2. Architecture & Infrastructure

The architecture follows a standard multi-tier infrastructure where NGINX acts as the sole public gateway receiving encrypted HTTPS traffic, forwarding PHP script execution to WordPress via FastCGI, which in turn queries MariaDB over the internal Docker network.

### Communication Flow Diagram

```text
               +-------------------------------------------------+
               |                    HOST SYSTEM                  |
               |                                                 |
               |   Browser / Client Request                      |
               |        (https://ntahadou.42.fr:443)             |
               +-----------------------+-------------------------+
                                       |
                                       | HTTPS (Port 443)
                                       v
+-----------------------------------------------------------------------------------+
| DOCKER BRIDGE NETWORK: inception                                                  |
|                                                                                   |
|  +-----------------------+   FastCGI    +-----------------------+                 |
|  | NGINX                 |  (Port 9000) | WORDPRESS + PHP-FPM   |                 |
|  | (container: nginx)    +------------->| (container: wordpress)|                 |
|  |                       |              |                       |                 |
|  | Reads static files &  |              | Executes PHP scripts  |                 |
|  | terminates TLS        |              | & WP-CLI commands     |                 |
|  +-----------+-----------+              +-----------+-----------+                 |
|              |                                      |                             |
|              | Read-only                            | MySQL Protocol              |
|              | Mount                                | (Port 3306)                 |
|              v                                      v                             |
|  +-----------------------+              +-----------------------+                 |
|  | Volume: wordpress_data|              | MARIADB               |                 |
|  | /var/www/html (ro)    |              | (container: mariadb)  |                 |
|  +-----------------------+              |                       |                 |
|                                         | Database storage      |                 |
|                                         +-----------+-----------+                 |
|                                                     |                             |
|                                                     | Read/Write Mount            |
|                                                     v                             |
|                                         +-----------------------+                 |
|                                         | Volume: mariadb_data  |                 |
|                                         | /var/lib/mysql        |                 |
|                                         +-----------------------+                 |
+-----------------------------------------------------------------------------------+
```

---

## 3. Instructions

### Prerequisites
1. **Operating System**: Linux (Ubuntu / Debian recommended).
2. **Docker Engine**: Version 24.0+ installed and running.
3. **Docker Compose**: Plugin v2.0+ installed.
4. **Make Utility**: `make` installed.

### Host Domain Resolution (`/etc/hosts`)
The project domain is set to `ntahadou.42.fr`. Map this domain to your local loopback address in `/etc/hosts`:

```bash
sudo sh -c 'echo "127.0.0.1 ntahadou.42.fr" >> /etc/hosts'
```

Verify host mapping:
```bash
ping -c 1 ntahadou.42.fr
```

### Installation, Compilation & Execution
To build all Docker images, set up host data directories (`/home/ntahadou/data/...`), and launch containers in detached mode:

```bash
make
```

### Available Management Commands

| Command | Description |
| :--- | :--- |
| `make` | Creates host storage directories (`/home/ntahadou/data/...`) and launches all containers. |
| `make build` | Builds or rebuilds Docker images for NGINX, WordPress, and MariaDB. |
| `make up` | Starts all services in detached background mode (`docker compose up -d`). |
| `make down` | Stops and removes running containers and networks (`docker compose down`). |
| `make start` | Starts existing stopped containers (`docker compose start`). |
| `make stop` | Stops running containers without removing them (`docker compose stop`). |
| `make restart` | Restarts all running containers (`docker compose restart`). |
| `make logs` | Streams consolidated logs from all containers (`docker compose logs`). |
| `make ps` | Displays status and port mappings of all project containers (`docker compose ps`). |
| `make clean` | Stops containers and removes networks and named volumes (`docker compose down -v`). |
| `make fclean` | Complete purge: removes containers, networks, volumes, prunes Docker system images/cache (`docker system prune -af`), and deletes host data directories (`rm -rf /home/ntahadou/data/*`). |
| `make re` | Performs `fclean`, rebuilds images, and launches the entire stack clean. |

---

## 4. Accessing the Application

- **Website Frontend**: `https://ntahadou.42.fr`
- **WordPress Admin Panel**: `https://ntahadou.42.fr/wp-admin`
- **Default Accounts**:
  - Administrator: `ntahadou` (Password in `secrets/credentials.txt`)
  - Subscriber: `student` (Password in `secrets/credentials.txt`)

For detailed step-by-step user operation, testing, and troubleshooting, refer to **[USER_DOC.md](file:///home/noureddine/inception/USER_DOC.md)**.
For deep technical internals, execution traces, and debugging, refer to **[DEV_DOC.md](file:///home/noureddine/inception/DEV_DOC.md)**.

---

## 5. 42 Inception Requirements Compliance

| 42 Subject Requirement | Status | Implementation Details |
| :--- | :--- | :--- |
| **Debian Bookworm base image** | Compliant | All `Dockerfile` files explicitly declare `FROM debian:bookworm`. |
| **Docker Compose orchestration** | Compliant | Infrastructure is managed via `srcs/docker-compose.yml`. |
| **Dedicated container per service** | Compliant | 3 separate containers: `nginx`, `wordpress`, and `mariadb`. |
| **NGINX container with TLS v1.2 / v1.3** | Compliant | NGINX template enforces `ssl_protocols TLSv1.2 TLSv1.3;` on port `443`. |
| **WordPress + PHP-FPM container** | Compliant | PHP 8.2 FPM runs on port `9000` without NGINX inside the same container. |
| **MariaDB container** | Compliant | MariaDB runs in an isolated container on port `3306`. |
| **Persistent Volumes** | Compliant | Bind mounts to host directories `/home/ntahadou/data/mariadb` and `/home/ntahadou/data/wordpress`. |
| **Custom Docker Bridge Network** | Compliant | Services communicate via private `inception` bridge network. |
| **Automatic Container Restart** | Compliant | `restart: always` flag set on all services in `docker-compose.yml`. |
| **Domain format `login.42.fr`** | Compliant | `DOMAIN_NAME` set to `ntahadou.42.fr`. |
| **Docker Secrets usage** | Compliant | Sensitive passwords read from `/run/secrets/` in container entrypoint scripts. |
| **Forbidden admin username** | Compliant | `setup.sh` rejects `WP_ADMIN_USER` values containing `admin` or `administrator`. |

---

## 6. Resources & AI Usage

### Classic References & Technical Documentation
- **Docker Engine Documentation**: [https://docs.docker.com/engine/](https://docs.docker.com/engine/)
- **Docker Compose Specification**: [https://docs.docker.com/compose/compose-file/](https://docs.docker.com/compose/compose-file/)
- **Debian Bookworm Package Repository**: [https://www.debian.org/distrib/packages](https://www.debian.org/distrib/packages)
- **NGINX HTTP & TLS Module Documentation**: [https://nginx.org/en/docs/http/ngx_http_ssl_module.html](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)
- **WP-CLI Command Reference**: [https://developer.wordpress.org/cli/commands/](https://developer.wordpress.org/cli/commands/)
- **MariaDB Server Documentation**: [https://mariadb.com/kb/en/documentation/](https://mariadb.com/kb/en/documentation/)
- **OpenSSL Command Manual**: [https://www.openssl.org/docs/manmaster/man1/openssl.html](https://www.openssl.org/docs/manmaster/man1/openssl.html)

### Artificial Intelligence (AI) Usage Declaration
In accordance with 42 School guidelines, Artificial Intelligence was utilized as an auxiliary agent during the documentation and review phases of this project as specified below:

- **AI Model / Tool Used**: Antigravity AI (Google DeepMind pair-programming assistant running Gemini models).
- **Specific Tasks Assisted by AI**:
  1. **Static Repository Analysis**: AI performed non-intrusive static code inspection across `Makefile`, `docker-compose.yml`, `Dockerfile` manifests, and shell entrypoint scripts (`generate-certificate.sh`, `setup.sh`, `init_db.sh`) to verify requirement compliance.
  2. **Technical Documentation Authoring**: AI generated comprehensive Markdown documentation files ([README.md](file:///home/noureddine/inception/README.md), [USER_DOC.md](file:///home/noureddine/inception/USER_DOC.md), and [DEV_DOC.md](file:///home/noureddine/inception/DEV_DOC.md)) reflecting the exact implementation found in the repository without altering source code.
  3. **Visual Architecture Diagrams**: AI generated Mermaid diagrams and comparison matrices (e.g. VMs vs Docker, Secrets vs Environment Variables, Docker Network vs Host Network, Volumes vs Bind Mounts).
