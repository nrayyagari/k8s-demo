# Kubernetes Troubleshooting: Production-Ready Crisis Response

## WHY Troubleshooting Skills Save Your Career

**Problem**: It's 2AM, production is down, customers are angry, and your manager is calling  
**Solution**: Systematic debugging approach that finds root causes fast and fixes them faster

**Business Reality**: In production, troubleshooting isn't about being smart—it's about being systematic and fast.

## The 2AM Rule: First Principles

When everything is broken and pressure is high, follow this rule:
1. **Stop the bleeding** (restore service)  
2. **Find the root cause** (prevent recurrence)
3. **Learn and improve** (make system stronger)

Never try to fix what you don't understand. Understanding comes first.

## The 5-Minute Kubernetes Health Check

**Before you panic, spend 5 minutes getting the complete picture:**

```bash
# Step 1: Cluster health (30 seconds)
kubectl get nodes
kubectl get pods --all-namespaces | grep -v Running

# Step 2: Recent events (1 minute)  
kubectl get events --sort-by='.lastTimestamp' | tail -20

# Step 3: Resource pressure (1 minute)
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=memory | head -10

# Step 4: Critical services (1 minute)
kubectl get pods -n kube-system
kubectl get svc --all-namespaces | grep LoadBalancer

# Step 5: Your application (1.5 minutes)
kubectl get all -n production  # Replace with your namespace
kubectl describe pods -l app=your-app | grep -A 5 Events
```

**After 5 minutes, you'll know:**
- Is this a cluster problem or application problem?
- Are resources exhausted?
- What happened recently?
- Where to focus your efforts

## Crisis Response Patterns: Real Production Scenarios

### Crisis 1: "Website Down - Revenue Lost"

**Situation**: E-commerce site returning 503 errors, Black Friday traffic  
**Business Impact**: $50,000/hour revenue loss  
**SLA**: Restore service in 15 minutes

**Response Pattern**:
```bash
# IMMEDIATE (2 minutes): Stop the bleeding
kubectl get pods -n production | grep -v Running
kubectl scale deployment web-frontend --replicas=10  # Scale up immediately

# DIAGNOSE (3 minutes): Find root cause
kubectl logs -l app=web-frontend --tail=50 | grep ERROR
kubectl top pods -n production --sort-by=memory

# COMMON CAUSES:
# - CPU/Memory limits too low during traffic spike
# - Database connection pool exhausted  
# - External service dependency failed
```

**Root Cause Pattern**: 90% of production outages are resource exhaustion or dependencies

### Crisis 2: "Service Not Responding"

**Situation**: API endpoints timing out, mobile app broken  
**Business Impact**: Customer complaints, app store ratings dropping  

**Response Pattern**:
```bash
# VERIFY (1 minute): Service actually broken?
kubectl get svc api-service
kubectl get endpoints api-service

# TEST CONNECTIVITY (2 minutes):
kubectl run debug --image=curlimages/curl --rm -it -- sh
# Inside pod: curl api-service/health

# COMMON FIXES:
# Service selector doesn't match pod labels
# Pods not ready (failing health checks)  
# Network policy blocking traffic
```

### Crisis 3: "Database Connection Errors"

**Situation**: Apps can't connect to database, data layer failing  
**Business Impact**: Cannot process orders, payments, user data  

**Response Pattern**:
```bash
# CHECK DATABASE PODS (1 minute):
kubectl get pods -l app=database
kubectl describe pod database-0 | grep Events

# TEST CONNECTIVITY (2 minutes):
kubectl exec -it api-pod -- nc -zv database-service 5432
kubectl exec -it api-pod -- nslookup database-service

# CHECK PERSISTENT STORAGE (1 minute):
kubectl get pvc -l app=database
kubectl describe pvc database-storage
```

## The Debugging Hierarchy: Start Here, Go Deeper

### Level 1: Pods (Are containers running?)
```bash
# Quick check
kubectl get pods -n your-namespace

# If pods not Running:
kubectl describe pod failing-pod-name
kubectl logs failing-pod-name --previous  # Previous crash logs
```

**Common Issues**:
- **CrashLoopBackOff**: App crashing on startup → Check logs
- **ImagePullBackOff**: Can't download image → Check image name/registry
- **Pending**: Can't schedule → Check resources/node capacity

### Level 2: Services (Can traffic reach pods?)
```bash
# Check service configuration
kubectl get svc your-service
kubectl get endpoints your-service

# Test service connectivity
kubectl run test --image=busybox --rm -it -- wget -qO- your-service
```

