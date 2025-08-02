# Storage: Enterprise Data Persistence & Disaster Recovery

## WHY Storage Is Critical for Business Continuity

**Problem**: Containers are ephemeral - data disappears when pods restart, causing catastrophic data loss  
**Solution**: Persistent storage with enterprise backup, disaster recovery, and high availability

## **Production Data Loss Incident: The Million Dollar Mistake**

**What Happened**: Startup's primary database pod crashed during deployment, no persistent storage configured  
**Business Impact**: Complete customer data loss, company closure within 6 months  
**Root Cause**: Using local container storage for production database  
**Prevention**: Proper persistent volumes with backup strategies

### **Storage Evolution: From Pets to Cattle**
- **Physical Era**: RAID arrays, shared NAS, manual backup tapes
- **VM Era**: VMDK files, SAN storage, snapshot-based backups  
- **Container Era**: Persistent Volumes, CSI drivers, cloud-native storage
- **Modern Era**: Software-defined storage, automated DR, cross-region replication

## The Critical Questions

**Data Protection**: "How do I save data when my pods restart?"  
**Disaster Recovery**: "What happens when an entire data center fails?"  
**Performance**: "How do I handle 100K IOPS requirements?"  
**Compliance**: "How do I prove data retention for audit?"  
**Cost Optimization**: "Why is my storage bill $50K/month?"

## **Production Storage Scenarios**

### **Scenario 1: Financial Trading Platform**
**Business Context**: Microsecond latency requirements, zero data loss tolerance  
**Compliance**: Financial regulations, audit trails, 7-year retention  
**Solution**: NVMe local storage + real-time replication + automated failover

### **Scenario 2: Healthcare Records System**  
**Business Context**: PHI data, 99.99% uptime requirement  
**Compliance**: HIPAA, encrypted at rest, secure deletion  
**Solution**: Encrypted persistent volumes + cross-region backup + audit logging

### **Scenario 3: Media Streaming Service**
**Business Context**: Petabytes of video content, global distribution  
**Compliance**: GDPR right to be forgotten, content licensing  
**Solution**: Object storage + CDN + tiered storage lifecycle

## Storage Hierarchy in Kubernetes

Understanding storage requires grasping three interconnected concepts:

### StorageClass - The Blueprint
- **What**: Defines types of storage available (SSD, HDD, local, cloud)
- **Role**: Storage administrator's configuration
- **Analogy**: "Menu of storage options"

### PersistentVolume (PV) - The Actual Storage
- **What**: Real storage resource (disk, NFS share, cloud volume)
- **Role**: Cluster-level storage inventory
- **Analogy**: "Actual storage device"

### PersistentVolumeClaim (PVC) - The Request
- **What**: Request for storage by applications
- **Role**: Pod's storage requirements
- **Analogy**: "Storage order from the menu"

## The Storage Workflow

```
1. Admin creates StorageClasses (storage types available)
2. Admin creates PVs OR enables dynamic provisioning
3. Developer creates PVC (requests storage)
4. Kubernetes binds PVC to suitable PV
5. Pod mounts PVC as volume
6. Application reads/writes persistent data
```

## Directory Structure

```
storage/
├── README.md                    # This overview file
├── SIMPLE-STORAGE.yaml         # Quick start with all concepts
├── pv/                          # Persistent Volumes
│   ├── README.md               # Complete PV guide
│   ├── 01-local-pv.yaml
│   ├── 02-nfs-pv.yaml
│   ├── 03-cloud-pv.yaml
│   └── SIMPLE-PV.yaml
├── pvc/                         # Persistent Volume Claims
│   ├── README.md               # Complete PVC guide
│   ├── 01-basic-pvc.yaml
│   ├── 02-database-pvc.yaml
│   ├── 03-shared-pvc.yaml
│   └── SIMPLE-PVC.yaml
└── storageclass/                # Storage Classes
    ├── README.md               # Complete StorageClass guide
    ├── 01-local-storageclass.yaml
    ├── 02-ssd-storageclass.yaml
    ├── 03-cloud-storageclass.yaml
    └── SIMPLE-STORAGECLASS.yaml
```

