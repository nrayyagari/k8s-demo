# Deployments: Run Your App Reliably

## WHY Do Deployments Exist?

**Problem**: Containers crash, nodes fail, need multiple copies for reliability  
**Solution**: Deployment automatically manages pod lifecycle with self-healing and scaling

## The Core Question

**"How do I run my app reliably in Kubernetes?"**

Single pod: Crashes → app down → users angry  
Deployment: Manages multiple pods → one crashes → others keep running → users happy

## What Deployments Do

### Self-Healing
- Pod crashes → Starts new pod automatically
- Node fails → Moves pods to healthy nodes  
- Always maintains desired replica count

### Rolling Updates
- New version → Updates pods one by one
- Always keeps some pods running → Zero downtime
- Bad update → Automatic rollback available

### Scaling
- Traffic increases → Add more replicas  
- Traffic decreases → Remove replicas
- Manual or automatic scaling

## Basic Pattern

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3          # Run 3 copies
  selector:
    matchLabels:
      app: my-app       # Find pods with this label
  template:            # Pod template
    metadata:
      labels:
        app: my-app     # Label for selector to find
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:     # ALWAYS set requests
            memory: "64Mi"
            cpu: "50m"
          limits:       # ALWAYS set limits  
            memory: "128Mi"
            cpu: "100m"
```

## The Magic: ReplicaSets

```
Deployment → Creates → ReplicaSet → Creates → Pods
    ↓
 Manages updates    Manages replicas    Run your app
```

**You manage**: Deployment  
**Kubernetes manages**: ReplicaSets and Pods

## Rolling Update Strategy

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1     # Allow 1 pod down during update
      maxSurge: 1           # Allow 1 extra pod during update
```

**Example with 3 replicas**:
1. Start update → Create 1 new pod (4 total)
2. New pod ready → Kill 1 old pod (3 total) 
3. Repeat until all pods updated
4. Always maintain 2-4 pods running

## Resource Management

### Why Resources Matter
```yaml
resources:
  requests:         # "I need at least this much"
    memory: "64Mi"  # Used for scheduling decisions
    cpu: "50m"      # Required for autoscaling
  limits:           # "Don't let me use more than this"  
    memory: "128Mi" # Prevents memory leaks from killing node
    cpu: "100m"     # Prevents CPU hogging
```

### CPU Units
- `100m` = 0.1 CPU core (100 millicores)
- `500m` = 0.5 CPU core
- `1000m` = `1` = 1 full CPU core

## Files in This Directory

1. **SIMPLE-DEPLOYMENT.yaml** - Complete beginner example with explanations
2. **01-basic-deployment.yaml** - Minimal deployment example
3. **demo-app.yaml** - Shows load balancing with hostname display
4. **webapp-deployment.yaml** - Deployment + Service together

## Quick Start

```bash
# Deploy your app
kubectl apply -f SIMPLE-DEPLOYMENT.yaml

# Check status
kubectl get deployments
kubectl get pods
kubectl get replicasets

# Scale up/down
kubectl scale deployment my-app --replicas=5

# Update image
kubectl set image deployment/my-app app=nginx:1.21

# Check rollout
kubectl rollout status deployment/my-app
```

## Common Operations

### Scaling
```bash
# Scale manually
kubectl scale deployment my-app --replicas=10

# Autoscale (requires HPA)
kubectl autoscale deployment my-app --min=2 --max=10 --cpu-percent=70
```

### Updates
```bash
# Update image
kubectl set image deployment/my-app app=nginx:1.21

# Update from file
kubectl apply -f updated-deployment.yaml

# Check rollout
kubectl rollout status deployment/my-app

# Rollback if needed
kubectl rollout undo deployment/my-app
```

### Debugging
```bash
# Check deployment
kubectl describe deployment my-app

# Check pods
kubectl get pods -l app=my-app
kubectl logs -l app=my-app

# Check ReplicaSet
kubectl describe replicaset
```

## Deployment vs Other Workloads

### ✅ Use Deployment For:
- **Stateless applications** (web servers, APIs)
- **Microservices** that don't store data locally
- **Worker processes** that process from queues
- **Frontend applications** (React, Angular apps)

### ❌ Don't Use Deployment For:
- **Databases** → Use StatefulSets (need persistent identity)
- **Node agents** → Use DaemonSets (one per node)
- **Batch jobs** → Use Jobs (run to completion)
- **Scheduled tasks** → Use CronJobs

## Best Practices

### Labels and Selectors
```yaml
# Good: Consistent labeling
metadata:
  labels:
    app: my-app
    version: v1.0
    environment: production

spec:
  selector:
    matchLabels:
      app: my-app  # Simple selector
```

### Resource Requests/Limits
```yaml
# Always set both requests and limits
resources:
  requests:
    memory: "64Mi"   # Minimum needed
    cpu: "50m"       # Minimum needed
  limits:
    memory: "256Mi"  # Maximum allowed
    cpu: "200m"      # Maximum allowed
```

### Health Checks
```yaml
# Add readiness and liveness probes
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  periodSeconds: 5

livenessProbe:
  httpGet:
    path: /health  
    port: 8080
  periodSeconds: 30
```

## Troubleshooting

### Pods Not Starting
```bash
kubectl describe deployment my-app
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# Common issues:
# - Wrong image name
# - Missing secrets/configmaps  
# - Insufficient resources
# - Image pull errors
```

### Rolling Update Stuck
```bash
kubectl rollout status deployment/my-app
kubectl describe deployment my-app

# Common issues:
# - New pods failing health checks
# - Insufficient resources for new pods
# - Image pull failures
```

## Key Insights

**Deployments are for stateless workloads** - if your app stores important data locally, consider StatefulSets

**Always set resource requests/limits** - prevents scheduling issues and resource starvation  

**Use labels consistently** - makes management and troubleshooting much easier

**Deployments are the foundation** - most Kubernetes workloads start here

**Rolling updates provide zero-downtime deployments** - but only if health checks are properly configured