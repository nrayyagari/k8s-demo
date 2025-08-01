# Resource Quotas and Limits: Control Resource Usage

## WHY Do Resource Quotas and Limits Exist?

**Problem**: Developers deploy apps without resource constraints, leading to resource starvation and cluster instability  
**Solution**: ResourceQuotas limit namespace consumption, LimitRanges set default/max per container

## The Core Questions

**"How do I prevent one team from consuming all cluster resources?"** → **ResourceQuotas**
**"How do I ensure containers specify reasonable resource requests?"** → **LimitRanges**

## Resource Management Hierarchy

```
Cluster Resources (100% available)
    ↓
Namespace Quota (e.g., 50% of cluster)
    ↓  
Pod Resource Requests/Limits (within quota)
    ↓
Container Actual Usage (bounded by limits)
```

## Two Types of Resource Controls

### 1. ResourceQuota (Namespace Level)
**Purpose**: Limit total resource consumption per namespace  
**Scope**: Applies to entire namespace  

### 2. LimitRange (Container Level)  
**Purpose**: Set default/min/max resources per container  
**Scope**: Applies to individual pods/containers  

## Simple ResourceQuota Pattern

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: development
spec:
  hard:
    requests.cpu: "4"      # Total CPU requests in namespace
    requests.memory: 8Gi   # Total memory requests in namespace
    limits.cpu: "8"        # Total CPU limits in namespace  
    limits.memory: 16Gi    # Total memory limits in namespace
    persistentvolumeclaims: "4"  # Max PVCs allowed
    pods: "10"             # Max pods allowed
```

## Simple LimitRange Pattern

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: container-limits
  namespace: development
spec:
  limits:
  - type: Container
    default:              # Default limits (if not specified)
      cpu: "500m"         
      memory: "512Mi"
    defaultRequest:       # Default requests (if not specified)
      cpu: "100m"
      memory: "128Mi"
    max:                  # Maximum allowed
      cpu: "2"
      memory: "2Gi"
    min:                  # Minimum required
      cpu: "50m"
      memory: "64Mi"
```

## The Production Workflow

### Step 1: Create Namespace with Quota
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: prod-quota
  namespace: production
spec:
  hard:
    requests.cpu: "20"      # 20 CPU cores for requests
    requests.memory: "40Gi" # 40GB RAM for requests
    limits.cpu: "40"        # 40 CPU cores for limits
    limits.memory: "80Gi"   # 80GB RAM for limits
```

### Step 2: Set Container Defaults
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: prod-limits
  namespace: production
spec:
  limits:
  - type: Container
    default:
      cpu: "1"
      memory: "1Gi"
    defaultRequest:
      cpu: "200m"
      memory: "256Mi"
    max:
      cpu: "4"
      memory: "8Gi"
    min:
      cpu: "100m"
      memory: "128Mi"
```

## Files in This Directory

1. **01-namespace-quota.yaml** - Basic ResourceQuota example
2. **02-container-limits.yaml** - LimitRange for container defaults
3. **03-complete-setup.yaml** - Full namespace with quota and limits
4. **04-pod-with-resources.yaml** - Example pod with resource specifications
5. **SIMPLE-QUOTAS.yaml** - Quick start example

## Quick Start

```bash
# Create namespace with quota and limits
kubectl apply -f 03-complete-setup.yaml

# Check quota status
kubectl get resourcequota -n development
kubectl describe resourcequota dev-quota -n development

# Check limit ranges
kubectl get limitrange -n development
kubectl describe limitrange dev-limits -n development

# Deploy a pod and see resources applied
kubectl apply -f 04-pod-with-resources.yaml
kubectl describe pod example-pod -n development
```

## Key Resource Types

### CPU Resources
- **Measured in**: millicores (m) or cores
- **Examples**: `100m` (0.1 core), `500m` (0.5 core), `2` (2 cores)
- **Request**: Guaranteed CPU allocation
- **Limit**: Maximum CPU allowed (throttled if exceeded)

