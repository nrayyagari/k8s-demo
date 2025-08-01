# Storage Classes: Dynamic Storage Provisioning

## WHY Do Storage Classes Exist?

**Problem**: Manual PV creation is slow, error-prone, and doesn't scale for developer self-service  
**Solution**: StorageClasses automatically create PVs when PVCs are requested

## The Core Question

**"How do I let developers request storage without manual PV creation?"**

StorageClass is the **storage menu** - it defines what types of storage are available and how to create them automatically.

## StorageClass Fundamentals

### What is a StorageClass?
- **Cluster Resource**: Available to all namespaces
- **Storage Template**: Defines how to create PVs automatically
- **Admin Managed**: Created by cluster administrators
- **Provisioner Driven**: Uses plugins to create actual storage

### The Dynamic Provisioning Workflow
```
1. Admin creates StorageClass (defines storage types)
2. Developer creates PVC with storageClassName
3. StorageClass provisioner creates actual storage (EBS volume, etc.)
4. Kubernetes creates PV representing the storage
5. PVC automatically binds to new PV
6. Pod uses PVC normally
```

## Simple StorageClass Pattern

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs    # Who creates the storage
parameters:
  type: gp3                          # Storage-specific configuration
  fsType: ext4
  encrypted: "true"
allowVolumeExpansion: true           # Can grow storage later
reclaimPolicy: Delete                # What happens when PVC deleted
```

## StorageClass Components

### Provisioner
```yaml
# Different provisioners for different storage types
provisioner: kubernetes.io/aws-ebs          # AWS EBS volumes
provisioner: kubernetes.io/gce-pd           # Google Cloud disks  
provisioner: kubernetes.io/azure-disk       # Azure disks
provisioner: k8s.io/minikube-hostpath       # Local testing
provisioner: nfs.csi.k8s.io                 # NFS storage
```

### Parameters (Storage-Specific)
```yaml
# AWS EBS parameters
parameters:
  type: gp3                    # Volume type (gp3, io1, st1, sc1)
  fsType: ext4                 # File system type
  encrypted: "true"            # Enable encryption
  iops: "3000"                 # Provisioned IOPS (for io1/gp3)

# Azure Disk parameters
parameters:
  storageaccounttype: Premium_LRS
  kind: Managed
  
# GCE Persistent Disk parameters
parameters:
  type: pd-ssd                 # pd-standard or pd-ssd
  zone: us-central1-a
```

### Volume Expansion
```yaml
allowVolumeExpansion: true     # PVCs can be resized after creation
# Requires: Storage system supports expansion
# Note: Usually requires pod restart to see new size
```

### Reclaim Policy
```yaml
reclaimPolicy: Delete          # Delete PV when PVC deleted
reclaimPolicy: Retain          # Keep PV when PVC deleted
# Default: Delete (for dynamic PVs)
```

## Common StorageClass Examples

### AWS EBS Fast Storage
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: aws-gp3-fast
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
  encrypted: "true"
  iops: "3000"
  throughput: "125"
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

### Local NVMe Storage
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-nvme
provisioner: kubernetes.io/no-provisioner    # Manual provisioning
parameters:
  fsType: xfs
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowedTopologies:
- matchLabelExpressions:
  - key: kubernetes.io/hostname
    values: [worker-node-1, worker-node-2]
```

### NFS Shared Storage
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-shared
provisioner: nfs.csi.k8s.io
parameters:
  server: nfs-server.example.com
  share: /shared/kubernetes
  fsType: nfs
reclaimPolicy: Retain
allowVolumeExpansion: true
```

## Volume Binding Modes

### Immediate (Default)
```yaml
volumeBindingMode: Immediate
# Behavior: PV created immediately when PVC created
# Use case: Storage not tied to specific nodes (cloud volumes)
```

### WaitForFirstConsumer
```yaml
volumeBindingMode: WaitForFirstConsumer  
# Behavior: PV created when first pod using PVC is scheduled
# Use case: Local storage, topology-aware storage
```

## Default StorageClass

### Setting Default
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard-ssd
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"  # Default
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  fsType: ext4
```

### Using Default
```yaml
# PVC without storageClassName uses default
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: default-storage-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
  # storageClassName not specified = uses default
```

## Files in This Directory

1. **01-local-storageclass.yaml** - Local storage examples
2. **02-ssd-storageclass.yaml** - SSD storage configurations
3. **03-cloud-storageclass.yaml** - Cloud provider examples
4. **SIMPLE-STORAGECLASS.yaml** - Quick start example

## Quick Start

```bash
# Create a StorageClass
kubectl apply -f 01-local-storageclass.yaml

# Check StorageClass
kubectl get storageclass
kubectl describe storageclass local-storage

# Create PVC using StorageClass
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 5Gi
  storageClassName: local-storage
EOF

# Watch dynamic provisioning
kubectl get pvc test-pvc -w
```

## StorageClass Management

