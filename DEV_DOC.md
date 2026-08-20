# Inception — Developer & Maintainer Documentation (`DEV_DOC.md`)

This document is written for developers, system administrators, and maintainers who need to **understand, build, operate, debug, modify, and extend** the Inception multi-container infrastructure.

---

## 1. Setting Up the Environment from Scratch

This section details all prerequisites, configuration manifests, environment variables, secrets management, and host resolution required to initialize the project on a clean machine.

### 1.1 Host Environment Prerequisites
Before setting up the repository, ensure the host system fulfills the following technical requirements:

- **Operating System**: Linux (Debian 12 Bookworm, Ubuntu 22.04 LTS / 24.04 LTS x86_64).
- **Docker Engine**: Version `24.0.0` or higher (`docker --version`).
- **Docker Compose Plugin**: Version `v2.0.0` or higher (`docker compose version`).
- **GNU Make**: Installed on host (`make --version`).
- **Required Host Utilities**: `curl`, `openssl`, `netcat` (`nc`), `bash`, `tar`.
- **Host Privileges**: The developer user must have `sudo` access or belong to the `docker` user group (`sudo usermod -aG docker $USER`).

### 1.2 Repository Configuration (`srcs/.env`)
All non-sensitive, environment-wide configuration variables are stored in `srcs/.env`. This file is parsed by `docker-compose.yml` (`env_file`) and injected into service containers during runtime.

| Environment Variable | Applied Service | Purpose & Description | Default / Example Value |
| :--- | :--- | :--- | :--- |
| `DOMAIN_NAME` | `nginx`, `wordpress` | Fully Qualified Domain Name bound to NGINX TLS server block and WordPress home URL. | `ntahadou.42.fr` |
| `WP_TITLE` | `wordpress` | Title of the WordPress web site. | `Inception` |
| `WP_ADMIN_USER` | `wordpress` | Administrator account username. **Constraint**: Cannot contain `admin` or `administrator`. | `ntahadou` |
| `WP_ADMIN_EMAIL` | `wordpress` | Email address associated with the administrator account. | `ntahadou@example.com` |
| `WP_USER` | `wordpress` | Username for the secondary non-administrator subscriber account. | `student` |
| `WP_USER_EMAIL` | `wordpress` | Email address for the subscriber account. | `student@example.com` |
| `MYSQL_DATABASE` | `mariadb`, `wordpress` | Relational database schema name created on first boot. | `wordpress` |
| `MYSQL_USER` | `mariadb`, `wordpress` | Non-root MariaDB user account created for WordPress database access. | `wp_user` |
| `MYSQL_HOST` | `wordpress` | Hostname of the MariaDB service (defined in `docker-compose.yml`). | `mariadb` |

### 1.3 Secrets Management (`secrets/`)
Sensitive credentials are stored in plain text files inside the `secrets/` directory on the host and passed into containers via **Docker Secrets**. Docker mounts these files inside containers as temporary, RAM-backed filesystems (`tmpfs`) at `/run/secrets/`.

#### Host Secret File Paths & Container Mount Matrix

```text
Host File Path                         Container Secret Mount Point            Consuming Service
──────────────                         ────────────────────────────            ─────────────────
secrets/db_password.txt         ───>   /run/secrets/db_password         ───>   mariadb, wordpress
secrets/db_root_password.txt    ───>   /run/secrets/db_root_password    ───>   mariadb
secrets/credentials.txt        ───>   /run/secrets/credentials        ───>   wordpress
```

1. **`secrets/db_password.txt`**: Contains the raw password for the MariaDB user (`MYSQL_USER`).
2. **`secrets/db_root_password.txt`**: Contains the raw password for MariaDB `root@localhost`.
3. **`secrets/credentials.txt`**: Formatted key-value file containing WordPress account passwords:
   ```text
   WP_ADMIN_PASSWORD=ntahadou_password
   WP_USER_PASSWORD=student_password
   ```

### 1.4 Host Domain Setup (`/etc/hosts`)
Map the domain name defined by `DOMAIN_NAME` (`ntahadou.42.fr`) to the local loopback address (`127.0.0.1`) on the host system:

```bash
sudo sh -c 'echo "127.0.0.1 ntahadou.42.fr" >> /etc/hosts'
```

Verify mapping:
```bash
ping -c 1 ntahadou.42.fr
```

---

## 2. Building and Launching the Project

This section explains the build pipeline, the orchestration manifest (`srcs/docker-compose.yml`), the `Makefile` target workflows, and the end-to-end container startup lifecycle.

### 2.1 Makefile Automation Interface
All compilation, container creation, execution, and cleanup operations are driven via the root `Makefile`.

```bash
# Complete build and launch sequence
make
```

#### Complete Makefile Target Reference

