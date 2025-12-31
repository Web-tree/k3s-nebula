# Longhorn Distributed Storage

Longhorn provides persistent storage for Kubernetes workloads with automatic volume provisioning, data replication, and high availability.

## Overview

- **Version**: 1.10.1
- **Deployment**: ArgoCD GitOps
- **Storage Path**: `/var/lib/longhorn` (on cluster nodes)
- **Default Replica Count**: 2
- **Management UI**: https://longhorn.example.com

## Features

### Automatic Volume Provisioning
Longhorn is configured as the default StorageClass. Any PersistentVolumeClaim (PVC) will automatically provision a Longhorn volume without specifying a storage class.

### Data Resilience
All volumes are replicated across 2 nodes by default with soft anti-affinity enabled. This ensures data survives single node failures.

### Management Visibility
The Longhorn UI provides real-time visibility into:
- Volume health and status
- Node capacity and disk usage
- Replica distribution across nodes
- Snapshot and backup management

## Usage Examples

### Basic PVC Example

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data-pvc
  namespace: my-app
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

### Pod Using Longhorn Volume

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app-pod
  namespace: my-app
spec:
  containers:
  - name: app
    image: my-app:latest
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: my-data-pvc
```

### Volume Expansion

Longhorn supports online volume expansion. To expand a volume:

1. Edit the PVC to increase the storage request:
   ```bash
   kubectl edit pvc my-data-pvc -n my-app
   ```

2. Update the `spec.resources.requests.storage` value to the desired size

3. Longhorn will automatically expand the volume (no pod restart required for most filesystems)

## Configuration

### Resource Limits

Longhorn components have resource limits configured to prevent resource exhaustion:
- **Manager**: 1 CPU / 512Mi memory (limit), 100m CPU / 128Mi memory (request)
- **Driver**: 500m CPU / 256Mi memory (limit), 50m CPU / 64Mi memory (request)
- **UI**: 500m CPU / 256Mi memory (limit), 50m CPU / 64Mi memory (request)
- **Instance Manager**: 1 CPU / 512Mi memory (limit), 100m CPU / 64Mi memory (request)

### Replica Configuration

- **Default Replicas**: 2 per volume
- **Anti-Affinity**: Soft (distributes replicas across nodes when possible)
- **Reclaim Policy**: Delete (volumes deleted when PVC is deleted)

### Monitoring

Prometheus scraping is enabled on port 9500 at `/metrics` endpoint.

## Access Control

The Longhorn UI is accessible at https://longhorn.example.com via Traefik Ingress with automatic TLS via Let's Encrypt.

For production environments, consider adding authentication middleware:

```yaml
# Add to values.yaml ingress.annotations:
traefik.ingress.kubernetes.io/router.middlewares: longhorn-system-auth@kubernetescrd
```

Then create a BasicAuth middleware in the longhorn-system namespace.

## Troubleshooting

### Check Longhorn System Status

```bash
kubectl get pods -n longhorn-system
kubectl get volumes.longhorn.io -n longhorn-system
kubectl get replicas.longhorn.io -n longhorn-system
```

### Check Storage Class

```bash
kubectl get storageclass
```

Longhorn should be marked as `(default)`.

### Check Volume Health

```bash
kubectl get volume.longhorn.io -n longhorn-system -o wide
```

Look for `robustness` column - should show `healthy` for production volumes.

### Access Logs

```bash
# Manager logs
kubectl logs -n longhorn-system -l app=longhorn-manager

# UI logs
kubectl logs -n longhorn-system -l app=longhorn-ui
```

## Related Documentation

- [Longhorn Documentation](https://longhorn.io/docs/)
- [ArgoCD Application Manifest](./application.yaml)
- [Helm Values Configuration](./values.yaml)
- [Route53 DNS Configuration](../../cluster-configuration/longhorn.tf)

## Deployment

This Longhorn installation is managed via ArgoCD. To modify the configuration:

1. Edit `values.yaml` in this directory
2. Commit changes to git
3. ArgoCD will automatically sync the changes to the cluster

Manual deployment commands (not recommended):
```bash
# Apply ArgoCD Application
kubectl apply -f application.yaml

# Check sync status
kubectl get application longhorn -n argocd
```
