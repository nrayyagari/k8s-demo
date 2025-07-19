# Kubernetes Troubleshooting & Debugging

## WHY Troubleshooting Skills Matter

**Problem**: Kubernetes systems are complex - pods crash, services don't respond, networking fails  
**Solution**: Systematic debugging approach using the right tools and methods

## The Fundamental Questions

**"My application isn't working - where do I start?"**  
**"How do I find the root cause quickly and efficiently?"**

## The Kubernetes Debugging Hierarchy

```
1. Pods (Are containers running?)
   ↓
2. Services (Can traffic reach pods?)
   ↓  
3. Networking (Can pods communicate?)
   ↓
4. DNS (Can services be resolved?)
   ↓
5. Resources (Enough CPU/memory?)
   ↓
6. Configuration (ConfigMaps/Secrets working?)
```

## Core Debugging Commands

### Essential kubectl Commands
```bash
# Get overview of resources
kubectl get all -n <namespace>
kubectl get events --sort-by='.lastTimestamp'

# Deep dive into specific resources  
kubectl describe pod <pod-name>
kubectl describe service <service-name>
kubectl describe node <node-name>

# Live monitoring
kubectl logs -f <pod-name> [-c container-name]
kubectl top pods
kubectl top nodes

# Interactive debugging
kubectl exec -it <pod-name> -- /bin/sh
kubectl port-forward <pod-name> 8080:80
```

### The Debug Workflow

#### Step 1: Get the Big Picture
```bash
# Check cluster health
kubectl get nodes
kubectl get all --all-namespaces

# Look for obvious problems
kubectl get events --sort-by='.lastTimestamp' | tail -20
```

#### Step 2: Focus on Your Application
```bash
# Check your namespace
kubectl get all -n <your-namespace>

# Look for failed pods
kubectl get pods -n <your-namespace> | grep -v Running

# Check recent events
kubectl get events -n <your-namespace> --sort-by='.lastTimestamp'
```

#### Step 3: Drill Down
```bash
# Investigate specific pods
kubectl describe pod <failing-pod>
kubectl logs <failing-pod> --previous  # Previous crash logs
```

## Common Scenarios & Solutions

### Scenario 1: Service Not Responding

**Symptoms**: 
- `curl` to service times out
- External traffic can't reach application
- Internal services can't communicate

#### The Service Debugging Checklist

**1. Check if Service exists and has endpoints**
```bash
kubectl get svc <service-name>
kubectl describe svc <service-name>
kubectl get endpoints <service-name>
```

**2. Verify Service selector matches Pod labels**
```bash
# Check service selector
kubectl get svc <service-name> -o yaml | grep -A 5 selector

# Check pod labels  
kubectl get pods --show-labels | grep <app-name>
```

**3. Test Service connectivity**
```bash
# From within cluster
kubectl run debug --image=busybox -it --rm -- /bin/sh
wget -qO- http://<service-name>.<namespace>.svc.cluster.local

# Port forward for external testing
kubectl port-forward svc/<service-name> 8080:80
curl localhost:8080
```

**4. Check Pod readiness**
```bash
kubectl get pods -o wide
kubectl describe pod <pod-name> | grep -A 10 Conditions
```

### Scenario 2: Pod Startup Issues

**Symptoms**:
- Pod stuck in Pending state
- Pod in CrashLoopBackOff
- Pod starts but doesn't become Ready

#### Pod Startup Debugging

**1. Check Pod status and events**
```bash
kubectl get pods
kubectl describe pod <pod-name>
kubectl get events --field-selector involvedObject.name=<pod-name>
```

**2. Common Pending Issues**
```bash
# Resource constraints
kubectl describe pod <pod-name> | grep -A 5 "Events"
# Look for: "Insufficient cpu", "Insufficient memory"

# Check node capacity
kubectl top nodes
kubectl describe nodes

# Scheduling constraints
kubectl describe pod <pod-name> | grep -A 10 "Node-Selectors"
```

**3. CrashLoopBackOff Investigation**
```bash
# Current logs
kubectl logs <pod-name>

# Previous crash logs (critical!)
kubectl logs <pod-name> --previous

# Container exit codes
kubectl describe pod <pod-name> | grep "Exit Code"
```

### Scenario 3: DNS Resolution Issues

**Symptoms**:
- Pods can't resolve service names
- External DNS not working
- Intermittent connectivity issues

