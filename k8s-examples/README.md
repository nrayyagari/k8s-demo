# Kubernetes Examples: Learn by Doing

## WHY This Repository Exists

**Problem**: Kubernetes concepts are complex and abstract  
**Solution**: Practical, runnable examples that teach through first principles

Start with WHY, then HOW, then practice.

## Directory Structure

```
k8s-examples/
├── deployments/     # Deployment examples
├── services/        # Service examples (ClusterIP, NodePort, LoadBalancer)
├── statefulsets/    # StatefulSet examples
├── daemonsets/      # DaemonSet examples
├── pdbs/           # Pod Disruption Budget examples
├── ingress/        # Ingress controller and routing examples
├── health-checks/  # Liveness, readiness, and startup probes
├── configmaps-secrets/ # Configuration and secrets management
├── autoscaling/    # Horizontal Pod Autoscaler examples
└── README.md       # This file
```

## Core Concepts: First Principles

### The Fundamental Questions

**1. How do I run my app reliably?** → **Deployments**
- Problem: Containers crash, nodes fail
- Solution: Automatically restart and spread across nodes

**2. How do users reach my app?** → **Services** 
- Problem: Pod IPs change constantly
- Solution: Stable endpoint that routes to healthy pods

**3. What if my pods need unique identity?** → **StatefulSets**
- Problem: Database clusters need master/slave roles
- Solution: Predictable names + individual storage

**4. How do I route HTTP traffic efficiently?** → **Ingress**
- Problem: Need external access to multiple services
- Solution: Single entry point with smart routing

**5. How does Kubernetes know my app is healthy?** → **Health Probes**
- Problem: App might be running but broken
- Solution: Kubernetes checks and acts on failures

### The 90/10 Rule

**90% of workloads**: Stateless web apps
- Use: Deployment + Service + Ingress + Health Probes

**10% of workloads**: Stateful systems  
- Use: StatefulSet + Headless Service + Health Probes

## Learning Path: Start Here

### 1. Run Your First App (Start Here)
```bash
kubectl apply -f deployments/SIMPLE-DEPLOYMENT.yaml
```

### 2. Connect to Your App  
```bash
kubectl apply -f services/SIMPLE-SERVICE.yaml
```

### 3. Make Your App Healthy
```bash
kubectl apply -f health-checks/SIMPLE-GUIDE.yaml
```

### 4. Expose Your App to the Internet
```bash
kubectl apply -f ingress/01-ingress-controller.yaml
kubectl apply -f ingress/03-basic-ingress.yaml
```

### 5. When You Need Databases
```bash
kubectl apply -f statefulsets/01-basic-statefulset.yaml
```

## The Pattern: Build Up Gradually

**Level 1**: Pod → Deployment → Service  
**Level 2**: Add Health Probes → Add Ingress  
**Level 3**: Add StatefulSets (when needed)

Each level solves a specific problem. Don't skip ahead.

## Key Principles Applied

### 1. Labels Connect Everything
```yaml
# Pod has label
labels:
  app: webapp

# Service finds pod by label  
selector:
  app: webapp
```
**Rule**: Labels must match exactly (case-sensitive)

### 2. Start Simple, Add Complexity
- Basic: Pod → Deployment
- Add reliability: + Service  
- Add health: + Probes
- Add external access: + Ingress
- Add state: + StatefulSet (only when needed)

### 3. One Responsibility Per Resource
- **Deployment**: Run app reliably
- **Service**: Route traffic to app
- **Ingress**: Route external HTTP traffic  
- **ProbeS**: Check app health

Don't try to solve everything in one resource.

## Commands for Testing

### Check resource status:
```bash
kubectl get deployments
kubectl get services
kubectl get statefulsets
kubectl get daemonsets
kubectl get pdb
```

### View pod distribution:
```bash
kubectl get pods -o wide
```

### Test service connectivity:
```bash
kubectl exec -it <pod-name> -- curl <service-name>
```

### Check PDB status:
```bash
kubectl get pdb <pdb-name>
```

## Clean Up

Remove all resources:
```bash
kubectl delete -f deployments/
kubectl delete -f services/
kubectl delete -f statefulsets/
kubectl delete -f daemonsets/
kubectl delete -f pdbs/
```

## Notes

- All examples use standard images (nginx, postgres, busybox)
- Resource limits are set for production readiness
- Comments explain key concepts inline
- Files are numbered for learning progression