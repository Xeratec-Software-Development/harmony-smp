# Harmony SMP Kubernetes Deployment

This directory contains Kubernetes manifests for deploying Harmony SMP to a Kubernetes cluster.

## Prerequisites

- **Kubernetes cluster** (v1.19+) - minikube, kind, GKE, EKS, AKS, etc.
- **kubectl** configured to access your cluster
- **Docker** for building the application image
- **Nginx Ingress Controller** (optional, for external access)

## Architecture

The deployment consists of:
- **MySQL Database** (1 replica) - Persistent storage for SMP data
- **Harmony SMP Application** (1 replica) - Spring Boot application
- **Ingress** - External HTTP access (optional)

## Quick Start

### Step 1: Build the Docker Image

First, build the Harmony SMP project and create a Docker image:

```bash
# From the project root
./mvnw clean install -DskipTests -DskipITs

# Build the Docker image (use the Dockerfile in k8s/)
docker build -t harmony-smp:2.2.0 -f k8s/Dockerfile .
```

If using a remote cluster, push to your container registry:

```bash
# Tag for your registry
docker tag harmony-smp:2.2.0 your-registry/harmony-smp:2.2.0

# Push to registry
docker push your-registry/harmony-smp:2.2.0

# Update k8s/smp-deployment.yaml with your image name
```

### Step 2: Initialize the Database Schema

Before deploying, you need to prepare the database initialization script:

```bash
# The MySQL initialization will be handled automatically via the init container
# Database schema will be created from: smp-webapp/src/main/smp-setup/database-scripts/mysql5innodb.ddl
```

### Step 3: Deploy to Kubernetes

Deploy all resources in order:

```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Create secrets
kubectl apply -f k8s/mysql-secret.yaml

# Create storage
kubectl apply -f k8s/mysql-pvc.yaml

# Deploy MySQL
kubectl apply -f k8s/mysql-deployment.yaml

# Wait for MySQL to be ready
kubectl wait --for=condition=ready pod -l app=mysql -n harmony-smp --timeout=300s

# Deploy SMP application
kubectl apply -f k8s/smp-configmap.yaml
kubectl apply -f k8s/smp-deployment.yaml

# (Optional) Create Ingress for external access
kubectl apply -f k8s/ingress.yaml
```

Or deploy all at once:

```bash
kubectl apply -f k8s/
```

### Step 4: Verify Deployment

Check the status of your deployment:

```bash
# Check all resources
kubectl get all -n harmony-smp

# Check pod logs
kubectl logs -f deployment/harmony-smp -n harmony-smp

# Check MySQL logs
kubectl logs -f deployment/mysql -n harmony-smp
```

### Step 5: Access the Application

#### Option 1: Port Forward (Development)

```bash
kubectl port-forward svc/harmony-smp 8084:8084 -n harmony-smp
```

Then access at: http://localhost:8084/smp/

#### Option 2: Ingress (Production)

If you deployed the Ingress resource:

1. **Install Nginx Ingress Controller** (if not already installed):
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
   ```

2. **Add hostname to /etc/hosts** (for local testing):
   ```bash
   echo "$(kubectl get ingress harmony-smp-ingress -n harmony-smp -o jsonpath='{.status.loadBalancer.ingress[0].ip}') harmony-smp.local" | sudo tee -a /etc/hosts
   ```

3. Access at: http://harmony-smp.local/

#### Option 3: LoadBalancer Service (Cloud)

For cloud deployments, change the service type:

```bash
kubectl patch svc harmony-smp -n harmony-smp -p '{"spec": {"type": "LoadBalancer"}}'
kubectl get svc harmony-smp -n harmony-smp
```

## Configuration

### Database Configuration

Database credentials are stored in `k8s/mysql-secret.yaml`. To change them:

```bash
# Edit the secret
kubectl edit secret mysql-secret -n harmony-smp

# Or delete and recreate
kubectl delete secret mysql-secret -n harmony-smp
kubectl create secret generic mysql-secret -n harmony-smp \
  --from-literal=mysql-root-password=YOUR_ROOT_PASSWORD \
  --from-literal=mysql-password=YOUR_SMP_PASSWORD
