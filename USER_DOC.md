# Inception — User & Operator Manual (`USER_DOC.md`)

This guide is written for **users, system administrators, evaluators, and 42 reviewers** who need to install, configure, operate, test, and troubleshoot the **Inception** infrastructure without needing to dive into complex source code internals.

---

## 1. Introduction

### What the Project Provides
The **Inception** infrastructure delivers a fully functional, containerized **WordPress web application** powered by a secure **NGINX** web server and an isolated **MariaDB** relational database.

After starting the project, you will get:
- A secure, encrypted website accessible via HTTPS (`https://ntahadou.42.fr`).
- A fully installed WordPress Content Management System (CMS) with pre-configured administrator and subscriber accounts.
- Persistent data storage for website files, themes, media, and database tables.
- Automated service management that keeps all components running continuously.

### Available Services

```text
               +-------------------------------------------------+
               |                    USER / BROWSER               |
               |             (https://ntahadou.42.fr:443)        |
               +-----------------------+-------------------------+
                                       |
                                       | Encrypted HTTPS (Port 443)
                                       v
               +-------------------------------------------------+
               | NGINX Web Server                                |
               | Container: nginx                                |
               | Role: Secure Public Gateway                     |
               +-----------------------+-------------------------+
                                       |
                                       | Internal FastCGI (Port 9000)
                                       v
               +-------------------------------------------------+
               | WordPress + PHP-FPM                             |
               | Container: wordpress                            |
               | Role: Application Engine & CMS                  |
               +-----------------------+-------------------------+
                                       |
                                       | Internal Database Protocol (Port 3306)
                                       v
               +-------------------------------------------------+
               | MariaDB Database                                |
               | Container: mariadb                              |
               | Role: Isolated Data Store                       |
               +-------------------------------------------------+
```

---

## 2. Requirements

Before installing and operating the infrastructure, ensure your system meets the following prerequisites:

### Hardware & Operating System
- **OS**: Linux (Debian 11/12 or Ubuntu 20.04/22.04/24.04 recommended).
- **RAM**: Minimum 2 GB RAM.
- **Disk Space**: At least 5 GB free disk space.

### Software Dependencies
- **Docker Engine**: Version 24.0+ installed and running (`docker --version`).
- **Docker Compose**: Plugin v2.0+ installed (`docker compose version`).
- **GNU Make**: Utility installed (`make --version`).

### Privileges & Host Configuration
- **Sudo / Root Access**: Required to configure the host domain name in `/etc/hosts` and to manage Docker permissions if your user is not in the `docker` group.
- **Host Domain Mapping**: The domain `ntahadou.42.fr` must resolve to local loopback (`127.0.0.1`).
- **Port Availability**: Port `443` (HTTPS) must be free on your host machine.

---

## 3. Installation Step-by-Step

Follow these exact steps to deploy the application from scratch:

### Step 1: Navigate to Project Directory
Open a terminal and enter the project repository directory:

```bash
cd /path/to/inception
```

### Step 2: Configure Local Host Resolution (`/etc/hosts`)
Map the domain name `ntahadou.42.fr` to your local machine address (`127.0.0.1`) in `/etc/hosts`:

```bash
sudo sh -c 'echo "127.0.0.1 ntahadou.42.fr" >> /etc/hosts'
```

Verify that the mapping is working:
```bash
ping -c 1 ntahadou.42.fr
```

### Step 3: Verify Environment and Secrets Files
Check that configuration files exist:
- `srcs/.env` (Environment variables)
- `secrets/db_password.txt` (MariaDB user password)
- `secrets/db_root_password.txt` (MariaDB root password)
- `secrets/credentials.txt` (WordPress accounts passwords)

### Step 4: Build and Launch the Application
Run the default `make` command:

```bash
make
```

**What this command does**:
1. Creates host data storage directories (`/home/ntahadou/data/mariadb` and `/home/ntahadou/data/wordpress`).
2. Builds custom Docker images for NGINX, WordPress, and MariaDB.
3. Launches all 3 containers in the background (`docker compose up -d`).

---

## 4. Configuration Reference

All user-configurable variables are managed in `srcs/.env` and secret text files in `secrets/`.

### 1. Environment Variables (`srcs/.env`)