**Common Issues**:
- **No endpoints**: Service selector doesn't match pod labels
- **Connection refused**: Port mismatch between service and container
- **Timeout**: Pods not ready (health checks failing)

### Level 3: Networking (Can pods communicate?)
```bash
# Test pod-to-pod communication
kubectl get pods -o wide  # Get pod IPs
kubectl exec source-pod -- ping target-pod-ip

# Check DNS resolution
kubectl exec test-pod -- nslookup your-service
```

**Common Issues**:
- **Network policies**: Blocking traffic between namespaces/pods
- **DNS failure**: CoreDNS pods not healthy
- **Service mesh**: Sidecar proxy configuration problems

### Level 4: Resources (Enough CPU/memory?)
```bash
# Check current usage
kubectl top pods --sort-by=memory
kubectl top nodes

# Check limits and requests
kubectl describe pod your-pod | grep -A 10 "Limits\|Requests"
```

**Common Issues**:
- **OOMKilled**: Memory limit too low
- **CPU throttling**: CPU limit too restrictive  
- **Node pressure**: Node out of resources

## The Production Debugging Toolkit

### Essential Commands Every Engineer Needs

```bash
# Health Overview
kubectl get all -n namespace
kubectl get events --sort-by='.lastTimestamp' | tail -10
kubectl top nodes && kubectl top pods

# Pod Investigation  
kubectl describe pod pod-name
kubectl logs pod-name --previous --tail=100
kubectl exec -it pod-name -- /bin/sh

# Service Testing
kubectl get endpoints service-name
kubectl port-forward svc/service-name 8080:80
curl localhost:8080

# Network Debugging
kubectl run netshoot --rm -it --image=nicolaka/netshoot -- bash
kubectl exec pod -- nc -zv service-name port

# Resource Analysis
kubectl describe node node-name | grep -A 10 "Allocated resources"
kubectl get pods --all-namespaces --sort-by='.status.containerStatuses[0].restartCount'
```

### Power User Debugging (Kubernetes 1.23+)

```bash
# Debug running pods without SSH access
kubectl debug pod-name -it --image=busybox --target=container-name

# Debug minimal/distroless containers  
kubectl debug pod-name -it --image=nicolaka/netshoot --share-processes

# Create debug copy of broken pod
kubectl debug pod-name --copy-to=debug-pod --image=ubuntu:20.04

# Debug node issues
kubectl debug node/node-name -it --image=ubuntu:20.04
```

## Common Problems and 30-Second Fixes

### Problem: "Pods Keep Crashing"
```bash
# Quick diagnosis
kubectl logs pod-name --previous | tail -20

# Common causes and fixes:
# Memory limit too low → Increase memory limit
# Missing environment variable → Check configmap/secret
# Health check too aggressive → Adjust probe timing
# App bug → Review application logs
```

### Problem: "Service Not Reachable"  
```bash
# Quick diagnosis
kubectl get endpoints service-name

# Common causes and fixes:
# No endpoints → Fix label selector
# Wrong port → Check service/container port match
# Pods not ready → Fix health checks
```

### Problem: "DNS Not Working"
```bash
# Quick diagnosis
kubectl exec pod -- nslookup kubernetes.default

# Common causes and fixes:
# CoreDNS down → Restart coredns pods
# Network policy → Allow DNS traffic (port 53)
# Wrong service name → Use fully qualified name
```

### Problem: "Out of Resources"
```bash
# Quick diagnosis  
kubectl top nodes && kubectl describe nodes | grep -A 5 "Allocated resources"

# Common causes and fixes:
# No CPU/memory → Scale cluster or reduce requests
# No storage → Provision more volumes  
# Image pull backoff → Clean up old images on nodes
```

## Production Troubleshooting Checklist

### Before You Start (1 minute)
- [ ] Get complete cluster overview: `kubectl get nodes,pods --all-namespaces`
- [ ] Check recent events: `kubectl get events --sort-by='.lastTimestamp' | tail -20`
- [ ] Verify your own app: `kubectl get all -n your-namespace`

### Pod Issues (2-3 minutes)
- [ ] Pod status: `kubectl get pods -o wide`
- [ ] Pod events: `kubectl describe pod pod-name | grep -A 10 Events`
- [ ] Current logs: `kubectl logs pod-name --tail=50`  
- [ ] Previous logs: `kubectl logs pod-name --previous --tail=50`
- [ ] Resource usage: `kubectl top pod pod-name`

### Service Issues (2 minutes)  
- [ ] Service endpoints: `kubectl get endpoints service-name`
- [ ] Label matching: `kubectl get pods --show-labels | grep app-name`
- [ ] Port configuration: `kubectl describe svc service-name`
- [ ] Direct test: `kubectl port-forward svc/service-name 8080:80`

