# Petclinic DevOps

A DevOps wrapper around [spring-petclinic-microservices](https://github.com/spring-petclinic/spring-petclinic-microservices) — a portfolio project demonstrating a full containerization and CI/CD cycle, with Kubernetes deployment on AWS planned for later stages.

The application code (Spring Boot microservices) is included as a git submodule and is not modified — the entire DevOps layer (Docker, CI/CD, Helm, Terraform, monitoring) lives around it in this repository.

## Stack

- **Containerization:** Docker, multi-stage builds
- **Orchestration (local):** Docker Compose
- **CI/CD:** GitHub Actions
- **Registry:** GitHub Container Registry (GHCR)
- **Planned:** Kubernetes (EKS), Helm, Terraform, Prometheus/Grafana/Loki

## Repository structure
petclinic-devops/
├── app/ # git submodule: spring-petclinic-microservices
├── docker/ # Dockerfile for each of the 6 services
│ ├── discovery-server/
│ ├── config-server/
│ ├── api-gateway/
│ ├── customers-service/
│ ├── vets-service/
│ └── visits-service/
├── docker-compose.yml # run the whole stack locally
├── scripts/
│ └── build-all.ps1 # batch-build all 6 images
├── helm/ # (planned) Helm charts
├── terraform/ # (planned) IaC for AWS
├── monitoring/ # (planned) Prometheus/Grafana/Loki
└── .github/workflows/ # CI/CD pipelines

## Services

| Service | Port | Description |
|---|---|---|
| discovery-server | 8761 | Eureka service registry |
| config-server | 8888 | Spring Cloud Config Server |
| api-gateway | 8080 | Entry point, UI |
| customers-service | 8081 | Pet owners and pets |
| vets-service | 8082 | Veterinarians |
| visits-service | 8083 | Visits |

## Quick start (local)

### Prerequisites
- Docker Desktop (with WSL2 backend on Windows)
- Git

### 1. Clone with submodule

```bash
git clone --recurse-submodules https://github.com/<username>/petclinic-devops.git
cd petclinic-devops
```

If the repo was already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

### 2. Build images

```powershell
.\scripts\build-all.ps1
```

The script builds all 6 images tagged as `:local` and `:<git-sha>`, injecting git metadata (app-code commit SHA, devops-repo commit SHA, build date) as OCI labels for traceability.

### 3. Run the full stack

```bash
docker-compose up
```

Startup order is controlled via `depends_on` + healthchecks:
`config-server` → `discovery-server` → (`api-gateway`, `customers-service`, `vets-service`, `visits-service`) in parallel.

### 4. Verify

- Eureka Dashboard: http://localhost:8761
- Pet Clinic UI: http://localhost:8080

## CI/CD

On every push to `main` (changes under `docker/**` or the submodule), GitHub Actions:
1. Checks out the repository together with the submodule
2. Builds all 6 images in parallel (matrix strategy)
3. Pushes to GHCR tagged as `:latest` and `:<git-sha>`

On Pull Requests, only the build step runs (Dockerfile validation), with no push to the registry.

Images are publicly available:
```bash
docker pull ghcr.io/<username>/petclinic-<service-name>:latest
```

## Kubernetes deployment (Helm)

The same 6 services can be deployed to a Kubernetes cluster via the Helm chart in `helm/petclinic/`.

### Prerequisites

- A running Kubernetes cluster with `kubectl` access
- [Helm 3](https://helm.sh/)
- [NGINX Gateway Fabric](https://docs.nginx.com/nginx-gateway-fabric/) (Gateway API implementation) installed in the cluster

### 1. Install Gateway API CRDs and NGINX Gateway Fabric

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml

helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --namespace nginx-gateway \
  --create-namespace \
  --wait
```

### 2. Deploy the application

```bash
helm upgrade --install petclinic ./helm/petclinic
```

This creates:
- A `Deployment` + `Service` for each of the 6 microservices
- Startup/readiness/liveness probes tuned for Spring Boot's Config Server / Eureka bootstrap time
- An `initContainer` per service that waits for its dependencies (config-server, discovery-server) to be reachable before starting
- A `Gateway` + `HTTPRoute` exposing `api-gateway` through NGINX Gateway Fabric
- An `NginxProxy` resource configuring the auto-provisioned data-plane Service as `NodePort` (bare-metal cluster, no cloud load balancer)

### 3. Access

Find the NodePort assigned to the Gateway's data-plane service:

```bash
kubectl get svc -A | grep gateway-nginx
```

Add a hosts entry pointing `petclinic.local` at any cluster node's IP, then open:

http://petclinic.local:<nodeport>

## Key engineering decisions

- **Multi-stage Docker build** — separate stages for compilation (JDK) and runtime (JRE), smaller final image, non-root user.
- **Git-based traceability instead of `git.properties`** — since the application code is included as a submodule, Spring Boot's built-in `git-commit-id-maven-plugin` cannot reliably read git metadata inside the Docker build context. Instead, the commit SHA is passed via `--build-arg` and recorded as OCI image labels (`org.opencontainers.image.revision`) — separately for the app code and for this devops repository.
- **`SPRING_PROFILES_ACTIVE=docker`** — activates the Docker-network-aware configuration profile (services address each other by Docker Compose service names instead of `localhost`).


## License

The application code (`app/` submodule) is licensed under the original [spring-petclinic-microservices](https://github.com/spring-petclinic/spring-petclinic-microservices) license. The DevOps code in this repository is MIT (add a `LICENSE` file if desired).