#### DNS Debugging Process

**1. Test DNS from within a pod**
```bash
kubectl run dnsutils --image=tutum/dnsutils -it --rm -- /bin/bash

# Test service DNS
nslookup <service-name>
nslookup <service-name>.<namespace>.svc.cluster.local

# Test external DNS
nslookup google.com

# Check DNS config
cat /etc/resolv.conf
```

**2. Check CoreDNS health**
```bash
kubectl get pods -n kube-system | grep coredns
kubectl logs -n kube-system <coredns-pod>
kubectl describe cm coredns -n kube-system
```

### Scenario 4: Networking Issues

**Symptoms**:
- Pods can't reach other pods
- Services work but pod-to-pod doesn't
- Ingress not routing correctly

#### Network Debugging

**1. Test pod-to-pod connectivity**
```bash
# Get pod IPs
kubectl get pods -o wide

# Test direct pod communication
kubectl exec -it <pod1> -- ping <pod2-ip>
kubectl exec -it <pod1> -- telnet <pod2-ip> <port>
```

**2. Check network policies**
```bash
kubectl get networkpolicies
kubectl describe networkpolicy <policy-name>
```

**3. Test service mesh issues (if using Istio/Linkerd)**
```bash
# Check sidecar injection
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].name}'

# Service mesh logs
kubectl logs <pod-name> -c istio-proxy
```

### Scenario 5: Resource Issues

**Symptoms**:
- Pods getting OOMKilled
- Node becomes NotReady
- Performance degradation

#### Resource Debugging

**1. Check resource usage**
```bash
kubectl top nodes
kubectl top pods --all-namespaces --sort-by memory
kubectl top pods --all-namespaces --sort-by cpu
```

**2. Investigate resource limits**
```bash
kubectl describe pod <pod-name> | grep -A 10 Limits
kubectl describe pod <pod-name> | grep -A 10 Requests
```

**3. Check node conditions**
```bash
kubectl describe node <node-name> | grep -A 10 Conditions
kubectl describe node <node-name> | grep -A 10 "Allocated resources"
```

## Advanced Debugging Techniques

### Using kubectl debug (K8s 1.23+)

#### Why kubectl debug?
**Problem**: Production containers often lack debugging tools (distroless images, minimal containers)  
**Solution**: Attach ephemeral containers with full debugging toolset

#### Basic Debug Patterns
```bash
# Attach debug container to running pod
kubectl debug <pod-name> -it --image=busybox --target=<container-name>

# Debug with network tools
kubectl debug <pod-name> -it --image=nicolaka/netshoot --target=<container>

# Create debug copy of pod with modifications
kubectl debug <pod-name> --copy-to=<debug-pod-name> --image=<new-image>

# Debug with elevated privileges
kubectl debug <pod-name> -it --image=busybox --privileged

# Debug node issues
kubectl debug node/<node-name> -it --image=busybox
```

#### When to Use kubectl debug
- **Distroless containers**: No shell or tools available
- **Minimal images**: Missing debugging utilities  
- **Permission issues**: Need elevated privileges
- **Network debugging**: Need specialized network tools
- **Process analysis**: Need to inspect running processes
- **Memory debugging**: Need profiling tools

### Network Policy Testing
```bash
# Create test pods in different namespaces
kubectl run test-pod-1 --image=busybox -n namespace1 -- sleep 3600
kubectl run test-pod-2 --image=busybox -n namespace2 -- sleep 3600

# Test cross-namespace communication
kubectl exec -n namespace1 test-pod-1 -- ping test-pod-2.namespace2.svc.cluster.local
```

### Performance Profiling
```bash
# CPU profiling
kubectl exec -it <pod-name> -- top
kubectl exec -it <pod-name> -- ps aux

# Memory analysis
kubectl exec -it <pod-name> -- cat /proc/meminfo
kubectl exec -it <pod-name> -- free -h
```

## Troubleshooting Checklist

### Pre-Investigation
- [ ] Check cluster status: `kubectl get nodes`
- [ ] Check system pods: `kubectl get pods -n kube-system`
- [ ] Review recent events: `kubectl get events --sort-by='.lastTimestamp' | tail -20`

### Pod Issues
- [ ] Pod status: `kubectl get pods`
- [ ] Pod details: `kubectl describe pod <name>`
- [ ] Pod logs: `kubectl logs <name> --previous`
- [ ] Resource usage: `kubectl top pod <name>`