| Target | Executed Shell Commands | Purpose & Description |
| :--- | :--- | :--- |
| `all` | `$(MAKE) setup`, `$(MAKE) up` | Default target. Creates host directories and starts containers. |
| `setup` | `mkdir -p /home/ntahadou/data/mariadb /home/ntahadou/data/wordpress` | Creates persistent host volume directories before containers start. |
| `build` | `docker compose -f srcs/docker-compose.yml build` | Compiles Docker images for NGINX, WordPress, and MariaDB. |
| `up` | `docker compose -f srcs/docker-compose.yml up -d` | Starts all services in detached background mode. |
| `down` | `docker compose -f srcs/docker-compose.yml down` | Stops and removes running containers and virtual networks. |
| `stop` | `docker compose -f srcs/docker-compose.yml stop` | Pauses running containers without destroying container state. |
| `start` | `docker compose -f srcs/docker-compose.yml start` | Resumes paused containers. |
| `restart` | `docker compose -f srcs/docker-compose.yml restart` | Restarts all active containers. |
| `logs` | `docker compose -f srcs/docker-compose.yml logs` | Streams consolidated logs from all service containers. |
| `ps` | `docker compose -f srcs/docker-compose.yml ps` | Lists container status, uptime, and port bindings. |
| `clean` | `docker compose -f srcs/docker-compose.yml down -v` | Stops containers and removes networks and named Docker volumes. |
| `fclean` | `make clean`, `docker system prune -af`, `rm -rf /home/ntahadou/data/*` | **Full Purge**: Removes containers, networks, volumes, image caches, and host data directories. |
| `re` | `$(MAKE) fclean`, `$(MAKE) build`, `$(MAKE) up` | Performs a complete factory wipe and rebuilds the stack from scratch. |

---

### 2.2 Docker Compose Manifest Specification (`srcs/docker-compose.yml`)

The multi-container orchestration is defined in `srcs/docker-compose.yml` using Compose Specification v2.

```yaml
services:

  nginx:
    build:
      context: ./requirements/nginx
      dockerfile: Dockerfile
    container_name: nginx
    env_file:
      - .env
    depends_on:
      - wordpress
    ports:
      - "443:443"
    volumes:
      - wordpress_data:/var/www/html:ro
    networks:
      - inception
    restart: always

  mariadb:
    build:
      context: ./requirements/mariadb
      dockerfile: Dockerfile
    container_name: mariadb
    env_file:
      - .env
    secrets:
      - db_password
      - db_root_password
    volumes:
      - mariadb_data:/var/lib/mysql
    networks: 
      - inception
    restart: always
  
  wordpress:
    build:
      context: ./requirements/wordpress
      dockerfile: Dockerfile
    container_name: wordpress
    env_file:
      - .env
    secrets:
      - db_password
      - credentials
    environment:
      MYSQL_HOST: mariadb
    volumes:
      - wordpress_data:/var/www/html
    depends_on:
      - mariadb
    networks:
      - inception
    restart: always

volumes:
   mariadb_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/ntahadou/data/mariadb
   
   wordpress_data:
     driver: local
     driver_opts:
       type: none
       o: bind
       device: /home/ntahadou/data/wordpress

secrets:
  db_password:
    file: ../secrets/db_password.txt
  db_root_password:
    file: ../secrets/db_root_password.txt
  credentials:
    file: ../secrets/credentials.txt

networks:
  inception:
    driver: bridge
```

---

### 2.3 End-to-End Build & Execution Architecture

```text
Makefile (make)
   │
   ├── 1. Execute `make setup`: mkdir -p /home/ntahadou/data/mariadb /home/ntahadou/data/wordpress
   │
   └── 2. Execute `make up`: docker compose -f srcs/docker-compose.yml up -d
          │
          ├── Build Phase (docker compose build)
          │     ├── NGINX: debian:bookworm -> install nginx openssl gettext-base -> copy configs/entrypoint
          │     ├── WordPress: debian:bookworm -> install php8.2-fpm php8.2-mysql curl wp-cli -> copy entrypoint
          │     └── MariaDB: debian:bookworm -> install mariadb-server mariadb-client -> copy configs/entrypoint
          │
          ├── Network & Volume Phase
          │     ├── Create private bridge network: `inception`
          │     └── Mount local bind volumes: `mariadb_data` and `wordpress_data`
          │
          └── Container Execution Phase
                ├── 1. Start `mariadb` container -> Run `/usr/local/bin/init_db.sh` -> Hand off to `mariadbd` (PID 1)
                ├── 2. Start `wordpress` container -> Run `/usr/local/bin/setup.sh` -> Wait for DB -> Hand off to `php-fpm8.2` (PID 1)
                └── 3. Start `nginx` container -> Run `/usr/local/bin/generate-certificate.sh` -> Render config -> Hand off to `nginx` (PID 1)
```

---

