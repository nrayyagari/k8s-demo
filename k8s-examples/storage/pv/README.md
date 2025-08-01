# Persistent Volumes (PV): The Actual Storage

## WHY Do Persistent Volumes Exist?

**Problem**: Applications need real storage devices, but pods shouldn't care about storage infrastructure  
**Solution**: PVs represent actual storage resources (disk, NFS, cloud volume) that pods can use

## The Core Question

**"Where is the actual storage that my application will use?"**

PV is the **actual storage device** - the real disk, NFS share, or cloud volume that holds your data.

## PV Fundamentals

### What is a Persistent Volume?
- **Cluster Resource**: Available to any namespace (not namespace-scoped)
- **Storage Abstraction**: Represents real storage (local disk, NFS, cloud volume)
- **Lifecycle Independent**: Exists beyond pod lifecycles
- **Admin Managed**: Usually created by cluster administrators

### PV vs Pod Storage
```
Pod Volume (temporary):
├── EmptyDir → Lost when pod dies
├── HostPath → Tied to specific node
└── ConfigMap → Configuration only

Persistent Volume (permanent):
├── Survives pod restarts
├── Survives pod rescheduling  
├── Survives node failures (if networked)
└── Managed independently of pods
```

## Simple PV Pattern

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-pv
spec:
  capacity:
    storage: 10Gi                    # Size of storage
  accessModes:
  - ReadWriteOnce                    # How it can be accessed
  persistentVolumeReclaimPolicy: Retain  # What happens when released
  hostPath:                          # Type of storage (local disk)
    path: /data/my-pv
```

## PV Access Modes

### ReadWriteOnce (RWO) - Single Pod Access
```yaml
accessModes:
- ReadWriteOnce
# Use case: Database storage, single-instance applications
# Supported by: Most storage types (local, cloud disks)
```

### ReadOnlyMany (ROX) - Multiple Read-Only
```yaml
accessModes:  
- ReadOnlyMany
# Use case: Static content, shared configuration
# Supported by: Most storage types
```

### ReadWriteMany (RWX) - Multiple Read-Write
```yaml
accessModes:
- ReadWriteMany  
# Use case: Shared application data, content management
# Supported by: NFS, distributed file systems (limited support)
```

## PV Reclaim Policies

### Retain (Safest)
```yaml
persistentVolumeReclaimPolicy: Retain
# What happens: PV kept when PVC deleted
# Data: Preserved (manual cleanup needed)
# Use case: Production data that must not be lost
```

### Delete (Dangerous)
```yaml
persistentVolumeReclaimPolicy: Delete
# What happens: PV deleted when PVC deleted
# Data: Lost forever
# Use case: Temporary data, development environments
```

### Recycle (Deprecated)
```yaml
persistentVolumeReclaimPolicy: Recycle
# What happens: PV wiped and made available again
# Status: Deprecated, don't use
```

## PV Types and Examples

### 1. Local Storage (HostPath)
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv
spec:
  capacity:
    storage: 20Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /mnt/data/local-pv

# Pros: Fast (direct attached)
# Cons: Tied to specific node, lost if node fails
# Use case: High-performance temporary storage
```

### 2. NFS Storage
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv
spec:
  capacity:
    storage: 100Gi
  accessModes:
  - ReadWriteMany                    # Multiple pods can share
  persistentVolumeReclaimPolicy: Retain
  nfs:
    server: 192.168.1.100           # NFS server IP
    path: /shared/data              # Path on NFS server

# Pros: Survives node failures, shareable
# Cons: Network dependent, slower than local
# Use case: Shared storage, content management
```

### 3. Cloud Storage (AWS EBS)
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: aws-ebs-pv
spec:
  capacity:
    storage: 50Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  awsElasticBlockStore:
    volumeID: vol-0123456789abcdef0   # AWS EBS volume ID
    fsType: ext4

# Pros: Highly durable, managed by cloud provider
# Cons: Cloud-specific, costs money
# Use case: Production databases, critical data
```

## Files in This Directory

1. **01-local-pv.yaml** - Local storage PV examples
2. **02-nfs-pv.yaml** - Network storage PV examples  
3. **03-cloud-pv.yaml** - Cloud storage PV examples
4. **SIMPLE-PV.yaml** - Quick start example

## Quick Start

```bash
# Create a local PV
kubectl apply -f 01-local-pv.yaml

# Check PV status
kubectl get pv
kubectl describe pv local-storage-pv

# Check available storage
kubectl get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,STATUS:.status.phase
```

## PV Lifecycle States

### Available
```bash
# PV exists but not bound to any PVC
STATUS: Available
# Ready to be claimed by a PVC
```

### Bound  
```bash
# PV is bound to a PVC
STATUS: Bound
# In use by a pod through PVC
```

### Released
```bash
# PVC was deleted, but PV not yet reclaimed
STATUS: Released
# Data might still exist, needs admin action
```

### Failed
```bash
# Automatic reclaim failed
STATUS: Failed
# Requires manual intervention
```

## Static vs Dynamic PV Creation

### Static Provisioning (Manual)
```yaml
# Admin pre-creates PVs
apiVersion: v1
kind: PersistentVolume
metadata:
  name: static-pv
spec:
  capacity:
    storage: 10Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /data/static

# Process:
# 1. Admin creates PV
# 2. Developer creates PVC
# 3. Kubernetes binds PVC to PV
```

