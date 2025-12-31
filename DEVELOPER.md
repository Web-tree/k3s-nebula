# Developer Guide: k3s-nebula

This guide is intended for developers who want to extend `k3s-nebula`, add new apps, or contribute to the core project.

## Project Structure

```
k8s-core/
├── cluster-infrastructure/  # Terraform: Physical resources (Servers, Networks)
├── cluster-configuration/   # Terraform: Kubernetes resources (ArgoCD, Secrets)
├── apps/                    # Helm charts & Manifests
├── scripts/                 # Helper scripts
└── test/                    # Go tests (Terratest)
```

## Local Development (Extending)

To use `k3s-nebula` in your own project, we recommend treating it as an upstream module.

### 1. Fork or Submodule

You can add this repository as a git submodule to your infrastructure project:

```bash
git submodule add https://github.com/webtree/k3s-nebula.git infrastructure/core
```

### 2. Wrapper Structure

Create a wrapper directory (e.g., `infrastructure/live/`) that calls the core modules:

```hcl
# infrastructure/live/main.tf
module "cluster" {
  source = "../core/cluster-infrastructure"
  # ... variables
}
```

This allows you to update the core logic by pulling the latest changes from the upstream `k3s-nebula` repo.

## Adding New Apps

### 1. Create a Helm Release in Terraform

To add a new application (e.g., Prometheus) to the base cluster, add a resource to `cluster-configuration`:

```hcl
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  # ...
}
```

### 2. Add to ArgoCD (GitOps)

For user-land applications, it's best to manage them via ArgoCD rather than Terraform.

1. Create a generic `Application` manifest in `apps/`.
2. Apply it manually or via the "App of Apps" pattern once ArgoCD is running.

## Testing

We use [Terratest](https://terratest.gruntwork.io/) for end-to-end validation.

### Prerequisites

- Go >= 1.21
- Terraform >= 1.5.0
- Valid AWS & Hetzner credentials in environment

### Running Tests

```bash
cd test
go test -v -timeout 60m
```

> **Warning**: Tests provision real resources on Hetzner Cloud and will incur costs.

## Taskfile Extension

You can include the core Taskfile in your project's `Taskfile.yml` to inherit standard commands:

```yaml
includes:
  core:
    taskfile: ./k8s-core/Taskfile.yml
    dir: ./k8s-core
```

Then you can run `task core:deploy:infrastructure`.

## Contributing

Please refer to [CONTRIBUTING.md](CONTRIBUTING.md) for pull request guidelines and code style.