## 3. Relevant Commands to Manage Containers and Volumes

This section provides a developer CLI reference for inspecting, debugging, entering, and managing running containers, virtual networks, and persistent storage volumes.

### 3.1 Container Management Commands

#### List Active & All Containers
```bash
# Using Makefile
make ps

# Using Docker CLI
docker ps
docker ps -a
```

#### Inspect Container Details & Configuration
```bash
docker inspect nginx
docker inspect wordpress
docker inspect mariadb
```

#### Execute Interactive Shell Inside Containers
```bash
# Open interactive shell in NGINX container
docker exec -it nginx sh

# Open interactive shell in WordPress container
docker exec -it wordpress sh

# Open interactive shell in MariaDB container
docker exec -it mariadb sh
```

#### Execute Direct Commands Inside Containers
```bash
# Query MariaDB database tables directly from inside MariaDB container
docker exec -it mariadb mariadb -u wp_user -p$(cat secrets/db_password.txt) wordpress -e "SHOW TABLES;"

# Check WP-CLI core status inside WordPress container
docker exec -it wordpress wp core check-update --allow-root --path=/var/www/html

# Test NGINX configuration syntax inside NGINX container
docker exec -it nginx nginx -t
```

#### Inspect Real-Time Container Logs
```bash
# Stream logs from all services simultaneously
make logs

# Stream logs from a single container
docker logs -f nginx
docker logs -f wordpress
docker logs -f mariadb
```

#### Rebuild & Recreate a Single Service
To modify code in one service (e.g. NGINX) and apply changes without restarting the rest of the stack:

```bash
docker compose -f srcs/docker-compose.yml build nginx
docker compose -f srcs/docker-compose.yml up -d --no-deps nginx
```

---

### 3.2 Volume Management Commands

#### List and Inspect Docker Volumes
```bash
# List all Docker volumes
docker volume ls

# Inspect MariaDB bind volume
docker volume inspect mariadb_data

# Inspect WordPress bind volume
docker volume inspect wordpress_data
```

#### Inspect Host Storage Directory Contents
```bash
# Inspect host MariaDB storage directory directly
ls -la /home/ntahadou/data/mariadb

# Inspect host WordPress site directory directly
ls -la /home/ntahadou/data/wordpress
```

#### Remove Named Docker Volumes
```bash
# Remove project volumes (Requires containers to be stopped first)
docker volume rm mariadb_data wordpress_data
```

---

### 3.3 Network Management Commands

#### Inspect Custom Docker Bridge Network
```bash
# Inspect IP assignments and connected containers in the `inception` network
docker network inspect inception
```

#### Inter-Container Connectivity Testing
```bash
# Test FastCGI TCP connectivity from NGINX container to WordPress container (Port 9000)
docker exec -it nginx nc -zv wordpress 9000

# Test MariaDB TCP connectivity from WordPress container to MariaDB container (Port 3306)
docker exec -it wordpress mariadb-admin --host=mariadb --user=wp_user --password=$(cat secrets/db_password.txt) ping
```

---

## 4. Identifying Where Project Data Is Stored and How It Persists

This section explains host bind mount mappings, storage driver options, and the distinction between container removal and data deletion.

### 4.1 Host Data Storage Locations

The project explicitly maps container storage directories to host filesystem paths via Docker's `local` volume driver using bind mounts.

```yaml
volumes:
   mariadb_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/ntahadou/data/mariadb
   
   wordpress_data:
     driver: local
     driver_opts:
       type: none
       o: bind
       device: /home/ntahadou/data/wordpress
```

#### Storage Mapping Matrix

| Volume Name | Host Directory Location | Container Mount Point | Service & Permissions | Data Stored |
| :--- | :--- | :--- | :--- | :--- |
| `mariadb_data` | `/home/ntahadou/data/mariadb` | `/var/lib/mysql` | `mariadb` container (`rw`) | MariaDB data files, InnoDB tablespaces (`ibdata1`), SQL schemas, user tables, and `.initialized` marker. |
| `wordpress_data` | `/home/ntahadou/data/wordpress` | `/var/www/html` | `wordpress` container (`rw`) | WordPress core files, `wp-config.php`, installed plugins, themes, and uploaded media (`wp-content/uploads/`). |
| `wordpress_data` | `/home/ntahadou/data/wordpress` | `/var/www/html` | `nginx` container (`ro`) | Mounted **read-only** so NGINX can serve static files (CSS, JS, images) directly without write access. |

---

### 4.2 How Data Persistence Works