## Storage Patterns by Use Case

### Pattern 1: Database Storage (Most Common)
```yaml
# What you need: Fast, persistent storage for single pod
# Use: StorageClass → PVC → StatefulSet
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
spec:
  accessModes: [ReadWriteOnce]     # Single pod access
  storageClassName: fast-ssd       # High performance
  resources:
    requests:
      storage: 10Gi
```

### Pattern 2: Shared Files
```yaml
# What you need: Multiple pods sharing same files
# Use: ReadWriteMany PVC with NFS or similar
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-files-pvc  
spec:
  accessModes: [ReadWriteMany]     # Multiple pod access
  storageClassName: nfs-storage    # Shared filesystem
  resources:
    requests:
      storage: 50Gi
```

### Pattern 3: Temporary Fast Storage
```yaml
# What you need: Fast temporary storage for processing
# Use: Local SSD storage class
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: processing-pvc
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: local-nvme     # Fastest possible
  resources:
    requests:
      storage: 100Gi
```

## Storage Access Modes

Understanding access modes is crucial for choosing the right storage:

### ReadWriteOnce (RWO) - Single Pod
- **Use Case**: Databases, single-instance applications
- **Limitation**: Only one pod can mount at a time
- **Storage Types**: Most cloud disks, local storage
- **Example**: PostgreSQL data directory

### ReadOnlyMany (ROX) - Multiple Readers
- **Use Case**: Configuration files, static content
- **Limitation**: Read-only access
- **Storage Types**: Most storage types support this
- **Example**: Shared configuration files

### ReadWriteMany (RWX) - Multiple Writers
- **Use Case**: Shared application data, content management
- **Limitation**: Requires shared filesystem (NFS, Ceph, etc.)
- **Storage Types**: NFS, cloud file systems, distributed storage
- **Example**: Shared uploads directory

## Storage Performance Characteristics

### Local Storage
- **Performance**: Fastest (direct attached)
- **Durability**: Lost if node fails
- **Use Case**: High-performance temporary storage, caches
- **Cost**: Included with node

### Network Storage (SAN/NFS)
- **Performance**: Good (network dependent)
- **Durability**: High (survives node failures)
- **Use Case**: Shared storage, databases
- **Cost**: Separate from compute

### Cloud Storage
- **Performance**: Variable (depends on type)
- **Durability**: Very high (multiple replicas)
- **Use Case**: Production databases, long-term storage
- **Cost**: Pay per GB and IOPS

## Dynamic vs Static Provisioning

### Static Provisioning (Manual)
```yaml
# Admin pre-creates PVs
apiVersion: v1
kind: PersistentVolume
metadata:
  name: manual-pv
spec:
  capacity:
    storage: 10Gi
  accessModes: [ReadWriteOnce]
  hostPath:
    path: /data/manual-pv
```

### Dynamic Provisioning (Automatic)
```yaml
# StorageClass automatically creates PVs
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: auto-storage
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  fsType: ext4
```

**Modern Best Practice**: Use dynamic provisioning with StorageClasses

## Quick Start: Common Scenarios

### Scenario 1: Database Needs Storage
```bash
# Create StorageClass for databases
kubectl apply -f storageclass/01-local-storageclass.yaml

# Create PVC for database
kubectl apply -f pvc/02-database-pvc.yaml

# Check binding
kubectl get pvc database-pvc
```

### Scenario 2: Share Files Between Pods
```bash  
# Create shared storage class
kubectl apply -f storageclass/02-ssd-storageclass.yaml

# Create shared PVC
kubectl apply -f pvc/03-shared-pvc.yaml

# Multiple pods can use the same PVC
```

### Scenario 3: High Performance Application
```bash
# Create fast local storage
kubectl apply -f storageclass/03-cloud-storageclass.yaml

# Request high-performance storage
kubectl apply -f pvc/01-basic-pvc.yaml
```

## Storage Troubleshooting Commands

### Check Storage Resources
```bash
# List all storage classes
kubectl get storageclass

# List persistent volumes
kubectl get pv

# List persistent volume claims
kubectl get pvc -A

# Check storage class details
kubectl describe storageclass <storage-class-name>
```