### Dynamic Provisioning (Automatic)
```yaml
# StorageClass automatically creates PVs
# No manual PV creation needed
# PV created when PVC is created

# Process:
# 1. Admin creates StorageClass
# 2. Developer creates PVC with storageClassName
# 3. StorageClass provisioner creates PV automatically
# 4. Kubernetes binds PVC to new PV
```

**Modern Best Practice**: Use dynamic provisioning with StorageClasses

## PV Selection and Binding

### How Kubernetes Matches PVC to PV
```
1. Access Mode: PV must support PVC's access mode
2. Storage Size: PV must be >= PVC requested size  
3. Storage Class: Must match (or both empty)
4. Selector: PVC can specify label selectors
5. Volume Mode: Filesystem vs Block (advanced)
```

### PV Selection Example
```yaml
# PVC requests
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 8Gi
  storageClassName: fast-ssd

# This PV would match:
spec:
  capacity:
    storage: 10Gi               # >= 8Gi ✓
  accessModes: [ReadWriteOnce]  # Matches ✓
  storageClassName: fast-ssd    # Matches ✓
```

## PV with Node Affinity

### Local Storage with Node Constraints
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-node-specific
spec:
  capacity:
    storage: 100Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  local:
    path: /mnt/fast-ssd
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - worker-node-1             # Only available on this node
```

## Monitoring and Troubleshooting

### Check PV Status
```bash
# List all PVs
kubectl get pv

# Detailed PV information
kubectl describe pv <pv-name>

# Check PV capacity and usage
kubectl get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,STATUS:.status.phase,CLAIM:.spec.claimRef.name
```

### Common PV Issues

#### Issue: PV Shows as Available but PVC Pending
```bash
# Check access modes compatibility
kubectl describe pv <pv-name> | grep "Access Modes"
kubectl describe pvc <pvc-name> | grep "Access Modes"

# Check storage size requirements
kubectl describe pvc <pvc-name> | grep "Requested"
kubectl describe pv <pv-name> | grep "Capacity"
```

#### Issue: PV Stuck in Released State
```bash
# Check reclaim policy
kubectl get pv <pv-name> -o yaml | grep reclaimPolicy

# Manual cleanup for Retain policy:
# 1. Delete the PV
# 2. Clean up the underlying storage
# 3. Recreate PV if needed
```

#### Issue: PV Access Denied
```bash
# Check node permissions
kubectl describe pod <pod-name>
# Look for mount errors in events

# Common fixes:
# - Check directory permissions on host
# - Verify storage system is accessible
# - Check security contexts
```

## PV Best Practices

### 1. Use Descriptive Names
```yaml
metadata:
  name: postgres-prod-pv-001      # Clear purpose and environment
  labels:
    app: postgres
    environment: production
    tier: database
```

### 2. Set Appropriate Reclaim Policies
```yaml
# Production data
persistentVolumeReclaimPolicy: Retain

# Development/testing
persistentVolumeReclaimPolicy: Delete
```

### 3. Include Monitoring Labels
```yaml
metadata:
  labels:
    storage-type: ssd
    performance-tier: high
    backup-required: "true"
    cost-center: engineering
```

### 4. Plan for Growth
```yaml
# Create PVs larger than immediate needs
capacity:
  storage: 50Gi    # App needs 20Gi, plan for growth
```

## When to Create PVs Manually

### ✅ Use Manual PV Creation When:
- **Existing storage** needs to be integrated (legacy NFS shares)
- **Special storage** not supported by StorageClass
- **Testing** storage configurations
- **Static environments** where storage is pre-allocated
- **Compliance** requires specific storage configurations

### ❌ Avoid Manual PV Creation When:
- **Dynamic provisioning** is available and suitable
- **Development** environments need quick storage
- **Cloud environments** with good StorageClass support
- **Multi-tenant** environments where developers need self-service

## Real-World PV Scenarios

### Scenario 1: Database Migration
```yaml
# Existing database on NFS needs to move to Kubernetes
apiVersion: v1
kind: PersistentVolume
metadata:
  name: legacy-db-pv
spec:
  capacity:
    storage: 200Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  nfs:
    server: legacy-storage.company.com
    path: /databases/production/postgres
```

### Scenario 2: High-Performance Computing
```yaml
# Application needs local NVMe storage
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hpc-scratch-pv
spec:
  capacity:
    storage: 1Ti
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Delete  # Temporary data
  local:
    path: /mnt/nvme-scratch
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-type
          operator: In
          values: [compute-intensive]
```

## Key Insights

**PVs represent actual storage** - they are the real disks, shares, or volumes your data lives on

**PVs are cluster-wide resources** - available to any namespace, managed by admins

**Reclaim policies matter** - choose Retain for production, Delete only for temporary data

**Access modes determine sharing** - most storage is ReadWriteOnce, ReadWriteMany needs special storage

**Static PVs are for special cases** - modern deployments use dynamic provisioning via StorageClasses

**Node affinity matters for local storage** - local PVs are tied to specific nodes

**Plan for lifecycle management** - PVs can outlive the applications that use them

The goal is **reliable storage abstraction** that provides actual storage resources while hiding infrastructure complexity from applications.