# Docker Cheat-Sheet — terminology & commands

A general Docker reference with TrustBank-CBS examples where useful. For *what this repo has*, see [my-docker-setup.md](my-docker-setup.md).

---

## 1. Core terminology

| Term | What it is |
|------|------------|
| **Image** | A read-only, layered template (your compiled app + runtime + OS libs). Built once, run many times. Identified by `repository:tag` (e.g. `cbs-gateway:latest`) or an image ID/SHA. |
| **Container** | A **running (or stopped) instance** of an image — image + a writable layer + its own process, network, and mounts. Many containers can run from one image. |
| **Layer** | Each Dockerfile instruction (`RUN`, `COPY`, …) adds a cached layer. Unchanged layers are reused → fast rebuilds. Order instructions least- to most-frequently-changing. |
| **Dockerfile** | The recipe to build an image (base image, copy files, build, entrypoint). |
| **Build context** | The directory sent to the builder (everything the `COPY` commands can see). Kept small via `.dockerignore`. Here it's the solution root. |
| **ARG** vs **ENV** | `ARG` = **build-time** variable (e.g. `PROJECT`), only during `docker build`. `ENV` = **runtime** variable, present in the running container. |
| **Registry / repository / tag** | Registry = image store (Docker Hub, ACR…). Repository = a named image (`cbs-gateway`). Tag = a version label (`latest`, `1.0`). |
| **Volume** | Docker-managed persistent storage that outlives a container. |
| **Bind mount** | Maps a **host path** into the container (e.g. `./docker/x.json:/app/x.json`). Edits on the host are visible in the container. |
| **Network** | A virtual network containers attach to. On a user-defined/compose network, containers reach each other by **service name** (built-in DNS). |
| **Port publishing** | `-p host:container` (or compose `ports:`) exposes a container port on the host. Without it, a port is only reachable *inside* the container's network. |
| **Healthcheck** | A command Docker runs periodically to mark a container `healthy`/`unhealthy` (here: `curl /health/ready`). |
| **ENTRYPOINT / CMD** | The process a container runs at start. |
| **Compose** | A tool + YAML file to define and run **multi-container** apps (`services`, `networks`, `volumes`) as one unit. |
| **Service** (compose) | One container spec in a compose file (image/build, env, ports, …). Can scale to multiple replicas. |
| **Project** (compose) | A group of services managed together; namespaces container/network names (here `tflcbsnet10sol`). |

---

## 2. Image commands

| Command | Purpose |
|---------|---------|
| `docker build -t name:tag .` | Build an image from the `Dockerfile` in `.` (the context). |
| `docker build --build-arg PROJECT=TflCbs.Host.Hr -t cbs-hr:latest .` | Build passing a build-time `ARG`. |
| `docker images` | List local images (repo, tag, size, ID). |
| `docker image inspect name:tag` | Full metadata (layers, env, entrypoint). |
| `docker history name:tag` | Show the layers and their sizes. |
| `docker tag src:tag new:tag` | Add another name/tag to an image. |
| `docker pull image:tag` / `docker push …` | Download from / upload to a registry. |
| `docker image rm name:tag` (`docker rmi`) | Delete an image. |
| `docker image prune` | Remove dangling (untagged) images. |

## 3. Container commands

| Command | Purpose |
|---------|---------|
| `docker run -d -p 8090:8080 --name x img` | Create + start a container (detached, port published). |
| `docker ps` / `docker ps -a` | List running / all containers. |
| `docker stop <c>` / `docker start <c>` | Stop / start a container. |
| `docker restart <c>` | Restart. |
| `docker rm <c>` | Remove a stopped container (`-f` to force). |
| `docker logs <c>` / `docker logs -f <c>` | Print / follow a container's stdout. |
| `docker exec -it <c> sh` | Open a shell **inside** a running container. |
| `docker exec <c> curl -fsS http://localhost:8080/health/ready` | Run a one-off command inside. |
| `docker inspect <c>` | Full JSON state (env, mounts, IP, health). |
| `docker inspect -f '{{.State.Health.Status}}' <c>` | Just the health status (Go-template format). |
| `docker stats` | Live CPU/memory/IO per container. |
| `docker cp <c>:/path ./local` | Copy files out of (or into) a container. |

