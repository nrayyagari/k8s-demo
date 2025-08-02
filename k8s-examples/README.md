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
├── autoscaling/    # Horizontal and Vertical Pod Autoscaler examples
├── storage/        # Persistent storage with PV, PVC, and StorageClass examples
├── rbac/           # Roles, ClusterRoles, and RBAC examples
├── scheduling/     # Pod scheduling, taints/tolerations, affinity/anti-affinity
├── resource-quotas/ # Resource quotas and limits for resource management
├── troubleshooting/ # Debugging scenarios and systematic troubleshooting
├── annotations/    # Metadata for tools and human operators
├── jobs/           # Batch processing and one-time task execution
├── cronjobs/       # Scheduled task automation
├── node-affinity/  # Advanced pod placement control
├── observability/  # Production monitoring, metrics, logging, tracing
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

**6. Who can do what in my cluster?** → **RBAC (Roles & ClusterRoles)**
- Problem: Everyone has admin access - security risk
- Solution: Fine-grained permissions per user/team

**7. Where should my pods run?** → **Scheduling (Taints, Affinity)**
- Problem: Default scheduler doesn't understand business needs
- Solution: Control pod placement for performance and availability

**8. How do I handle dynamic resource demands automatically?** → **Autoscaling (HPA & VPA)**
- Problem: Traffic varies unpredictably, unknown resource needs, manual scaling is slow
- Solution: Automatically scale horizontally (more pods) or vertically (bigger containers)

**9. How do I store data that survives pod restarts?** → **Storage (PV, PVC, StorageClass)**
- Problem: Containers are ephemeral, data disappears when pods restart
- Solution: Persistent storage that survives pod restarts, rescheduling, and node failures

**10. How do I prevent resource starvation?** → **Resource Quotas & Limits**
- Problem: Apps consume unlimited resources, causing instability
- Solution: Set quotas per namespace and limits per container

**11. My application isn't working - how do I debug?** → **Troubleshooting**
- Problem: Complex systems fail in subtle ways
- Solution: Systematic debugging approach using the right tools

**12. How do I attach metadata for tools and operations?** → **Annotations**  
- Problem: Need to store configuration and context that isn't for selection
- Solution: Annotations provide arbitrary metadata for tools, automation, and humans

**13. How do I run tasks that complete and exit?** → **Jobs**
- Problem: Need batch processing, migrations, one-time tasks
- Solution: Jobs run pods to completion with retry and failure handling

**14. How do I automate recurring tasks?** → **CronJobs**
- Problem: Manual execution of scheduled tasks (backups, reports, cleanup)
- Solution: CronJobs automatically create Jobs on a schedule

**15. How do I control exactly where my pods run?** → **Node Affinity**
- Problem: Need specific hardware, compliance, or performance requirements
- Solution: Node affinity provides precise control over pod placement

### The 90/10 Rule: Enterprise Production Reality

**90% of workloads**: Stateless web apps
- **Pattern**: Deployment + Service + Ingress + Health Probes + HPA + Resource Quotas + NetworkPolicies
- **Why this works**: Horizontal scaling, self-healing, cloud-native design
- **Business Value**: High availability, cost efficiency, rapid iteration
- **When it fails**: Session state, file uploads, legacy applications

**10% of workloads**: Stateful systems  
- **Pattern**: StatefulSet + Headless Service + Health Probes + VPA + Storage + RBAC + Pod Security
- **Why different**: Persistent identity, ordered deployment, data consistency requirements
- **Business Value**: Data integrity, performance optimization, compliance
- **When it fails**: Distributed systems complexity, backup/recovery challenges

### **Critical Analysis: Why Most Kubernetes Deployments Fail**

**Common Failure Patterns**:
1. **Resource Limits**: 60% of outages - no requests/limits set
2. **Health Checks**: 25% of issues - missing or wrong probes  
3. **Security**: 15% of breaches - overprivileged ServiceAccounts

**Evolution Context**: How these patterns emerged from:
- **VM Era**: Manual resource allocation → Kubernetes automation
- **Container Era**: Docker run → Kubernetes orchestration  
- **Cloud Era**: Pet servers → Cattle workloads

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

### 6. Secure Your Cluster  
```bash
kubectl apply -f rbac/SIMPLE-RBAC.yaml
```

