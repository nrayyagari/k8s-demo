# Taints and Tolerations: Node-Centric Pod Scheduling

## WHY Taints and Tolerations Exist

**Problem**: Default scheduler places pods anywhere, causing resource conflicts, security issues, and inefficient utilization  
**Solution**: Nodes control what pods they accept through taints, pods prove they can handle restrictions through tolerations

## The Fundamental Question

**How do we ensure only appropriate pods run on specialized nodes?**

Think of it as a **Bouncer Pattern**:
- **Taint** = Node says "I have restrictions, not everyone allowed"
- **Toleration** = Pod says "I can handle your restrictions"

## Core Concepts: First Principles

### The Control Direction
Unlike affinity (pod chooses node), taints give **nodes control** over pod placement:
- Node sets restrictions (taints)
- Pod must prove compatibility (tolerations)
- No toleration = immediate rejection

### The Three Taint Effects (Enforcement Levels)

| Effect | Behavior | Use Case |
|--------|----------|----------|
| `NoSchedule` | Reject new pods, existing stay | Resource isolation |
| `PreferNoSchedule` | Avoid if possible (soft) | Performance optimization |
| `NoExecute` | Evict existing + reject new | Maintenance, failures |

## Production Scenarios: When You Need This at 2AM

### GPU Node Crisis
**Scenario**: "Our $50k GPU nodes are running nginx pods, ML training is failing"
```bash
# Emergency GPU isolation
kubectl taint nodes gpu-node-1 hardware=gpu:NoSchedule
kubectl taint nodes gpu-node-2 hardware=gpu:NoSchedule
```

### Maintenance Window Disaster
**Scenario**: "Node needs patching but critical pods can't move"
```bash
# Prevent new scheduling, allow existing
kubectl taint nodes worker-3 maintenance=patching:NoSchedule

# Later: Force eviction with grace period
kubectl taint nodes worker-3 maintenance=patching:NoExecute
```

### Multi-Tenant Security Breach
**Scenario**: "Customer A's pod accessed Customer B's data on shared node"
```bash
# Immediate tenant isolation
kubectl taint nodes tenant-a-nodes customer=tenant-a:NoExecute
kubectl taint nodes tenant-b-nodes customer=tenant-b:NoExecute
```

## Learning Path: Start Simple, Build Complexity

### 1. Basic Isolation (Start Here)
```bash
kubectl apply -f 01-basic-isolation.yaml
```

### 2. Multiple Taint Effects
```bash
kubectl apply -f 02-taint-effects.yaml
```

### 3. System Pod Management
```bash
kubectl apply -f 03-system-pods.yaml
```

### 4. Production Multi-Tenant Setup
```bash
kubectl apply -f 04-production-tenancy.yaml
```

### 5. Emergency Scenarios
```bash
kubectl apply -f 05-emergency-scenarios.yaml
```

## Toleration Operators: How Matching Works

### Equal (Exact Match)
```yaml
tolerations:
- key: workload
  operator: Equal
  value: database
  effect: NoSchedule
```
**Matches**: `workload=database:NoSchedule`

### Exists (Key-Only Match)
```yaml
tolerations:
- key: workload
  operator: Exists
  effect: NoSchedule
```
**Matches**: Any `workload=*:NoSchedule`

### Master Node Pattern (Common System Toleration)
```yaml
tolerations:
- key: node-role.kubernetes.io/control-plane
  operator: Exists
  effect: NoSchedule
```

## Essential Commands for Operations

### Taint Management
```bash
# Add taint
kubectl taint nodes node1 key=value:NoSchedule

# Remove specific taint
kubectl taint nodes node1 key=value:NoSchedule-

# Remove all taints with key
kubectl taint nodes node1 key-

# View node taints
kubectl describe node node1 | grep -i taint
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

### Debugging Scheduling Issues
```bash
# Check why pod is pending
kubectl describe pod <pod-name> | grep -A 10 Events

# See taint-related events
kubectl get events --field-selector reason=FailedScheduling

# Check scheduler decision
kubectl describe pod <pod-name> | grep -A 5 "Node-Selectors"
```

### Emergency Operations
```bash
# Cordon node (prevent new pods)
kubectl cordon node1

# Drain node (move all pods)
kubectl drain node1 --ignore-daemonsets --delete-emptydir-data

# Make all system pods tolerate everything (emergency)
kubectl patch daemonset kube-proxy -n kube-system -p '{"spec":{"template":{"spec":{"tolerations":[{"operator":"Exists"}]}}}}'
```

## Enterprise Patterns

### GPU Resource Management
```yaml
# GPU nodes accept only ML workloads
Taint: hardware=gpu:NoSchedule
Tolerations: ML training pods only
```

### Master Node Protection
```yaml
# Control plane isolation (automatic)
Taint: node-role.kubernetes.io/control-plane:NoSchedule
Tolerations: System pods only
```

### Customer Isolation
```yaml
# Multi-tenant separation
Taint: customer=tenant-a:NoExecute
Tolerations: Only tenant-a pods
```

### Spot Instance Handling
```yaml
# Spot instance preparation
Taint: node.kubernetes.io/instance-type=spot:NoSchedule
Tolerations: Fault-tolerant workloads only
```

## Common Mistakes and Solutions

### Mistake 1: Forgetting System Pods
**Problem**: Taint nodes, system pods can't schedule
**Solution**: Check DaemonSets have proper tolerations
```bash
kubectl get daemonsets -A -o yaml | grep -A 10 tolerations
```

### Mistake 2: Wrong Toleration Seconds
**Problem**: Pods evicted too quickly during maintenance
**Solution**: Use `tolerationSeconds` for graceful handling
```yaml
tolerations:
- key: node.kubernetes.io/unreachable
  operator: Exists
  effect: NoExecute
  tolerationSeconds: 300  # 5 minutes grace
```

### Mistake 3: Taint Effect Confusion
**Problem**: Using NoExecute when you meant NoSchedule
**Solution**: Understand the difference
- `NoSchedule`: New pods rejected, existing stay
- `NoExecute`: All pods evicted immediately

## Real-World Impact

**Resource Efficiency**: 40% better GPU utilization by preventing non-ML workloads  
**Security Compliance**: PCI-DSS compliance through tenant isolation  
**Operational Safety**: Zero-downtime maintenance windows  
**Cost Optimization**: Spot instances only for fault-tolerant workloads  

## Best Practice: Progressive Restrictions

1. **Start with PreferNoSchedule** (soft enforcement)
2. **Monitor placement patterns** 
3. **Upgrade to NoSchedule** (hard enforcement)
4. **Use NoExecute only for emergencies**

## Implementation Guidance

### Step 1: Identify Node Classes
- Hardware types (CPU, GPU, high-memory)
- Availability tiers (spot, on-demand, reserved)
- Customer segments (tenant-a, tenant-b, shared)

### Step 2: Design Taint Strategy
- Use descriptive keys (`workload`, `customer`, `hardware`)
- Consistent naming across clusters
- Document all taints in cluster runbook

### Step 3: Update Workload Manifests
- Add tolerations to appropriate pods
- Test with `kubectl apply --dry-run=server`
- Rollout incrementally, verify placement

Remember: Taints are about **access control**, not preferences. Use affinity for pod preferences, taints for node restrictions.