```

### Application Configuration

Application settings are in `k8s/smp-configmap.yaml`. After editing:

```bash
kubectl apply -f k8s/smp-configmap.yaml
kubectl rollout restart deployment/harmony-smp -n harmony-smp
```

### Resource Limits

Adjust CPU and memory in the deployment files:
- **MySQL**: `k8s/mysql-deployment.yaml`
- **SMP App**: `k8s/smp-deployment.yaml`

### Persistent Storage

By default, uses 10Gi for MySQL. To change:

```bash
# Edit k8s/mysql-pvc.yaml
# Change: storage: 10Gi to your desired size
# Then delete the PVC and redeploy (WARNING: This will delete data)
```

## Scaling

Scale the SMP application (database remains single instance):

```bash
kubectl scale deployment harmony-smp --replicas=3 -n harmony-smp
```

**Note**: For multi-replica deployments, ensure `smp.cluster.enabled=true` in the ConfigMap.

## Monitoring

### View Logs

```bash
# Application logs
kubectl logs -f deployment/harmony-smp -n harmony-smp

# Database logs
kubectl logs -f deployment/mysql -n harmony-smp

# All pods
kubectl logs -f -l app=harmony-smp -n harmony-smp
```

### Pod Status

```bash
# Watch pods
kubectl get pods -n harmony-smp -w

# Describe pod for issues
kubectl describe pod <pod-name> -n harmony-smp
```

### Events

```bash
kubectl get events -n harmony-smp --sort-by='.lastTimestamp'
```

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n harmony-smp

# Check logs
kubectl logs <pod-name> -n harmony-smp

# Check events
kubectl get events -n harmony-smp
```

### Database Connection Issues

```bash
# Verify MySQL is running
kubectl get pods -l app=mysql -n harmony-smp

# Test MySQL connection from SMP pod
kubectl exec -it deployment/harmony-smp -n harmony-smp -- sh
# Inside the pod:
nc -zv mysql 3306
```

### Application Not Accessible

```bash
# Check service
kubectl get svc -n harmony-smp

# Check endpoints
kubectl get endpoints -n harmony-smp

# Check ingress
kubectl describe ingress harmony-smp-ingress -n harmony-smp
```

## Production Considerations

### Security

1. **Change default passwords** in `mysql-secret.yaml`
2. **Enable TLS/HTTPS** - Uncomment TLS section in `ingress.yaml`
3. **Use cert-manager** for automatic SSL certificates
4. **Network policies** - Restrict traffic between pods
5. **RBAC** - Configure appropriate service accounts

### High Availability

1. **Multiple replicas** - Scale SMP deployment
2. **Pod disruption budgets** - Prevent all pods from being down
3. **Database replication** - Consider MySQL replication or managed database
4. **Backup strategy** - Regular backups of MySQL data

### Monitoring & Observability

1. **Prometheus** - Install for metrics collection
2. **Grafana** - Dashboards for visualization
3. **ELK/EFK Stack** - Centralized logging
4. **Health checks** - Already configured in deployments

### Resource Management

1. **Resource quotas** - Set namespace limits
2. **Limit ranges** - Default limits for pods
3. **HPA** - Horizontal Pod Autoscaler for auto-scaling
4. **VPA** - Vertical Pod Autoscaler for resource recommendations

## Cleanup

Remove all resources:

```bash
kubectl delete -f k8s/

# Or delete namespace (removes everything)
kubectl delete namespace harmony-smp
```

## Development with Minikube

For local development with Minikube:

```bash
# Start minikube
minikube start

# Use minikube's docker daemon
eval $(minikube docker-env)

# Build image (it will be available in minikube)
docker build -t harmony-smp:2.2.0 -f k8s/Dockerfile .

# Deploy
kubectl apply -f k8s/

# Access via minikube service
minikube service harmony-smp -n harmony-smp

# Or use port-forward
kubectl port-forward svc/harmony-smp 8084:8084 -n harmony-smp
```

## Support

For issues or questions:
- **Harmony Documentation**: https://github.com/nordic-institute/harmony-common/
- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **Project Issues**: Check the repository issues

## License

This deployment configuration is part of the Harmony SMP project and follows the same EUPL-1.2 license.