| Variable | Purpose | Editable? | Notes / Restrictions |
| :--- | :--- | :--- | :--- |
| `DOMAIN_NAME` | Website domain name | Yes | Must match the entry in `/etc/hosts` (default: `ntahadou.42.fr`). |
| `WP_TITLE` | WordPress website title | Yes | Displayed in website header (default: `Inception`). |
| `WP_ADMIN_USER` | WordPress admin username | Yes | **Cannot** contain `admin` or `administrator` (e.g. `ntahadou`). |
| `WP_ADMIN_EMAIL` | Admin email address | Yes | Example: `ntahadou@example.com`. |
| `WP_USER` | Second user account name | Yes | Default: `student`. |
| `WP_USER_EMAIL` | Second user email | Yes | Example: `student@example.com`. |
| `MYSQL_DATABASE` | Database name | Advanced | Default: `wordpress`. |
| `MYSQL_USER` | Standard DB username | Advanced | Default: `wp_user`. |

### 2. Secret Files (`secrets/`)

> ⚠️ **Security Warning**: Never share or publish actual password files.

- `secrets/db_password.txt`: Contains the password for `MYSQL_USER` (e.g. `YOUR_DB_PASSWORD`).
- `secrets/db_root_password.txt`: Contains the MariaDB `root` password (e.g. `YOUR_ROOT_PASSWORD`).
- `secrets/credentials.txt`: Contains WordPress account passwords:
  ```text
  WP_ADMIN_PASSWORD=YOUR_ADMIN_PASSWORD
  WP_USER_PASSWORD=YOUR_USER_PASSWORD
  ```

---

## 5. Starting the Application

To start the infrastructure, run:

```bash
make
```
or if the containers have already been built:

```bash
make start
```

### What to Expect Upon Starting
- The terminal will display:
  ```text
  mkdir -p /home/ntahadou/data/mariadb
  mkdir -p /home/ntahadou/data/wordpress
  docker compose -f srcs/docker-compose.yml up -d
  ```
- On the first start, database initialization and WordPress installation take **10 to 20 seconds** in the background.

---

## 6. Accessing the Website

Once containers show status `Up`, access the web application through your browser:

### 1. Main Website (Frontend)
- **URL**: `https://ntahadou.42.fr`
- **Protocol**: HTTPS (Port 443)

### 2. WordPress Administration Panel
- **URL**: `https://ntahadou.42.fr/wp-admin`
- **Login Page**: `https://ntahadou.42.fr/wp-login.php`

---

## 7. First Use & Account Credentials

After launching the site for the first time, log into the WordPress dashboard:

1. Open `https://ntahadou.42.fr/wp-admin` in your browser.
2. Log in using the administrator credentials configured during setup:
   - **Username**: `ntahadou` *(configured via `WP_ADMIN_USER`)*
   - **Password**: *(Password defined in `secrets/credentials.txt`)*
3. **Verify Pre-configured Subscriber Account**:
   - Go to **Users -> All Users** in the dashboard.
   - Confirm the existence of the secondary user `student` (`WP_USER`).
4. **Publish Test Content**:
   - Create a post or page to verify dynamic PHP execution and MariaDB database write access.

---

## 8. Managing the Application

All routine management operations are performed using simple `make` commands:

### Start Services
Starts existing stopped containers:
```bash
make start
```

### Stop Services
Stops running containers without destroying persistent data:
```bash
make stop
```

### Restart Services
Restarts all running containers:
```bash
make restart
```

### Rebuild Images
Rebuilds Docker images after configuration changes:
```bash
make build
```

### Check Status
Displays the running status of containers:
```bash
make ps
```
*Output should show containers `nginx`, `wordpress`, and `mariadb` running.*

### Inspect Service Logs
Streams live log output from all services:
```bash
make logs
```

To view logs for a specific container:
```bash
docker logs nginx
docker logs wordpress
docker logs mariadb
```

---

## 9. Updating Configuration

If you modify configuration files (`.env`, templates, or secret files), follow the appropriate workflow:

```text
Modify File (.env / template / secrets)
                  ↓
          Rebuild / Recreate
                  ↓
       Restart Application (`make re`)
                  ↓
          Verify Application
```

### When to Restart vs Rebuild

- **Simple Service Restart (`make restart`)**:
  - Useful when restarting after a temporary process halt.
- **Rebuild and Recreate (`make build` followed by `make up`, or `make re`)**:
  - Required when editing `.env`, secret files, Dockerfiles, or NGINX template files.

---

## 10. Data Persistence

The application guarantees that your data is stored safely on the host system.

### Where Data is Stored
- **Database Tables**: Stored in host path `/home/ntahadou/data/mariadb`.
- **Website Files & Uploads**: Stored in host path `/home/ntahadou/data/wordpress`.

### Data Survival Matrix