### Debug PVC Issues
```bash
# Check PVC status and events
kubectl describe pvc <pvc-name>

# Check if PVC is bound
kubectl get pvc <pvc-name> -o wide

# Check pod using PVC
kubectl describe pod <pod-name>
```

### Monitor Storage Usage
```bash
# Check PV usage (if metrics available)
kubectl top pv

# Check which pods are using storage
kubectl get pods -o custom-columns=NAME:.metadata.name,VOLUMES:.spec.volumes[*].persistentVolumeClaim.claimName
```

## Storage Best Practices

### 1. Choose Right Access Mode
```yaml
# Database: ReadWriteOnce (RWO)
accessModes: [ReadWriteOnce]

# Shared config: ReadOnlyMany (ROX)  
accessModes: [ReadOnlyMany]

# Shared data: ReadWriteMany (RWX) - needs special storage
accessModes: [ReadWriteMany]
```

### 2. Size Storage Appropriately
```yaml
# Start reasonable, can usually expand later
resources:
  requests:
    storage: 20Gi    # Based on actual needs, not just "big number"
```

### 3. Use StorageClasses
```yaml
# Don't hardcode storage types
storageClassName: fast-ssd    # Use descriptive names
# storageClassName: ""        # Only for static PVs
```

### 4. Plan for Growth
```yaml
# Enable volume expansion if supported
allowVolumeExpansion: true
```

## Common Storage Issues

### Issue: PVC Stuck in Pending
```bash
# Check events
kubectl describe pvc <pvc-name>

# Common causes:
# - No matching PV available
# - StorageClass doesn't exist
# - Insufficient resources
# - Access mode not supported
```

### Issue: Pod Can't Mount Volume
```bash
# Check pod events
kubectl describe pod <pod-name>

# Common causes:
# - PVC not bound
# - Node lacks required storage driver
# - Access mode conflicts
# - Storage system unreachable
```

### Issue: Data Loss
```bash
# Check PV reclaim policy
kubectl get pv <pv-name> -o yaml | grep reclaimPolicy

# Policies:
# - Retain: PV kept after PVC deletion (safe)
# - Delete: PV deleted with PVC (dangerous)
# - Recycle: PV wiped and reused (deprecated)
```

## Production Considerations

### Data Backup
```yaml
# Implement backup strategy
# - Database dumps
# - Volume snapshots  
# - Cross-region replication
# - Regular restore testing
```

### Security
```yaml
# Consider encryption
# - At rest: encrypted storage class
# - In transit: secure protocols
# - Access: RBAC for storage resources
```

### Monitoring
```yaml
# Track storage metrics
# - Disk usage
# - IOPS utilization
# - Storage costs
# - Performance trends
```

## When to Use Each Storage Type

### Use PV Directly When:
✅ **Static storage** already exists (NFS shares, SAN volumes)  
✅ **Special configuration** not supported by StorageClass  
✅ **Testing** storage setups  
✅ **Legacy environments** without dynamic provisioning

### Use PVC with StorageClass When:
✅ **Production applications** (most common)  
✅ **Dynamic scaling** requirements  
✅ **Cloud environments** with dynamic provisioning  
✅ **Developer self-service** scenarios  
✅ **Automated deployments**

### Use StorageClass When:
✅ **Standardizing storage** across teams  
✅ **Enabling self-service** for developers  
✅ **Managing costs** with different storage tiers  
✅ **Simplifying operations** with automation

## Key Insights

**Storage is about persistence AND performance** - different workloads need different storage characteristics

**StorageClasses enable self-service** - developers request storage without knowing infrastructure details

**PVCs are like resource requests** - they specify what you need, not how to provide it

**Access modes determine sharing** - choose based on how many pods need access

**Dynamic provisioning is the modern way** - avoid static PVs unless necessary

**Plan for data lifecycle** - backup, growth, migration, and eventual cleanup

**Test storage failures** - verify your applications handle storage issues gracefully

The goal is **reliable, performant data persistence** that survives pod restarts, node failures, and supports your application's sharing and performance requirements.