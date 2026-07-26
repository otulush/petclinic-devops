# 1. Single namespace for now, multi-namespace planned later

## Status
Accepted

## Context

The project currently runs all Kubernetes resources (app services, Gateway,
HTTPRoute) in a single namespace (`default`), while the NGINX Gateway Fabric
controller lives in its own `nginx-gateway` namespace.

As the project grows — specifically once the `monitoring/` stack
(Prometheus, Grafana, Loki) is added — there's a natural motivation to split
resources into dedicated namespaces:

- `petclinic`      — the 6 application services
- `monitoring`     — Prometheus, Grafana, Loki
- `nginx-gateway`  — Gateway API controller (already separate)

Reasons to eventually adopt this split:

1. **RBAC boundaries.** `Role`/`RoleBinding` are namespace-scoped. Splitting
   namespaces would allow granting different teams (e.g. app developers vs.
   an SRE/observability team) different access levels — e.g. `edit` on
   `petclinic`, `view`-only on `monitoring`, no access to `nginx-gateway`.
2. **ResourceQuota / LimitRange per namespace** — caps how much CPU/memory
   each team's workloads can consume, preventing one component from starving
   the others on a shared cluster.
3. **NetworkPolicy-based traffic isolation** — e.g. restricting direct access
   from `monitoring` to `petclinic` pods to only the Prometheus scrape path.
4. **Readability** — `kubectl get pods -A` stays meaningful as the number of
   components grows.

## Decision

For now, keep the `petclinic` Helm chart deploying into a single namespace
(`default`). Namespace splitting is deferred until the `monitoring/` stack is
introduced, at which point:

- The Helm chart's namespace becomes a `values.yaml` parameter instead of an
  implicit `default`.
- `Gateway`/`HTTPRoute` will need explicit
  `allowedRoutes.namespaces.from: All` (or `Selector`), since the Gateway API
  default (`Same`) only allows routes from the Gateway's own namespace — this
  breaks once `nginx-gateway` and `petclinic` are genuinely separate
  namespaces with cross-namespace routing.
- Example `Role`/`RoleBinding` manifests will be added to demonstrate
  per-team access boundaries.

## Consequences

- Simpler chart and fewer moving parts while the project is single-person /
  early-stage.
- A follow-up migration step is required before adding RBAC examples or
  ResourceQuota to the repo — tracked here so the reasoning isn't lost.
- The `Gateway` resource will need a spec change (`allowedRoutes`) as part of
  that migration — already anticipated, not a surprise later.