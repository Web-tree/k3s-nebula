# ArgoCD Bad Gateway Troubleshooting

## Quick Debugging Steps

Run the debug script:
```bash
cd k8s/cluster-configuration
./debug-argocd-ingress.sh
```

## Common Issues and Solutions

### 1. Traefik Not Watching Standard Ingress

**Problem**: K3s Traefik might only watch IngressRoutes (CRDs), not standard Ingress resources.

**Check**:
```bash
# Check if Traefik is watching Ingress
kubectl get ingressclass traefik -o yaml

# Check Traefik configuration
kubectl get configmap -n kube-system traefik -o yaml
```

**Solution**: If Traefik doesn't support standard Ingress, you have two options:

**Option A**: Use Traefik IngressRoutes (recommended for K3s)
- Remove `server.ingress.enabled` from values
- Create IngressRoute resources manually (see old implementation)

**Option B**: Configure Traefik to watch Ingress
- Update Traefik Helm values to enable Ingress provider
- Or use a different ingress controller

### 2. Service Port Mismatch

**Problem**: Ingress pointing to wrong service port.

**Check**:
```bash
# Check service ports
kubectl get svc -n argocd argocd-server -o yaml

# Check ingress backend
kubectl get ingress -n argocd -o yaml
```

**Expected**: 
- Service should expose port `80` (HTTP) when using `--insecure`
- Ingress should route to port `80`

**Fix**: Ensure ArgoCD service exposes HTTP port 80:
```yaml
server:
  service:
    servicePortHttp: 80  # Default, but verify
```

### 3. Service Has No Endpoints

**Problem**: Pods not ready or selector mismatch.

**Check**:
```bash
# Check endpoints
kubectl get endpoints -n argocd argocd-server

# Check pods
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server

# Check pod readiness
kubectl describe pod -n argocd <pod-name>
```

**Fix**: Ensure ArgoCD server pods are running and ready.

### 4. Certificate Provisioning Blocking

**Problem**: cert-manager can't provision certificate, blocking ingress.

**Check**:
```bash
# Check certificate status
kubectl get certificate -n argocd
kubectl describe certificate -n argocd <cert-name>

# Check certificate requests
kubectl get certificaterequest -n argocd
kubectl describe certificaterequest -n argocd <cr-name>

# Check ClusterIssuer
kubectl get clusterissuer letsencrypt-prod
```

**Fix**: Ensure ClusterIssuer exists and cert-manager can access Let's Encrypt.

### 5. DNS Not Resolving

**Problem**: Domain not pointing to Traefik load balancer.

**Check**:
```bash
# Get load balancer IP
cd k8s/cluster-configuration
terraform output load_balancer_ip

# Check DNS
dig argocd.example.com
nslookup argocd.example.com
```

**Fix**: Update DNS A record to point to load balancer IP.

## Step-by-Step Debugging

1. **Verify pods are running**:
   ```bash
   kubectl get pods -n argocd
   ```

2. **Check service exists and has endpoints**:
   ```bash
   kubectl get svc -n argocd argocd-server
   kubectl get endpoints -n argocd argocd-server
   ```

3. **Test service directly** (bypass ingress):
   ```bash
   kubectl port-forward -n argocd svc/argocd-server 8080:80
   # Then visit http://localhost:8080
   ```

4. **Check ingress resource**:
   ```bash
   kubectl get ingress -n argocd
   kubectl describe ingress -n argocd <ingress-name>
   ```

5. **Check Traefik logs**:
   ```bash
   TRAEFIK_POD=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].metadata.name}')
   kubectl logs -n kube-system $TRAEFIK_POD --tail=50
   ```

6. **Check ArgoCD server logs**:
   ```bash
   SERVER_POD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}')
   kubectl logs -n argocd $SERVER_POD --tail=50
   ```

## Most Likely Issue for K3s

**Traefik in K3s typically only watches IngressRoutes (CRDs), not standard Ingress resources.**

If this is the case, you need to either:
1. Use Traefik IngressRoutes instead of standard Ingress
2. Configure Traefik to watch standard Ingress resources

To check if Traefik supports Ingress:
```bash
kubectl api-resources | grep ingress
# Should show both:
# ingressroutes.traefik.containo.us
# ingresses.networking.k8s.io
```

If only IngressRoutes are available, you'll need to use IngressRoute CRDs instead of standard Ingress.