## 4. Compose commands

Run from the folder with the compose file. `docker compose` (v2, a plugin) — older docs say `docker-compose`.

| Command | Purpose |
|---------|---------|
| `docker compose up -d` | Create + start all services (detached). |
| `docker compose up -d --build` | Rebuild images first, then start. |
| `docker compose -f a.yaml -f b.yaml up -d` | Merge multiple files (base + overlay). Later files win. |
| `docker compose down` | Stop + remove containers and the default network (add `-v` to also drop volumes). |
| `docker compose ps` | Status of the project's services. |
| `docker compose logs -f <svc>` | Follow one service's logs. |
| `docker compose exec <svc> <cmd>` | Exec into a service's container. |
| `docker compose build [<svc>]` | Build images without starting. |
| `docker compose config` | Print the **fully-merged, resolved** config (great for debugging overlays/env). |
| `docker compose restart <svc>` | Restart one service. |
| `docker compose up -d <svc>` | Recreate just one service after a config change. |

> **Override files:** only `compose.override.yaml` is auto-merged onto `compose.yaml` (when no `-f`). Any other overlay (e.g. `compose.multi.local.yaml`) must be passed explicitly with a second `-f`.

## 5. Volumes, networks, system

| Command | Purpose |
|---------|---------|
| `docker volume ls` / `docker volume rm <v>` | List / remove named volumes. |
| `docker network ls` | List networks. |
| `docker network inspect <net>` | Show subnet, gateway IP, connected containers. |
| `docker network inspect <net> -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}'` | Just the bridge **gateway IP** (useful for `KnownProxies`). |
| `docker system df` | Disk used by images/containers/volumes/build cache. |
| `docker system prune` | Remove stopped containers, unused networks, dangling images. |
| `docker builder prune` | Reclaim build cache. |
| `docker system prune -a --volumes` | Aggressive cleanup (also unused images + volumes) — **careful**. |

---

## 6. Reading Go-template output (`-f` / `--format`)

Many commands accept `--format` with Go templates:
```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker inspect <c> --format '{{.Config.Image}}'
docker inspect <c> --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}'
```

---

## 7. Troubleshooting patterns

| Symptom | Look at |
|---------|---------|
| Container won't stay up | `docker logs <c>` — app crashed at startup (config/DB/cert). |
| `unhealthy` | The healthcheck command fails — `docker inspect <c>` → `.State.Health.Log`; run the health URL by hand. |
| Can't reach a container from the host | Is the port **published** (`docker ps` shows `0.0.0.0:host->cont`)? Only published ports are host-reachable. |
| Container A can't reach container B | Same network? Use the **service name**, not `localhost` (each container's `localhost` is itself). |
| Env var "set" but app ignores it | Check the **process** env, not just `docker inspect`: `docker exec <c> cat /proc/1/environ | tr '\0' '\n'`. Names with hyphens/dots may be dropped. |
| Source IP looks wrong behind a proxy | Docker NATs host→container traffic to the **bridge gateway IP** — that's the peer the app sees (matters for `KnownProxies`). |
| Build fails on `apt-get` | Usually a transient mirror/network blip — just retry the build. |
| Out of disk | `docker system df` → `docker system prune` / `docker builder prune`. |

---

## 8. Mental model (the one-paragraph version)

You **build** a Dockerfile into an **image** (immutable, layered). You **run** an image to get a **container** (a live process, isolated but sharing the host kernel). Containers are disposable — persist data in **volumes/bind mounts**, not in the container. Containers talk over **networks** (by service name); expose them to the host by **publishing ports**. **Compose** wires many containers, their networks, mounts, and env into one declarative file you bring `up` and `down`.

---

## 9. Related docs
- [my-docker-setup.md](my-docker-setup.md) — this repo's images, containers, and how to run them
- [../deploy/docker-single-host.md](../deploy/docker-single-host.md) / [../deploy/docker-multi-host.md](../deploy/docker-multi-host.md) — deployment walkthroughs
