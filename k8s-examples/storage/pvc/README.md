# Persistent Volume Claims (PVC): Requesting Storage

## WHY Do Persistent Volume Claims Exist?

**Problem**: Applications need storage, but shouldn't know about storage infrastructure details  
**Solution**: PVCs let applications request storage without knowing about disks, NFS servers, or cloud volumes

## The Core Question

**"How do I request storage for my application without caring about the details?"**

PVC is a **storage request** - like ordering from a menu without knowing how the kitchen works.

## PVC Fundamentals

### What is a Persistent Volume Claim?
- **Namespace Resource**: Belongs to a specific namespace
- **Storage Request**: Specifies size, access mode, and storage class
- **Pod Interface**: How pods request and use persistent storage
- **Developer Managed**: Created by application developers

### PVC in the Storage Workflow
```
1. Developer creates PVC (storage request)
2. Kubernetes finds matching PV or creates one (via StorageClass)
3. PVC gets bound to PV
4. Pod uses PVC to access storage
5. Data persists beyond pod lifecycle
```

## Simple PVC Pattern

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-pvc
  namespace: default
spec:
  accessModes:
  - ReadWriteOnce                    # How I want to access storage
  resources:
    requests:
      storage: 10Gi                  # How much storage I need
  storageClassName: fast-ssd         # What type of storage I want
```

## PVC Specifications

### Access Modes (How to Use Storage)
```yaml
# Single pod, read-write (most common)
accessModes: [ReadWriteOnce]
# Use case: Database, single-instance app

# Multiple pods, read-only
accessModes: [ReadOnlyMany]  
# Use case: Shared config, static content

# Multiple pods, read-write (requires special storage)
accessModes: [ReadWriteMany]
# Use case: Shared uploads, content management
```

### Storage Size
```yaml
resources:
  requests:
    storage: 20Gi                    # Minimum storage needed
# Note: You get AT LEAST this much storage
# PV might be larger than requested
```

### Storage Class
```yaml
storageClassName: fast-ssd           # Type of storage wanted
# storageClassName: ""               # Use default StorageClass
# storageClassName: "manual"         # Bind to pre-created PV only
```

## PVC Lifecycle States

### Pending
```bash
# PVC created but not bound to PV
STATUS: Pending
# Waiting for suitable PV or dynamic provisioning
```

### Bound
```bash
# PVC successfully bound to PV
STATUS: Bound  
# Ready to be used by pods
```

### Lost
```bash
# Bound PV no longer available
STATUS: Lost
# Requires manual intervention
```

## Common PVC Patterns

### Pattern 1: Database Storage
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: database
spec:
  accessModes: [ReadWriteOnce]       # Database needs exclusive access
  resources:
    requests:
      storage: 50Gi                  # Size for database files
  storageClassName: ssd-storage      # Fast storage for database
```

### Pattern 2: Shared Files
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-uploads-pvc
  namespace: webapp
spec:
  accessModes: [ReadWriteMany]       # Multiple pods need access
  resources:
    requests:
      storage: 100Gi                 # Space for user uploads
  storageClassName: nfs-storage      # Shared filesystem
```

### Pattern 3: Temporary Processing
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: processing-scratch-pvc
  namespace: batch-jobs
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 200Gi                 # Large temporary space
  storageClassName: local-nvme       # Fastest possible storage
```

## Using PVCs in Pods

### Single Volume Mount
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: database-pod
spec:
  containers:
  - name: postgres
    image: postgres:13
    volumeMounts:
    - name: database-storage
      mountPath: /var/lib/postgresql/data    # Where app expects data
  volumes:
  - name: database-storage
    persistentVolumeClaim:
      claimName: postgres-pvc                # Reference to PVC
```

### Multiple Volume Mounts
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app-pod
spec:
  containers:
  - name: webapp
    image: nginx:alpine
    volumeMounts:
    - name: web-content
      mountPath: /usr/share/nginx/html       # Static files
    - name: upload-storage
      mountPath: /var/uploads                # User uploads
  volumes:
  - name: web-content
    persistentVolumeClaim:
      claimName: web-content-pvc
  - name: upload-storage
    persistentVolumeClaim:
      claimName: uploads-pvc
```

## Files in This Directory

1. **01-basic-pvc.yaml** - Simple PVC examples
2. **02-database-pvc.yaml** - Database-specific PVC patterns
3. **03-shared-pvc.yaml** - Shared storage PVC examples
4. **SIMPLE-PVC.yaml** - Quick start example

## Quick Start

```bash
# Create a basic PVC
kubectl apply -f 01-basic-pvc.yaml

# Check PVC status
kubectl get pvc
kubectl describe pvc basic-storage-pvc

# See PVC binding
kubectl get pvc -o wide
```

## PVC Selection and Binding

### How Kubernetes Matches PVC to PV
```yaml
# PVC requirements
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
  storageClassName: fast-ssd

# Matching process:
# 1. Find PVs with compatible access mode
# 2. Find PVs with sufficient capacity (>= 10Gi)
# 3. Find PVs with matching storage class
# 4. Bind to best match or trigger dynamic provisioning
```

### PVC Selectors (Advanced)
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: specific-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
  selector:
    matchLabels:
      environment: production        # Only bind to PVs with this label
    matchExpressions:
    - key: tier
      operator: In
      values: [premium, enterprise]