### 7. Control Pod Placement
```bash
kubectl apply -f scheduling/SIMPLE-SCHEDULING.yaml
```

### 8. Scale Automatically
```bash
kubectl apply -f autoscaling/SIMPLE-AUTOSCALING.yaml
```

### 9. Add Persistent Storage
```bash
kubectl apply -f storage/SIMPLE-STORAGE.yaml
```

### 10. Set Resource Limits
```bash
kubectl apply -f resource-quotas/SIMPLE-QUOTAS.yaml
```

### 11. Debug Issues Systematically
```bash
kubectl apply -f troubleshooting/SIMPLE-DEBUG.yaml
```

### 12. Add Metadata for Tools and Operations
```bash
kubectl apply -f annotations/SIMPLE-ANNOTATIONS.yaml
```

### 13. Run One-Time Tasks
```bash
kubectl apply -f jobs/SIMPLE-JOBS.yaml
```

### 14. Automate Scheduled Tasks
```bash
kubectl apply -f cronjobs/SIMPLE-CRONJOBS.yaml
```

### 15. Control Pod Placement
```bash
kubectl apply -f node-affinity/SIMPLE-NODE-AFFINITY.yaml
```

### 16. Monitor and Observe Your System
```bash
kubectl apply -f observability/
```

## The Pattern: Build Up Gradually

**Level 1**: Pod → Deployment → Service  
**Level 2**: Add Health Probes → Add Ingress  
**Level 3**: Add StatefulSets (when needed) → Add RBAC → Add Scheduling → Add Autoscaling → Add Storage → Add Resource Quotas  
**Level 4**: Master Troubleshooting → Add Annotations → Add Jobs/CronJobs → Add Node Affinity (essential for production)

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
kubectl get hpa,vpa -A
kubectl get pv,pvc -A
kubectl get storageclass
kubectl get resourcequota,limitrange
kubectl get roles,rolebindings,clusterroles,clusterrolebindings
kubectl get cronjobs,jobs
kubectl get nodes --show-labels
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

### Test RBAC permissions:
```bash
kubectl auth can-i create pods --as=system:serviceaccount:rbac-demo:demo-sa
```

### Check pod scheduling:
```bash
kubectl get pods -o wide
kubectl describe pod <pod-name> | grep -A 10 "Node-Selectors"
```

### Check autoscaling status:
```bash
kubectl get hpa --watch
kubectl describe hpa <hpa-name>
kubectl get vpa <vpa-name> -o yaml | grep -A 10 recommendation
```

### Check storage status:
```bash
kubectl describe pvc <pvc-name>
kubectl get pv <pv-name> -o wide
kubectl describe storageclass <storage-class-name>
```

### Check resource quotas and limits:
```bash
kubectl describe resourcequota <quota-name> -n <namespace>
kubectl describe limitrange <limitrange-name> -n <namespace>
kubectl top pods -n <namespace>
```

### Debug application issues:
```bash
kubectl get events --sort-by='.lastTimestamp'
kubectl describe pod <pod-name>
kubectl logs <pod-name> --previous
```

### Check annotations and job status:
```bash
kubectl get deployment <name> -o yaml | grep -A 10 annotations
kubectl get jobs --watch
kubectl logs -l job-name=<job-name>
```

### View node affinity and placement:
```bash
kubectl get pods -o wide
kubectl describe pod <pod-name> | grep -A 10 "Node-Selectors"
kubectl get nodes --show-labels
```

## Clean Up

Remove all resources:
```bash
kubectl delete -f deployments/
kubectl delete -f services/
kubectl delete -f statefulsets/
kubectl delete -f daemonsets/
kubectl delete -f pdbs/
kubectl delete -f rbac/
kubectl delete -f scheduling/
kubectl delete -f autoscaling/
kubectl delete -f storage/
kubectl delete -f resource-quotas/
kubectl delete -f troubleshooting/
kubectl delete -f annotations/
kubectl delete -f jobs/
kubectl delete -f cronjobs/
kubectl delete -f node-affinity/
```

## Notes

- All examples use standard images (nginx, postgres, busybox)
- Resource limits are set for production readiness
- Comments explain key concepts inline
- Files are numbered for learning progression