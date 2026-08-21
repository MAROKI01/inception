*This project has been created as part of the 42 curriculum by ntahadou.*

# Inception — System Administration & Containerization Project

![Docker](https://img.shields.io/badge/Docker-24.0+-2496ED?style=for-the-badge\&logo=docker\&logoColor=white)
![Docker Compose](https://img.shields.io/badge/Docker_Compose-v2+-2496ED?style=for-the-badge\&logo=docker\&logoColor=white)
![Debian](https://img.shields.io/badge/Debian-Bookworm-A81D33?style=for-the-badge\&logo=debian\&logoColor=white)
![NGINX](https://img.shields.io/badge/NGINX-TLS_1.2%2F1.3-009639?style=for-the-badge\&logo=nginx\&logoColor=white)
![WordPress](https://img.shields.io/badge/WordPress-PHP_8.2--FPM-21759B?style=for-the-badge\&logo=wordpress\&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB-10.x-003545?style=for-the-badge\&logo=mariadb\&logoColor=white)

---

## 1. Description

### Project Overview & Goal

**Inception** is a system administration and DevOps project at **42 School**. The goal is to build a small multi-container infrastructure using **Docker** and **Docker Compose**, with each required service running in its own container.

The infrastructure consists of three mandatory core services:

1. **NGINX**: Public-facing web server and reverse proxy handling HTTPS traffic with **TLS v1.2 / TLS v1.3** on port `443`.
2. **WordPress + PHP-FPM**: Web application responsible for running WordPress and processing PHP requests through PHP-FPM.
3. **MariaDB**: Relational database server storing WordPress data and accessible only through the internal Docker network.

### Use of Docker & Project Sources

The project uses **Docker** to create isolated and reproducible environments for each service. Every required service is built from a custom `Dockerfile` located under `srcs/requirements/`.

* `srcs/requirements/nginx/`: Contains the NGINX Dockerfile, configuration files, and certificate-generation/startup scripts.
* `srcs/requirements/wordpress/`: Contains the WordPress Dockerfile, PHP-FPM configuration, WP-CLI, and WordPress initialization scripts.
* `srcs/requirements/mariadb/`: Contains the MariaDB Dockerfile, server configuration, and database initialization scripts.

### Main Design Choices

* **Debian Bookworm Base Image**: Used as the base distribution for the service images.
* **Single Responsibility**: NGINX, WordPress/PHP-FPM, and MariaDB run in separate containers.
* **Security**: HTTPS is provided by NGINX, while MariaDB and PHP-FPM remain accessible only through the internal Docker network.
* **Persistent Storage**: WordPress files and MariaDB data are stored using persistent host-backed storage.
* **Automation**: Entry-point and initialization scripts automate service configuration, certificate generation, database initialization, and WordPress installation.

---

### Architectural Comparisons

#### 1. Virtual Machines vs Docker

| Parameter                | Virtual Machines (VMs)                                  | Docker Containers                                                             |
| :----------------------- | :------------------------------------------------------ | :---------------------------------------------------------------------------- |
| **Virtualization Level** | Hardware virtualization through a hypervisor.           | OS-level virtualization / containerization.                                   |
| **Kernel Usage**         | Each VM runs its own guest operating system and kernel. | Containers share the host operating system kernel.                            |
| **Resource Overhead**    | Higher because each VM includes a complete guest OS.    | Generally lower because containers share the host kernel.                     |
| **Startup Time**         | Usually slower because a complete OS must boot.         | Usually faster because a container starts its application processes directly. |
| **Isolation**            | Strong isolation with separate guest operating systems. | Process and namespace isolation provided by the container runtime.            |

#### 2. Secrets vs Environment Variables

| Parameter             | Environment Variables (`.env`)                                       | Docker Secrets (`/run/secrets/`)                             |
| :-------------------- | :------------------------------------------------------------------- | :----------------------------------------------------------- |
| **Storage Mechanism** | Key-value configuration passed through the environment.              | Secret values are provided to containers as files.           |
| **Typical Usage**     | Non-sensitive configuration such as domain names and database names. | Sensitive values such as database passwords and credentials. |
| **Access**            | Can be visible through container environment inspection.             | Read by applications from the mounted secret files.          |
| **Project Usage**     | Used for ordinary configuration parameters.                          | Used for sensitive credentials.                              |

#### 3. Docker Network vs Host Network

| Parameter             | Docker Network (Bridge)                                                    | Host Network (`network_mode: host`)                         |
| :-------------------- | :------------------------------------------------------------------------- | :---------------------------------------------------------- |
| **Isolation**         | Containers communicate through an isolated Docker network.                 | Containers share the host network namespace.                |
| **Port Exposure**     | Only explicitly published ports are exposed to the host.                   | Containers use the host network directly.                   |
| **Service Discovery** | Docker provides internal DNS using service names.                          | Containers communicate through the host network.            |
| **Security**          | Internal services can remain inaccessible from outside the Docker network. | Services can potentially expose ports directly on the host. |

#### 4. Docker Volumes vs Bind Mounts

| Parameter               | Docker-managed Named Volumes                                                    | Bind Mounts                                                                                 |
| :---------------------- | :------------------------------------------------------------------------------ | :------------------------------------------------------------------------------------------ |
| **Storage Location**    | Managed by Docker.                                                              | Explicit host filesystem path.                                                              |
| **Host Interaction**    | Managed through Docker's volume system.                                         | Files are directly visible on the host.                                                     |
| **Control & Lifecycle** | Docker manages the volume lifecycle.                                            | The host directory determines the storage location.                                         |
| **Inception Usage**     | The project uses Docker volume definitions configured with host-backed storage. | Persistent WordPress and MariaDB data is stored under the configured host data directories. |

---

## 2. Architecture & Infrastructure

The architecture follows a standard multi-tier infrastructure where NGINX acts as the sole public gateway receiving encrypted HTTPS traffic, forwarding PHP requests to WordPress through FastCGI. WordPress communicates with MariaDB through the internal Docker network.

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
|              | WordPress files                      | MySQL Protocol               |
|              |                                      | (Port 3306)                  |
|              v                                      v                             |
|  +-----------------------+              +-----------------------+                 |
|  | Persistent WordPress  |              | MARIADB               |                 |
|  | data                  |              | (container: mariadb)  |                 |
|  | /var/www/html         |              |                       |                 |
|  +-----------------------+              | Database storage      |                 |
|                                         +-----------+-----------+                 |
|                                                     |                             |
|                                                     | Persistent storage          |
|                                                     v                             |
|                                         +-----------------------+                 |
|                                         | MariaDB data          |                 |
|                                         | /var/lib/mysql        |                 |
|                                         +-----------------------+                 |
+-----------------------------------------------------------------------------------+
```

---

## 3. Instructions

### Prerequisites

The project requires:

1. **Linux** operating system.
2. **Docker Engine** installed and running.
3. **Docker Compose v2**.
4. **Make**.

### Host Domain Resolution (`/etc/hosts`)

The project domain is:

```text
ntahadou.42.fr
```

Map it to the local machine in `/etc/hosts`:

```bash
sudo sh -c 'echo "127.0.0.1 ntahadou.42.fr" >> /etc/hosts'
```

Verify the mapping:

```bash
getent hosts ntahadou.42.fr
```

### Installation, Compilation & Execution

From the root of the repository:

```bash
make
```

The Makefile prepares the required persistent-data directories, builds the Docker images, and starts the infrastructure.

### Available Management Commands

| Command        | Description                                                             |
| :------------- | :---------------------------------------------------------------------- |
| `make`         | Creates required data directories and launches the infrastructure.      |
| `make build`   | Builds or rebuilds the Docker images.                                   |
| `make up`      | Starts all services in detached mode.                                   |
| `make down`    | Stops and removes the project containers and network.                   |
| `make start`   | Starts existing stopped containers.                                     |
| `make stop`    | Stops running containers without removing them.                         |
| `make restart` | Restarts the services.                                                  |
| `make logs`    | Displays service logs.                                                  |
| `make ps`      | Displays the status of the project containers.                          |
| `make clean`   | Stops the infrastructure and removes project volumes.                   |
| `make fclean`  | Performs a complete project cleanup, including persistent project data. |
| `make re`      | Performs a complete cleanup and rebuilds the infrastructure.            |

> **Warning:** `make fclean` removes persistent project data. Use it only when a complete reset is intended.

---

## 4. Accessing the Application

### Website

```text
https://ntahadou.42.fr
```

### WordPress Administration

```text
https://ntahadou.42.fr/wp-admin
```

### Accounts

The administrator and additional WordPress user credentials are stored in the project's secret files.

Do not publish passwords or other sensitive credentials in this README.

### Additional Documentation

For detailed user instructions, testing, and troubleshooting, see:

* `USER_DOC.md`

For technical implementation details, debugging information, and development notes, see:

* `DEV_DOC.md`

---

## 5. 42 Inception Requirements Compliance

| 42 Subject Requirement                   | Status    | Implementation                                                              |
| :--------------------------------------- | :-------- | :-------------------------------------------------------------------------- |
| **Debian Bookworm base image**           | Compliant | Required service images use Debian Bookworm as their base image.            |
| **Docker Compose orchestration**         | Compliant | Infrastructure is managed through `srcs/docker-compose.yml`.                |
| **Dedicated container per service**      | Compliant | NGINX, WordPress/PHP-FPM, and MariaDB run in separate containers.           |
| **NGINX with TLS v1.2 / v1.3**           | Compliant | NGINX is configured for HTTPS using TLS 1.2 and TLS 1.3.                    |
| **WordPress + PHP-FPM**                  | Compliant | WordPress runs with PHP-FPM in its dedicated container.                     |
| **MariaDB container**                    | Compliant | MariaDB runs in its own dedicated container.                                |
| **Persistent storage**                   | Compliant | WordPress and MariaDB data are stored using persistent host-backed storage. |
| **Custom Docker network**                | Compliant | Services communicate through the project's Docker bridge network.           |
| **Automatic restart**                    | Compliant | Services are configured with the required restart policy.                   |
| **Domain format**                        | Compliant | The project uses `ntahadou.42.fr`.                                          |
| **Sensitive credentials**                | Compliant | Database credentials are supplied through the project's secret mechanism.   |
| **WordPress administrator restrictions** | Compliant | The WordPress setup prevents the use of forbidden administrator usernames.  |

---

## 6. Resources & AI Usage

### Classic References & Technical Documentation

The following documentation was consulted during the development and debugging of the project:

* [Docker Documentation](https://docs.docker.com/?utm_source=chatgpt.com)
* [Docker Compose Documentation](https://docs.docker.com/compose/?utm_source=chatgpt.com)
* [Debian Documentation](https://www.debian.org/doc/?utm_source=chatgpt.com)
* [NGINX Documentation](https://nginx.org/en/docs/?utm_source=chatgpt.com)
* [MariaDB Documentation](https://mariadb.com/docs/?utm_source=chatgpt.com)
* [WordPress Developer Resources](https://developer.wordpress.org/?utm_source=chatgpt.com)
* [WP-CLI Documentation](https://developer.wordpress.org/cli/?utm_source=chatgpt.com)
* [OpenSSL Documentation](https://www.openssl.org/docs/?utm_source=chatgpt.com)

### Artificial Intelligence (AI) Usage Declaration

AI tools were used as an auxiliary learning, debugging, and documentation resource during the development of this project.

AI assistance was used for:

1. **Technical Understanding**

   * Understanding Docker and Docker Compose concepts.
   * Understanding Docker networks, volumes, ports, and service dependencies.
   * Explaining NGINX, PHP-FPM, WordPress, and MariaDB interactions.

2. **Debugging**

   * Investigating Docker and Docker Compose errors.
   * Troubleshooting service startup and restart problems.
   * Investigating WordPress-to-MariaDB connectivity issues.
   * Reviewing configuration and shell-script behavior.

3. **Requirement Review**

   * Reviewing the implementation against the Inception subject requirements.
   * Identifying missing tests or documentation.
   * Preparing explanations for the project defense.

4. **Documentation**

   * Improving the structure and clarity of `README.md`, `USER_DOC.md`, and `DEV_DOC.md`.
   * Helping explain technical concepts and project architecture.

AI suggestions were reviewed, adapted, and tested against the actual project implementation. The final configuration, scripts, and infrastructure were manually verified.

AI was used as a **learning and development assistant**, not as a replacement for understanding the project's implementation.

---

## Documentation

This repository also contains:

### `USER_DOC.md`

Provides user-oriented instructions covering:

* Starting and stopping the infrastructure.
* Accessing WordPress.
* Basic testing.
* Common troubleshooting procedures.

### `DEV_DOC.md`

Provides technical information covering:

* Project architecture.
* Docker configuration.
* Service configuration.
* Initialization scripts.
* Networking.
* Volumes and persistence.
* Debugging and development procedures.

---

## Conclusion

The project demonstrates the use of Docker and Docker Compose to create an isolated, persistent, and reproducible multi-service infrastructure.

The three required services—**NGINX**, **WordPress/PHP-FPM**, and **MariaDB**—are separated into individual containers and communicate through a dedicated Docker network, while persistent storage keeps application and database data independent from container lifecycles.