### Network Issues (3 minutes)
- [ ] Pod connectivity: `kubectl exec pod1 -- ping pod2-ip`
- [ ] DNS resolution: `kubectl exec pod -- nslookup service-name`
- [ ] Network policies: `kubectl get networkpolicies`
- [ ] Service mesh: Check sidecar logs if using Istio/Linkerd

### Resource Issues (2 minutes)
- [ ] Node capacity: `kubectl top nodes`  
- [ ] Pod resource usage: `kubectl top pods --sort-by=memory`
- [ ] Resource limits: `kubectl describe pod pod-name | grep Limits`
- [ ] Storage: `kubectl get pvc,pv`

## Advanced Debugging Scenarios

### Scenario: "Intermittent Failures"
**Problem**: Service works sometimes, fails randomly  
**Pattern**: Usually network policies, resource limits, or load balancing

```bash
# Monitor in real-time
kubectl logs -f -l app=your-app --tail=0

# Check load balancing
kubectl get endpoints service-name -w

# Monitor resource usage
watch kubectl top pods -l app=your-app
```

### Scenario: "Slow Performance"  
**Problem**: Service responds but very slowly  
**Pattern**: Usually resource constraints or external dependencies

```bash
# Check resource throttling
kubectl describe pod pod-name | grep -A 5 "cpu\|memory"

# Monitor metrics
kubectl top pods --containers

# Check external dependencies
kubectl exec pod -- time curl external-service
```

### Scenario: "Configuration Issues"
**Problem**: App can't find config or secrets  
**Pattern**: Usually mounting or environment variable problems

```bash
# Check mounted configs
kubectl exec pod -- ls -la /path/to/config

# Check environment variables
kubectl exec pod -- printenv | grep YOUR_VAR

# Verify configmap/secret exists
kubectl get configmaps,secrets -n namespace
```

## Emergency Response Commands

### When Everything is Broken
```bash
# Nuclear option: Get all info fast
kubectl get all --all-namespaces > cluster-state.txt
kubectl describe nodes > node-state.txt  
kubectl get events --all-namespaces --sort-by='.lastTimestamp' > events.txt
```

### When You Need Help
```bash
# Export broken resources for analysis
kubectl get pod broken-pod -o yaml > broken-pod.yaml
kubectl describe pod broken-pod > broken-pod-description.txt
kubectl logs broken-pod --all-containers --previous > broken-pod-logs.txt
```

### When Time is Critical  
```bash
# Quick scale up (buy time while debugging)
kubectl scale deployment app --replicas=10

# Quick rollback (if recent deployment)
kubectl rollout undo deployment/app

# Quick restart (if pods are wedged)
kubectl rollout restart deployment/app
```

## Quick Revision Primer

### The 2AM Debugging Hierarchy
1. **Pods** → Are containers running? (`kubectl get pods`)
2. **Services** → Can traffic reach pods? (`kubectl get endpoints`)  
3. **Network** → Can pods communicate? (`kubectl exec pod -- ping`)
4. **Resources** → Enough CPU/memory? (`kubectl top`)
5. **Config** → Are settings correct? (`kubectl describe`)

### Essential Commands for Any Crisis
```bash
kubectl get all -n namespace              # Overview
kubectl get events --sort-by=lastTimestamp # Recent activity  
kubectl logs pod-name --previous          # Crash logs
kubectl describe pod pod-name              # Detailed status
kubectl top nodes && kubectl top pods     # Resource usage
kubectl exec pod -- command               # Test from inside
```

### Common Problem Patterns  
- **CrashLoopBackOff** → Check logs (`kubectl logs --previous`)
- **No endpoints** → Check service selector vs pod labels
- **Pending pods** → Check node resources (`kubectl top nodes`)
- **DNS issues** → Test with `nslookup` from inside pod
- **Network issues** → Check NetworkPolicies and service mesh

### Emergency Fixes
- **Scale up fast**: `kubectl scale deployment app --replicas=N`
- **Restart pods**: `kubectl rollout restart deployment/app`  
- **Rollback release**: `kubectl rollout undo deployment/app`
- **Get external IP**: `kubectl get svc | grep LoadBalancer`

### When You're Stuck
1. Export the broken resource: `kubectl get pod broken -o yaml`
2. Check events: `kubectl describe pod broken | grep Events`
3. Get help with full context: logs + description + yaml
4. Don't guess—systematic investigation always wins

**Remember**: In production crises, being methodical beats being fast. Follow the checklist, document what you find, and always understand the root cause before declaring victory.