### Service Issues  
- [ ] Service exists: `kubectl get svc`
- [ ] Endpoints exist: `kubectl get endpoints`
- [ ] Label matching: Compare service selector with pod labels
- [ ] Port configuration: Check service and container ports

### Network Issues
- [ ] Pod-to-pod connectivity: `ping` between pod IPs
- [ ] DNS resolution: `nslookup` from within pods
- [ ] Network policies: `kubectl get networkpolicies`
- [ ] Ingress rules: `kubectl describe ingress`

### Resource Issues
- [ ] Node capacity: `kubectl top nodes`
- [ ] Pod resource usage: `kubectl top pods`
- [ ] Resource limits: Check pod specifications
- [ ] Storage issues: `kubectl get pv,pvc`

## Common Error Patterns

### Image Issues
```bash
# ImagePullBackOff
kubectl describe pod <name> | grep -A 5 "Failed to pull image"
# Check: Image name, registry auth, network connectivity

# ErrImagePull  
kubectl describe pod <name> | grep -A 5 "Error pulling image"
# Check: Image exists, correct tag, registry permissions
```

### Configuration Issues
```bash
# ConfigMap/Secret not found
kubectl get configmaps,secrets
kubectl describe pod <name> | grep -A 5 "Volume"

# Environment variable issues
kubectl exec -it <pod> -- printenv
```

### Storage Issues
```bash
# PVC binding issues
kubectl get pvc
kubectl describe pvc <name>
kubectl get pv

# Mount issues
kubectl describe pod <name> | grep -A 10 "Mounts"
kubectl exec -it <pod> -- df -h
```

## Tools for Advanced Debugging

### Kubernetes Dashboard
```bash
# Deploy dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Access dashboard
kubectl proxy
```

### Monitoring Tools
```bash
# Metrics server
kubectl top nodes
kubectl top pods

# Custom metrics
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods
```

### Log Aggregation
```bash
# Multiple pod logs
kubectl logs -l app=<app-name> --tail=100

# Follow logs from multiple pods
kubectl logs -f -l app=<app-name> --max-log-requests=10
```

## Best Practices for Debugging

### 1. Start with High-Level View
Always begin with cluster and namespace overview before diving into specifics.

### 2. Check Events First
Events often contain the root cause information you need.

### 3. Use Labels Effectively
```bash
kubectl get pods -l app=<app-name>
kubectl logs -l app=<app-name> --tail=50
```

### 4. Preserve Evidence
```bash
# Save pod description before deletion
kubectl describe pod <failing-pod> > debug-pod-description.txt

# Export problematic resources
kubectl get pod <name> -o yaml > debug-pod.yaml
```

### 5. Test in Isolation
Create minimal test cases to isolate problems from complex applications.

## Emergency Debugging Commands

### Quick Health Check
```bash
kubectl get nodes,pods --all-namespaces | grep -v Running
kubectl get events --sort-by='.lastTimestamp' | tail -10
```

### Resource Emergency
```bash
kubectl top nodes --sort-by cpu
kubectl top pods --all-namespaces --sort-by memory | head -20
```

### Network Emergency
```bash
# Test DNS quickly
kubectl run dnstest --image=busybox -it --rm -- nslookup kubernetes.default

# Test connectivity
kubectl run nettest --image=busybox -it --rm -- wget -T 5 -qO- http://<service>
```

## Files in This Directory

1. **SIMPLE-DEBUG.yaml** - Basic troubleshooting starter examples
2. **01-service-debugging.yaml** - Service connectivity issues and solutions  
3. **02-pod-startup-issues.yaml** - Pod startup failures and debugging
4. **03-networking-dns.yaml** - Network and DNS troubleshooting scenarios
5. **04-resource-debugging.yaml** - Resource pressure and performance issues
6. **05-kubectl-debug.yaml** - Advanced debugging with ephemeral containers

## Real-World Debugging Impact

**Reduced MTTR**: Systematic approach cuts incident resolution time from hours to minutes  
**Faster Root Cause Analysis**: Proper event and log analysis quickly identifies issues  
**Preventive Insights**: Understanding failure patterns helps prevent future incidents  
**Team Efficiency**: Standardized debugging process enables any team member to troubleshoot