```text
Removing Container (make down)  ──> Data SURVIVES in host directories
Rebuilding Images (make build) ──> Data SURVIVES in host directories
Restarting Host Machine         ──> Data SURVIVES in host directories
Running `make fclean`           ──> Data IS DELETED (Full Purge)
```

> 🚨 **Crucial Concept**: Deleting a Docker container (`docker rm`) does **NOT** delete your WordPress posts or database. However, running `make fclean` deletes the host directories `/home/ntahadou/data/*`, permanently removing all database records and website uploads!

---

## 11. Backups and Data Safety

> ⚠️ **Notice**: Automated backups are **not** provided out of the box by this repository.

To back up your data manually:
1. Stop the application:
   ```bash
   make stop
   ```
2. Archive the host data directory:
   ```bash
   tar -czvf inception_backup.tar.gz /home/ntahadou/data
   ```
3. Restart the application:
   ```bash
   make start
   ```

---

## 12. HTTPS & Security Information

### Self-Signed Certificate Warning
When accessing `https://ntahadou.42.fr`, your browser will display a security alert:
`"Your connection is not private"` or `"Warning: Potential Security Risk Ahead"`.

**Why this happens**:
- The project generates a custom SSL/TLS certificate dynamically signed by an internal authority (OpenSSL self-signed certificate).
- Browsers do not recognize local self-signed certificates by default.

**How to proceed**:
- In Chrome / Edge: Click **Advanced** -> Click **Proceed to ntahadou.42.fr (unsafe)**.
- In Firefox: Click **Advanced** -> Click **Accept the Risk and Continue**.

*Note: This warning is expected behavior in a development/evaluation environment and does not mean your server is compromised.*

---

## 13. Practical Troubleshooting Guide

### Problem 1: Website Does Not Open (`Connection Refused`)
- **Check 1**: Verify `/etc/hosts` contains `127.0.0.1 ntahadou.42.fr`.
- **Check 2**: Ensure containers are running:
  ```bash
  make ps
  ```
- **Check 3**: If containers are stopped, run `make up`.

### Problem 2: Port 443 Already in Use (`bind: address already in use`)
- **Cause**: Another web server (e.g. Apache, host NGINX) is running on the host system.
- **Solution**: Stop host web services:
  ```bash
  sudo systemctl stop nginx
  sudo systemctl stop apache2
  ```

### Problem 3: `Error Establishing a Database Connection`
- **Cause**: MariaDB container is still initializing or secret credentials mismatch.
- **Solution**:
  1. Inspect MariaDB logs:
     ```bash
     docker logs mariadb
     ```
  2. Wait 10 seconds for MariaDB to complete bootstrap.
  3. Verify `secrets/db_password.txt` has matching content.

### Problem 4: WordPress Administrator Login Fails
- **Cause**: Wrong password or invalid username.
- **Solution**: Check `WP_ADMIN_USER` in `srcs/.env` and `WP_ADMIN_PASSWORD` in `secrets/credentials.txt`.

### Problem 5: Admin Username Rejected on Startup (`administrator username cannot contain 'admin'`)
- **Cause**: `WP_ADMIN_USER` in `srcs/.env` contains `admin` or `administrator`.
- **Solution**: Change `WP_ADMIN_USER` in `srcs/.env` to a custom string (e.g., `ntahadou`), then run `make re`.

---

## 14. Operational Verification Checklist

Use this checklist during an evaluation or after installation:

- [ ] **Domain Setup**: `/etc/hosts` maps `127.0.0.1` to `ntahadou.42.fr`.
- [ ] **Containers Status**: Running `make ps` shows `nginx`, `wordpress`, and `mariadb` with status `Up`.
- [ ] **HTTPS Access**: Navigating to `https://ntahadou.42.fr` opens the site over port `443`.
- [ ] **TLS Enforcement**: `openssl s_client -connect ntahadou.42.fr:443 -tls1_3` succeeds.
- [ ] **WordPress Administration**: Login to `https://ntahadou.42.fr/wp-admin` succeeds.
- [ ] **Database Connection**: WordPress reads/writes posts into MariaDB without errors.
- [ ] **Data Persistence**: Executing `make down` followed by `make up` preserves created WordPress posts.
- [ ] **Crash Recovery**: Running `docker kill nginx` results in Docker auto-restarting the container within seconds.

---

## 15. Command Quick Reference Table