### Memory Resources  
- **Measured in**: bytes with units (Mi, Gi)
- **Examples**: `128Mi`, `1Gi`, `2Gi`
- **Request**: Guaranteed memory allocation
- **Limit**: Maximum memory allowed (killed if exceeded)

## Critical Quota Concepts

### Hard vs Soft Limits
```yaml
spec:
  hard:                    # Enforced limits (cannot exceed)
    requests.cpu: "10"
    pods: "20"
```

### Quota Scope (Advanced)
```yaml
spec:
  hard:
    pods: "10"
  scopes: ["BestEffort"]   # Only count BestEffort pods
```

## The Resource Equation

**For a pod to be scheduled:**
1. Namespace must have quota remaining
2. Pod resources must fit within LimitRange constraints  
3. Node must have capacity for the requests

**Example Calculation:**
- Namespace quota: 4 CPU requests remaining
- LimitRange max: 2 CPU per container
- Pod request: 1 CPU → ✅ Allowed
- Pod request: 5 CPU → ❌ Exceeds quota

## Real-World Scenarios

### Scenario 1: Development Team Isolation
```yaml
# Each team gets their own namespace quota
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-a-quota
  namespace: team-a
spec:
  hard:
    requests.cpu: "8"
    requests.memory: "16Gi"
    persistentvolumeclaims: "5"
```

### Scenario 2: Environment-Based Limits
```yaml
# Production: Higher limits, stricter controls
# Development: Lower limits, more flexible
apiVersion: v1
kind: LimitRange
metadata:
  name: prod-strict-limits
  namespace: production
spec:
  limits:
  - type: Container
    max:
      cpu: "2"      # Max 2 cores per container
      memory: "4Gi" # Max 4GB per container
```

## Monitoring and Troubleshooting

### Check Quota Usage
```bash
# See quota utilization
kubectl get resourcequota -A
kubectl describe resourcequota <name> -n <namespace>

# Check which resources are consuming quota
kubectl get pods -n <namespace> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources}{"\n"}{end}'
```

### Common Issues

**Pod stuck in Pending with quota exceeded:**
```bash
kubectl describe pod <pod-name> -n <namespace>
# Look for: "exceeded quota" in events
```

**Solution**: Increase quota or reduce pod resource requests

**Pod getting default resources applied:**
```bash
kubectl describe pod <pod-name> -n <namespace>
# Check if resources section shows defaulted values
```

## Best Practices

### 1. Always Set Requests and Limits
```yaml
# ✅ Good - explicit resource specification
resources:
  requests:
    cpu: "200m"
    memory: "256Mi"
  limits:
    cpu: "500m" 
    memory: "512Mi"

# ❌ Bad - no resource specification (relies on defaults)
resources: {}
```

### 2. Set Reasonable Defaults via LimitRange
```yaml
# Set sensible defaults so developers don't have to specify every time
defaultRequest:
  cpu: "100m"
  memory: "128Mi"
default:
  cpu: "500m"
  memory: "512Mi"
```

### 3. Monitor Quota Usage
```bash
# Regularly check quota consumption
kubectl get resourcequota -A -o wide
```

## When You Need Resource Controls

✅ **Multi-tenant clusters** - Prevent resource monopolization  
✅ **Cost control** - Limit cloud spend per team/environment  
✅ **Performance isolation** - Ensure critical apps get resources  
✅ **Capacity planning** - Understand resource consumption patterns  

❌ **Single-tenant clusters** with trusted users  
❌ **Development environments** with unlimited resources  
❌ **Proof-of-concept** clusters  

## Key Insights

**Resource quotas are cluster economics** - they distribute finite resources fairly across teams and applications.

**LimitRanges are safety nets** - they prevent accidentally creating resource-hungry containers.

**The 90/10 rule applies**:
- **90% of containers**: Use default resources set by LimitRange
- **10% of containers**: Need custom resource specifications

**Production reality**: Most issues are caused by missing resource specifications, not exceeding quotas.

Think of quotas as "resource budgets" and limits as "spending controls" - both essential for running stable, cost-effective clusters.