### Check Available StorageClasses
```bash
# List all StorageClasses
kubectl get storageclass

# Show detailed information
kubectl describe storageclass <storage-class-name>

# Check which is default
kubectl get storageclass -o yaml | grep is-default-class
```

### Test StorageClass
```bash
# Create test PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: storageclass-test
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  storageClassName: <storage-class-name>
EOF

# Check if PV was created automatically
kubectl get pv
kubectl get pvc storageclass-test
```

## StorageClass Best Practices

### 1. Descriptive Names
```yaml
metadata:
  name: aws-gp3-encrypted      # Clear what it provides
  # not: storage-class-1       # Unclear purpose
```

### 2. Include Performance Characteristics
```yaml
metadata:
  name: high-iops-ssd
  labels:
    performance: high
    storage-type: ssd
    cost-tier: premium
```

### 3. Set Appropriate Defaults
```yaml
parameters:
  type: gp3                    # Good price/performance balance
  encrypted: "true"            # Security by default
  fsType: ext4                 # Widely supported
```

### 4. Document Usage
```yaml
metadata:
  name: database-storage
  annotations:
    description: "High-performance SSD for databases"
    use-case: "Production databases requiring low latency"
    cost-impact: "Premium pricing"
```

## Common StorageClass Patterns

### Multi-Tier Storage Strategy
```yaml
# Tier 1: High-performance (expensive)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: premium-ssd
parameters:
  type: io1
  iops: "10000"
  
---
# Tier 2: Balanced (default)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard-ssd
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
parameters:
  type: gp3
  
---
# Tier 3: Archive (cheap)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: archive-storage
parameters:
  type: sc1                    # Throughput optimized HDD
```

### Environment-Based Classes
```yaml
# Production: Encrypted, high-performance
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: production-storage
parameters:
  type: gp3
  encrypted: "true"
  iops: "3000"
reclaimPolicy: Retain          # Keep data safe

---
# Development: Unencrypted, basic
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: development-storage
parameters:
  type: gp2
  encrypted: "false"
reclaimPolicy: Delete          # Clean up automatically
```

## Troubleshooting StorageClasses

### Issue: PVC Stuck in Pending with StorageClass
```bash
# Check StorageClass exists
kubectl get storageclass <storage-class-name>

# Check provisioner is running
kubectl get pods -n kube-system | grep <provisioner-name>

# Check events for provisioning errors
kubectl describe pvc <pvc-name>
kubectl get events --sort-by='.lastTimestamp'
```

### Issue: Dynamic Provisioning Failed
```bash
# Check provisioner logs
kubectl logs -n kube-system <provisioner-pod>

# Common issues:
# 1. Cloud credentials missing/invalid
# 2. Insufficient permissions (IAM roles)
# 3. Storage quota exceeded
# 4. Invalid parameters in StorageClass
```

### Issue: StorageClass Parameters Invalid
```bash
# Validate parameters against provisioner documentation
kubectl describe storageclass <storage-class-name>

# Test with minimal parameters first
# Add complexity gradually
```

## Cloud Provider Examples

### AWS EKS
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: aws-ebs-gp3
provisioner: ebs.csi.aws.com         # AWS EBS CSI driver
parameters:
  type: gp3
  fsType: ext4
  encrypted: "true"
allowVolumeExpansion: true
reclaimPolicy: Delete
```

### Google GKE
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gce-ssd
provisioner: pd.csi.storage.gke.io   # GCE Persistent Disk CSI driver
parameters:
  type: pd-ssd
  replication-type: regional-pd
allowVolumeExpansion: true
```

### Azure AKS
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-premium
provisioner: disk.csi.azure.com      # Azure Disk CSI driver
parameters:
  storageaccounttype: Premium_LRS
  kind: Managed
allowVolumeExpansion: true
```

## When to Create StorageClasses

### ✅ Create StorageClasses When:
- **Different performance tiers** needed (fast SSD, slow HDD)
- **Different environments** need different storage (prod vs dev)
- **Cost optimization** requires multiple storage options
- **Compliance** requires specific configurations (encryption, location)
- **Developer self-service** is desired

### ❌ Don't Create StorageClasses When:
- **Single storage type** meets all needs
- **Static provisioning** is preferred
- **No dynamic provisioning** support available
- **Existing PVs** cover all requirements

## Key Insights

**StorageClasses enable self-service storage** - developers can request storage without admin intervention

**Parameters are provisioner-specific** - each storage system has different configuration options

**Default StorageClass simplifies PVCs** - developers don't need to specify storageClassName

**Volume binding modes affect scheduling** - WaitForFirstConsumer ensures storage is created where needed

**Reclaim policies determine data lifecycle** - choose Retain for important data, Delete for temporary

**Testing is essential** - always validate StorageClass works before production use

**Monitor costs** - dynamic provisioning can create expensive storage automatically

The goal is **automated, self-service storage provisioning** that gives developers the right storage for their applications while maintaining administrative control over policies and costs.