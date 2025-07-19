# Pod Scheduling: Taints/Tolerations vs Affinity/Anti-affinity

## WHY Scheduling Controls Exist

**Problem**: Default scheduler doesn't understand business requirements  
**Solution**: Fine-grained control over WHERE pods run and WITH WHAT

## The Fundamental Question

**Where should my pod run and what should it avoid?**

Two approaches:
1. **Node-Centric**: Nodes control what they accept (Taints/Tolerations)
2. **Pod-Centric**: Pods express preferences (Affinity/Anti-affinity)

## Core Concepts: First Principles

### The Control Direction

**Taints/Tolerations** → Node controls access  
**Affinity/Anti-affinity** → Pod expresses preferences

### The Decision Matrix

| Scenario | Pattern | Why |
|----------|---------|-----|
| "Only ML workloads on GPU nodes" | Taints/Tolerations | Node enforces restriction |
| "Web server near its database" | Pod Affinity | Pod wants performance |
| "Spread replicas for HA" | Pod Anti-affinity | Pod wants availability |
| "No pods during maintenance" | Taints | Node rejects everything |

## Taints/Tolerations: Node-Centric Control

### The Bouncer Pattern
- **Taint** = Node says "I don't accept everyone"
- **Toleration** = Pod says "I can handle that restriction"

### Three Taint Effects
1. **NoSchedule**: New pods rejected (existing stay)
2. **PreferNoSchedule**: Avoid if possible (soft)
3. **NoExecute**: Evict existing + reject new pods

### Common Use Cases
- **Hardware isolation**: GPU nodes, high-memory nodes
- **Dedicated nodes**: Master nodes, system pods only
- **Maintenance**: Drain nodes safely
- **Multi-tenancy**: Separate customer workloads

## Affinity/Anti-affinity: Pod-Centric Preferences  

### The Preference Pattern
- **Affinity** = Pod says "I want to be near X"
- **Anti-affinity** = Pod says "I don't want to be near Y"

### Two Enforcement Levels
1. **Required**: Must satisfy (hard constraint)
2. **Preferred**: Try to satisfy (soft constraint)

### Common Use Cases
- **Performance**: Co-locate app with database
- **High Availability**: Spread replicas across zones
- **Resource efficiency**: Group related services
- **Compliance**: Separate sensitive workloads

## Node Affinity vs Pod Affinity

### Node Affinity
Pod expresses preference for **node characteristics**
```yaml
# "I want nodes with SSD storage"
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
    - matchExpressions:
      - key: disk-type
        operator: In
        values: ["ssd"]
```

### Pod Affinity  
Pod expresses preference for **proximity to other pods**
```yaml
# "I want to be near Redis pods"
podAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
  - labelSelector:
      matchLabels:
        app: redis
    topologyKey: kubernetes.io/hostname
```

## Learning Path

### 1. Start with Taints/Tolerations (Simple)
```bash
kubectl apply -f 01-basic-taints.yaml
```

### 2. Node Affinity (Medium)
```bash
kubectl apply -f 02-node-affinity.yaml
```

### 3. Pod Affinity for Performance (Medium)
```bash
kubectl apply -f 03-pod-affinity.yaml
```

### 4. Pod Anti-affinity for HA (Advanced)
```bash
kubectl apply -f 04-pod-antiaffinity.yaml
```

### 5. Complex Multi-tier App (Advanced)
```bash
kubectl apply -f 05-complex-scheduling.yaml
```

## Key Principles Applied

### 1. Topology Keys Matter
```yaml
# Same node
topologyKey: kubernetes.io/hostname

# Same zone  
topologyKey: topology.kubernetes.io/zone

# Same region
topologyKey: topology.kubernetes.io/region
```

### 2. Weight-based Preferences
```yaml
# Prefer SSD nodes (weight 80), fallback to HDD (weight 20)
preferredDuringSchedulingIgnoredDuringExecution:
- weight: 80
  preference:
    matchExpressions:
    - key: disk-type
      operator: In
      values: ["ssd"]
```

### 3. Multiple Constraints Combine
- All required constraints must be satisfied
- Preferred constraints are scored and best match wins
- Taints must be tolerated regardless of affinity

## Testing Commands

### Check node taints:
```bash
kubectl describe nodes | grep -i taint
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

### View pod placement:
```bash
kubectl get pods -o wide
kubectl describe pod <pod-name> | grep -A 5 "Node-Selectors"
```

### Taint operations:
```bash
# Add taint
kubectl taint nodes node1 key=value:NoSchedule

# Remove taint  
kubectl taint nodes node1 key=value:NoSchedule-
```

### Test scheduling constraints:
```bash
kubectl get events --sort-by='.lastTimestamp'
kubectl describe pod <pod-name> | grep -A 10 Events
```

## Enterprise Patterns

### Multi-tier Application
- **Database**: High-memory nodes + avoid other databases
- **Cache**: Near database + SSD nodes
- **Web**: Spread across zones + avoid resource competition

### GPU Workloads
- **Training**: Dedicated GPU nodes + tolerate ML taints
- **Inference**: Prefer GPU, fallback to CPU
- **Development**: Share GPU nodes

### Compliance Separation
- **PCI workloads**: Dedicated nodes + strict isolation
- **Public data**: General nodes + cost optimization
- **Audit logs**: Specific nodes + retention policies

## Real-World Impact

**Cost optimization**: Pack compatible workloads, isolate expensive resources  
**Performance**: Co-locate related services, avoid resource conflicts  
**Availability**: Spread critical services across failure domains  
**Compliance**: Enforce data locality and isolation requirements  
**Operations**: Simplify maintenance and troubleshooting