| Goal | Command | Description |
| :--- | :--- | :--- |
| **Start Infrastructure** | `make` or `make up` | Creates directories and launches containers in detached mode. |
| **Stop Infrastructure** | `make down` | Stops and removes containers/networks without deleting data. |
| **Halt Containers** | `make stop` | Pauses running containers. |
| **Resume Containers** | `make start` | Resumes stopped containers. |
| **Restart Infrastructure** | `make restart` | Restarts all containers. |
| **Rebuild Images** | `make build` | Rebuilds Docker images from Dockerfiles. |
| **Check Container Status** | `make ps` | Lists container status and port mappings. |
| **View Infrastructure Logs** | `make logs` | Streams real-time logs from all containers. |
| **Safe Data Cleanup** | `make clean` | Removes containers, networks, and named volumes. |
| **Complete Purge** | `make fclean` | **Destructive**: Removes containers, images, and host data directories. |
| **Fresh Deployment** | `make re` | Performs `fclean` followed by `make`. |

---

## 16. Reset & Cleanup Operations

### Safe Cleanup (Preserves Your Website Data)
To remove running containers and virtual networks while **keeping** your database and WordPress uploads intact:

```bash
make clean
```

### 🚨 Destructive Cleanup (Deletes All Application Data)

> ⚠️ **WARNING**: Executing `make fclean` will permanently delete all WordPress content, users, and database tables stored in `/home/ntahadou/data/`!

To perform a complete factory reset:

```bash
make fclean
```

**What `make fclean` deletes**:
1. Stops and removes all containers.
2. Removes project Docker networks and volumes.
3. Purges cached Docker images (`docker system prune -af`).
4. Executes `rm -rf /home/ntahadou/data/mariadb /home/ntahadou/data/wordpress`.

---

## 17. User FAQ

#### Q: How do I open the website?
Open your web browser and go to `https://ntahadou.42.fr`. Ensure you added the domain to `/etc/hosts`.

#### Q: How do I log into WordPress administration?
Go to `https://ntahadou.42.fr/wp-admin` and enter the credentials configured in `srcs/.env` and `secrets/credentials.txt`.

#### Q: Why does my browser show a certificate security warning?
The server uses a self-signed TLS certificate generated for local testing. Click **Advanced** and proceed to the site.

#### Q: Will my website content be deleted if I stop the containers?
No. Stopping containers (`make stop` or `make down`) does not delete data. Data is only deleted if you run `make fclean`.

#### Q: What happens if my computer restarts?
Because all services specify `restart: always`, Docker will automatically start the containers when the system reboots and the Docker daemon starts.

---

## 18. 42 Evaluation & Demonstration Guide

During evaluation, follow this sequence to demonstrate project compliance:

### 1. Demonstrate Service Status
Execute:
```bash
make ps
```
*Show the evaluator that `nginx`, `wordpress`, and `mariadb` are all running.*

### 2. Demonstrate HTTPS & TLS Security
Execute:
```bash
openssl s_client -connect ntahadou.42.fr:443 -tls1_2 < /dev/null
openssl s_client -connect ntahadou.42.fr:443 -tls1_3 < /dev/null
```
*Demonstrate that TLS 1.2 and TLS 1.3 handshakes succeed.*

### 3. Demonstrate WordPress Web Application
- Open `https://ntahadou.42.fr` in the browser.
- Log into `https://ntahadou.42.fr/wp-admin`.
- Create a new blog post.

### 4. Demonstrate Data Persistence
1. Run `make down`.
2. Show that containers are removed: `docker ps -a`.
3. Run `make up`.
4. Refresh `https://ntahadou.42.fr` — show that the blog post created earlier is still present.

### 5. Demonstrate Service Crash Recovery
1. Run `docker kill nginx`.
2. Immediately run `docker ps`.
3. Show that Docker automatically restarts the container (`restart: always`).

### 6. Standard Port Modification Evaluation Procedure
If asked to change a service configuration (e.g. changing an internal port or environment variable):
1. Edit the target configuration file (`srcs/.env`, `docker-compose.yml`, or configuration templates).
2. Stop and rebuild the stack:
   ```bash
   make re
   ```
3. Run `make ps` to confirm the service is operational.
4. Verify application responsiveness at `https://ntahadou.42.fr`.

---

## 19. Known Limitations

- **Hardcoded Storage Location**: Data paths `/home/ntahadou/data/mariadb` and `/home/ntahadou/data/wordpress` are set specifically to match the project login path.
- **Port 80 Inactive**: The server listens exclusively on HTTPS (port 443). Entering `http://ntahadou.42.fr` (without `https://`) will not connect.
