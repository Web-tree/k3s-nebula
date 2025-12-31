# K8S Applications (GitOps Manifests)

This directory contains Kubernetes application manifests managed by ArgoCD.

## Structure

```
k8s/apps/
├── argocd/           # ArgoCD self-management (app-of-apps root)
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── root-app.yaml
│       └── argocd-app.yaml
└── README.md
```

## Conventions

1. **Directory per Application**: Each application has its own directory
2. **Helm Charts**: Use Helm charts for templating when needed
3. **Plain Manifests**: Simple applications can use plain YAML manifests
4. **Namespace**: Each application should declare its target namespace

## Adding New Applications

1. Create a directory under `k8s/apps/`
2. Add your manifests or Helm chart
3. Create an ArgoCD Application manifest pointing to your directory
4. ArgoCD will automatically detect and sync the application

## ArgoCD Self-Management

The `argocd/` directory implements the app-of-apps pattern:
- ArgoCD manages itself via GitOps
- Changes to ArgoCD configuration are applied by syncing in the UI
- Manual sync is used for ArgoCD itself to prevent cascading failures
