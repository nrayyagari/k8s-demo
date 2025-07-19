# Pod Disruption Budgets: Keep Your App Running During Maintenance

## WHY Do Pod Disruption Budgets Exist?

**Problem**: Node maintenance or cluster upgrades could take down too many pods at once  
**Solution**: PDB ensures minimum pods stay running during voluntary disruptions

## The Core Question

**"How do I prevent maintenance from breaking my app?"**

Without PDB: Maintenance drains nodes randomly → might kill all your pods  
With PDB: Kubernetes respects your availability requirements during planned disruptions

## What PDBs Protect Against

### Voluntary Disruptions (PDB helps)
- Node maintenance and reboots
- Cluster upgrades  
- Node pool scaling down
- kubectl drain operations

### Involuntary Disruptions (PDB doesn't help)
- Hardware failures
- Kernel panics
- Network partitions
- Out of resources

## Simple Pattern

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-app-pdb
spec:
  minAvailable: 2        # Keep at least 2 pods running
  # OR: maxUnavailable: 1  # Allow max 1 pod down
  selector:
    matchLabels:
      app: my-app
```

## Two Ways to Specify Limits

### minAvailable (Preferred)
```yaml
minAvailable: 3          # At least 3 pods must stay running
minAvailable: "50%"      # At least 50% of pods must stay running
```

### maxUnavailable (Alternative)
```yaml
maxUnavailable: 1        # At most 1 pod can be down
maxUnavailable: "25%"    # At most 25% of pods can be down
```

## Real-World Example

```yaml
# You have 5 replicas of your web app
# You want to ensure at least 3 are always available

apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 5
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app  # PDB will target this label
    spec:
      containers:
      - name: web
        image: nginx:alpine

---
apiVersion: policy/v1
kind: PodDisruptionBudget  
metadata:
  name: web-app-pdb
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: web-app  # Must match deployment labels
```

## Files in This Directory

1. **01-webapp-pdb.yaml** - Basic PDB example with explanations

## Quick Start

```bash
# Apply PDB
kubectl apply -f 01-webapp-pdb.yaml

# Check PDB status
kubectl get pdb
kubectl describe pdb webapp-pdb

# Test with node drain (if you have multiple nodes)
kubectl drain <node-name> --ignore-daemonsets
```

## Key Insights

**PDBs are about planned disruptions only** - they don't protect against crashes or failures

**Labels must match exactly** - PDB selector must match your pod labels

**Mathematics matter** - Don't set impossible constraints:
- ❌ `minAvailable: 5` with only 3 replicas = deadlock
- ✅ `minAvailable: 2` with 3 replicas = maintenance possible

## When You Need PDBs

✅ **Production applications** with multiple replicas  
✅ **Critical services** that must maintain availability  
✅ **Clusters with regular maintenance** windows  

❌ **Single replica** deployments (PDB can't help)  
❌ **Development environments** (usually not needed)  
❌ **Batch jobs** (temporary by nature)

## Troubleshooting

```bash
# PDB blocking operations
kubectl get pdb  # Check disruptions allowed

# If PDB shows 0 disruptions allowed:
# - Increase replicas, or
# - Decrease minAvailable, or  
# - Check if pods are actually ready
```

## Key Insight

**PDBs are like insurance** - you set them up hoping you'll never need them, but they save you when maintenance happens.

Think of it as telling Kubernetes: "I can survive losing some pods, but not ALL of them at once."