```

## Dynamic Provisioning with PVCs

### Automatic Storage Creation
```yaml
# When this PVC is created...
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: auto-provisioned-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 20Gi
  storageClassName: aws-gp3          # References StorageClass

# ...StorageClass automatically creates:
# 1. AWS EBS volume (20Gi, gp3 type)
# 2. PersistentVolume representing the EBS volume
# 3. Binds PVC to the new PV
```

## Monitoring and Troubleshooting

### Check PVC Status
```bash
# List all PVCs
kubectl get pvc -A

# Check PVC details
kubectl describe pvc <pvc-name>

# See PVC-to-PV binding
kubectl get pvc <pvc-name> -o yaml | grep volumeName
```

### Common PVC Issues

#### Issue: PVC Stuck in Pending
```bash
# Check events for clues
kubectl describe pvc <pvc-name>

# Common causes:
# 1. No suitable PV available
kubectl get pv

# 2. StorageClass doesn't exist
kubectl get storageclass

# 3. Insufficient permissions
kubectl get events | grep ProvisioningFailed

# 4. Storage quota exceeded
kubectl describe namespace <namespace>
```

#### Issue: Pod Can't Mount PVC
```bash
# Check pod events
kubectl describe pod <pod-name>

# Common causes:
# 1. PVC not bound
kubectl get pvc

# 2. Access mode conflicts (multiple pods using RWO)
kubectl get pods -o wide | grep <pvc-name>

# 3. Node lacks storage driver
kubectl describe node <node-name>
```

#### Issue: Storage Full
```bash
# Check storage usage (if supported)
kubectl exec <pod-name> -- df -h

# Check PVC size vs usage
kubectl get pvc <pvc-name> -o yaml | grep -A 5 status
```

## PVC Expansion

### Growing Storage Size
```yaml
# Original PVC
spec:
  resources:
    requests:
      storage: 10Gi

# Expanded PVC (edit the PVC)
spec:
  resources:
    requests:
      storage: 20Gi                  # Increase size

# Requirements:
# 1. StorageClass supports expansion (allowVolumeExpansion: true)
# 2. Underlying storage supports expansion
# 3. File system supports online expansion
```

### Expansion Commands
```bash
# Edit PVC to increase size
kubectl patch pvc <pvc-name> -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'

# Check expansion status
kubectl describe pvc <pvc-name> | grep -A 5 Conditions

# Some expansions require pod restart
kubectl delete pod <pod-name>  # Let Deployment recreate it
```

## PVC Best Practices

### 1. Size Storage Appropriately
```yaml
resources:
  requests:
    storage: 50Gi    # Based on actual needs + growth
# Don't request 1TB if you need 10GB
# Do plan for reasonable growth
```

### 2. Choose Correct Access Mode
```yaml
# Database: ReadWriteOnce
accessModes: [ReadWriteOnce]

# Shared config: ReadOnlyMany
accessModes: [ReadOnlyMany]

# Shared uploads: ReadWriteMany (needs special storage)
accessModes: [ReadWriteMany]
```

### 3. Use Descriptive Names
```yaml
metadata:
  name: postgres-data-pvc          # Clear purpose
  labels:
    app: postgres
    component: database
    environment: production
```

### 4. Specify Storage Classes
```yaml
# Don't rely on defaults
storageClassName: ssd-storage      # Explicit choice

# Unless you want default
storageClassName: ""               # Use cluster default
```

## PVC in Different Workload Types

### StatefulSets (Automatic PVC Creation)
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 3
  template:
    # Pod template
  volumeClaimTemplates:              # Automatic PVC creation
  - metadata:
      name: postgres-storage
    spec:
      accessModes: [ReadWriteOnce]
      resources:
        requests:
          storage: 50Gi
      storageClassName: fast-ssd

# Creates: postgres-storage-postgres-0, postgres-storage-postgres-1, etc.
```

### Deployments (Manual PVC Creation)
```yaml
# Create PVC first
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: webapp-storage-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi

---
# Reference in Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  template:
    spec:
      containers:
      - name: app
        volumeMounts:
        - name: storage
          mountPath: /app/data
      volumes:
      - name: storage
        persistentVolumeClaim:
          claimName: webapp-storage-pvc  # Must exist
```

## When to Use PVCs

### ✅ Use PVCs When:
- **Applications need persistent data** (databases, file uploads)
- **Data must survive pod restarts** (user data, configurations)
- **Multiple pods need shared storage** (content management systems)
- **You want storage abstraction** (don't care about storage details)
- **Using dynamic provisioning** (cloud environments)

### ❌ Don't Use PVCs When:
- **Temporary data only** (use emptyDir volumes)
- **Configuration files** (use ConfigMaps/Secrets)
- **Read-only data from images** (use image layers)
- **High-performance temporary storage** (use emptyDir with memory)

## Key Insights

**PVCs are storage requests** - they specify what you need, not how to provide it

**PVCs are namespaced** - each namespace has its own PVCs

**Binding is automatic** - Kubernetes matches PVCs to suitable PVs

**Dynamic provisioning is modern** - StorageClasses create PVs automatically

**Access modes matter** - choose based on how many pods need access

**Expansion is possible** - but requires compatible storage and StorageClass

**StatefulSets automate PVCs** - each replica gets its own storage automatically

The goal is **simple storage requests** that abstract away infrastructure complexity while providing persistent, reliable data storage for applications.