1. **Host Bind Mount Isolation**: When a container writes to `/var/lib/mysql` or `/var/www/html`, the Linux kernel writes bytes directly to host directory paths `/home/ntahadou/data/mariadb` and `/home/ntahadou/data/wordpress`.
2. **Decoupled Lifecycle**: The lifespan of persistent data is completely independent of container state. If a container is stopped (`make stop`), killed (`docker kill`), or deleted (`make down` / `docker rm`), the host files remain untouched.
3. **Re-Attachment on Container Creation**: When a new container is instantiated (`make up`), Docker bind-mounts the pre-existing host directories. The entrypoint scripts detect existing initialization marker files (`/var/lib/mysql/.initialized` and `/var/www/html/wp-config.php`) and resume normal execution without overwriting data.

---

### 4.3 Comprehensive Lifecycle Data Persistence Matrix

| Operation | Command Executed | Container State | Image State | Host Storage (`/home/ntahadou/data/*`) | Data Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Stop Containers** | `make stop` | Stopped | Retained | Intact | **Preserved** |
| **Remove Containers** | `make down` | Destroyed | Retained | Intact | **Preserved** |
| **Rebuild Images** | `make build` | Recreated | Rebuilt | Intact | **Preserved** |
| **Process Crash** | `docker kill <container>` | Auto-restarted | Retained | Intact | **Preserved** |
| **Clean Docker Volumes**| `make clean` | Destroyed | Retained | Directories remain on host | **Preserved** |
| **Full Project Reset** | `make fclean` | Destroyed | Pruned | **Deleted (`rm -rf`)** | 🚨 **PERMANENTLY DELETED** |

---

### 4.4 Container Removal (`docker rm`) vs Volume Removal (`make fclean`)

```text
   CONTAINER REMOVAL (make down / docker rm)
   ┌──────────────────────────────────────────────────┐
   │ Destroys ephemeral container execution layer.     │
   │ Host bind directory (/home/ntahadou/data) remains.│
   │ RESULT: Zero data loss.                          │
   └──────────────────────────────────────────────────┘

                           VS

   VOLUME REMOVAL & PURGE (make fclean / rm -rf)
   ┌──────────────────────────────────────────────────┐
   │ Removes host data directories on physical disk.  │
   │ Deletes database files and uploaded media.       │
   │ RESULT: Total permanent loss of site content.    │
   └──────────────────────────────────────────────────┘
```

---

## 5. Technical Service Internals & Startup Routines

### 5.1 NGINX Internals & TLS Generation (`generate-certificate.sh`)

1. **Environment Substitution**: Replaces `${DOMAIN_NAME}` in `/etc/nginx/nginx.conf.template` to output `/etc/nginx/nginx.conf`.
2. **OpenSSL TLS Certificate Generation**: If `/etc/nginx/ssl/server.crt` or `server.key` is missing:
   ```bash
   openssl req -x509 \
       -nodes \
       -days 365 \
       -newkey rsa:2048 \
       -keyout /etc/nginx/ssl/server.key \
       -out /etc/nginx/ssl/server.crt \
       -subj "/C=MA/ST=Casablanca/L=Casablanca/O=Inception/OU=IT/CN=${DOMAIN_NAME}"
   ```
3. **Permissions**: Key file is set to `chmod 600`; certificate is set to `chmod 644`.
4. **PID 1 Handoff**: `exec nginx -g "daemon off;"`.

---

### 5.2 WordPress & PHP-FPM Internals (`setup.sh`)

1. **Admin Username Check**: Evaluates `$WP_ADMIN_USER` using glob matching:
   ```sh
   case "$WP_ADMIN_USER" in
       *admin*|*Admin*|*ADMIN*|*administrator*|*Administrator*|*ADMINISTRATOR*)
           echo "Error: administrator username cannot contain 'admin'."
           exit 1 ;;
   esac
   ```
2. **MariaDB Wait Loop**: Polls database port using `mariadb-admin ping` until active.
3. **Core Installation**: Downloads `latest.tar.gz`, creates `wp-config.php`, and runs `wp core install` and `wp user create` via WP-CLI.
4. **PHP-FPM Pool Binding**: Updates `/etc/php/8.2/fpm/pool.d/www.conf` to set `listen = 0.0.0.0:9000`.
5. **PID 1 Handoff**: `exec php-fpm8.2 -F`.

---

### 5.3 MariaDB Internals (`init_db.sh`)

1. **System DB Install**: Runs `mariadb-install-db --user=mysql --datadir=/var/lib/mysql` if empty.
2. **Temporary Background Boot**: Launches `mariadbd --skip-networking --socket=/run/mysqld/mysqld.sock &`.
3. **SQL Privilege Setup**: Executes `CREATE DATABASE`, `CREATE USER`, `GRANT ALL PRIVILEGES`, and updates `root@localhost` password.
4. **Initialization Marker**: Creates sentinel file `/var/lib/mysql/.initialized`.
5. **Shutdown & PID 1 Handoff**: Gracefully shuts down temporary daemon (`mariadb-admin shutdown`) and executes `exec mariadbd --user=mysql --datadir=/var/lib/mysql`.
