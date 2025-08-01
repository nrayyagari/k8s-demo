# Node Affinity: Control Pod Placement

## WHY Does Node Affinity Exist?

**Problem**: Default scheduler doesn't understand business requirements for pod placement  
**Solution**: Node affinity allows precise control over which nodes pods can be scheduled on

## The Core Question

**"Where should my pods run to meet business, performance, or compliance requirements?"**

Default scheduling: Kubernetes picks any available node  
Node affinity: Pods run only on nodes that meet your specific criteria

## What Node Affinity Provides

### Hardware-Specific Placement
- GPU workloads on GPU-enabled nodes
- High-memory applications on large-memory nodes
- SSD storage for performance-critical applications
- CPU-intensive tasks on high-performance nodes

### Compliance and Security
- Sensitive workloads on dedicated, compliant nodes
- Geographic data placement requirements
- Isolated environments for different tenants
- Regulatory compliance (PCI, HIPAA, SOC2)

### Cost Optimization
- Batch jobs on spot/preemptible instances
- Production workloads on reserved instances
- Development workloads on smaller, cheaper nodes
- Multi-zone distribution for availability

## Required vs Preferred Affinity

### Required Affinity (Hard Constraint)
```yaml
requiredDuringSchedulingIgnoredDuringExecution:
  nodeSelectorTerms:
  - matchExpressions:
    - key: accelerator
      operator: In
      values: ["nvidia-tesla-p100"]
```
- **Behavior**: Pod WILL NOT be scheduled if no matching node exists
- **Use when**: Compliance requirements, hardware dependencies are mandatory

### Preferred Affinity (Soft Constraint)
```yaml
preferredDuringSchedulingIgnoredDuringExecution:
- weight: 100
  preference:
    matchExpressions:
    - key: topology.kubernetes.io/zone
      operator: In
      values: ["us-west-2a"]
```
- **Behavior**: Scheduler tries to match but will schedule elsewhere if needed
- **Weight**: 1-100, higher numbers = stronger preference
- **Use when**: Performance optimizations, cost preferences

## Node Selector Operators

### String Operators
```yaml
# In: Label value in specified list
- key: node.kubernetes.io/instance-type
  operator: In
  values: ["m5.large", "m5.xlarge"]

# NotIn: Label value not in list
- key: node.kubernetes.io/lifecycle
  operator: NotIn
  values: ["spot"]

# Exists: Label key exists (value ignored)  
- key: ssd-storage
  operator: Exists

# DoesNotExist: Label key doesn't exist
- key: gpu
  operator: DoesNotExist
```

### Numeric Operators
```yaml
# Gt: Numeric greater than
- key: node.company.com/memory-gb
  operator: Gt
  values: ["32"]

# Lt: Numeric less than
- key: node.company.com/cpu-cores
  operator: Lt
  values: ["16"]
```

## Files in This Directory

1. **SIMPLE-NODE-AFFINITY.yaml** - Basic node affinity examples with explanations
2. **01-gpu-workload.yaml** - GPU-specific node placement
3. **02-multi-zone-deployment.yaml** - Zone distribution with preferences
4. **03-compliance-workload.yaml** - Compliance and security requirements
5. **04-cost-optimization.yaml** - Cost-aware scheduling patterns

## Quick Start

```bash
# Label nodes for testing
kubectl label node <node-name> accelerator=nvidia-tesla-p100
kubectl label node <node-name> node.company.com/environment=production

# Deploy node affinity examples
kubectl apply -f SIMPLE-NODE-AFFINITY.yaml

# Check pod placement
kubectl get pods -o wide
kubectl describe pod <pod-name> | grep -A 10 "Node-Selectors"

# View node labels
kubectl get nodes --show-labels
kubectl describe node <node-name>
```

## Basic Patterns

### Hardware-Specific Placement
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gpu-training
spec:
  replicas: 2
  selector:
    matchLabels:
      app: gpu-training
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: accelerator
                operator: In
                values:
                - nvidia-tesla-p100
                - nvidia-tesla-v100
              - key: node.kubernetes.io/instance-type
                operator: In
                values:
                - p3.2xlarge
                - p3.8xlarge
      containers:
      - name: training
        image: tensorflow/tensorflow:latest-gpu
        resources:
          limits:
            nvidia.com/gpu: 1
```

### Zone Distribution with Preferences
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 6
  template:
    spec:
      affinity:
        nodeAffinity:
          # Prefer specific zones but allow others
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values: ["us-west-2a"]
          - weight: 80
            preference:
              matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values: ["us-west-2b"]
          - weight: 60
            preference:
              matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values: ["us-west-2c"]
```

## Production Examples

### Database with High-Performance Requirements
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-primary
  annotations:
    team.company.com/owner: "database-team"
    database.company.com/role: "primary"
spec:
  serviceName: postgres-primary
  replicas: 1
  template:
    metadata:
      annotations:
        cluster-autoscaler.kubernetes.io/safe-to-evict: "false"
    spec:
      affinity:
        nodeAffinity:
          # REQUIRED: Must run on dedicated database nodes
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              # High-memory nodes for database workloads
              - key: node.company.com/memory-gb
                operator: Gt
                values: ["64"]
              # SSD storage for performance
              - key: node.company.com/storage-type
                operator: In
                values: ["ssd", "nvme"]
              # No spot instances for databases
              - key: node.kubernetes.io/lifecycle
                operator: NotIn
                values: ["spot"]
              # Dedicated nodes for isolation
              - key: node.company.com/workload-type
                operator: In
                values: ["database"]
          
          # PREFERRED: Optimize placement
          preferredDuringSchedulingIgnoredDuringExecution:
          # Prefer primary zone for lower latency
          - weight: 100
            preference:
              matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values: ["us-west-2a"]
          # Prefer newer instance types
          - weight: 80
            preference:
              matchExpressions:
              - key: node.kubernetes.io/instance-type
                operator: In
                values: ["r5.4xlarge", "r5.8xlarge"]
      
      containers:
      - name: postgres
        image: postgres:15
        resources:
          requests:
            memory: "8Gi"
            cpu: "2"
          limits:
            memory: "16Gi"
            cpu: "4"
```

### Batch Processing with Cost Optimization
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-processing
  annotations:
    team.company.com/owner: "analytics-team"
    cost.company.com/optimization: "spot-instances"
spec:
  parallelism: 10
  completions: 50
  template:
    spec:
      affinity:
        nodeAffinity:
          # PREFERRED: Use spot instances for cost savings
          preferredDuringSchedulingIgnoredDuringExecution:
          # Strongly prefer spot instances
          - weight: 100
            preference:
              matchExpressions:
              - key: node.kubernetes.io/lifecycle
                operator: In
                values: ["spot"]
          # Prefer compute-optimized instances for batch work
          - weight: 80
            preference:
              matchExpressions:
              - key: node.kubernetes.io/instance-type
                operator: In
                values: ["c5.large", "c5.xlarge", "c5.2xlarge"]
          # Distribute across zones for availability
          - weight: 60
            preference:
              matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values: ["us-west-2a", "us-west-2b", "us-west-2c"]
          
          # REQUIRED: Avoid dedicated nodes
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              # Don't use dedicated database or production nodes
              - key: node.company.com/workload-type
                operator: NotIn
                values: ["database", "production-web"]
      
      containers:
      - name: processor
        image: data-processor:v1.0
        resources:
          requests:
            memory: "2Gi"
            cpu: "1"
          limits:
            memory: "4Gi"
            cpu: "2"
      
      # Handle node failures gracefully for spot instances
      restartPolicy: OnFailure
  backoffLimit: 5
```

### Compliance-Required Workload
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: financial-processor
  annotations:
    team.company.com/owner: "fintech-team"
    compliance.company.com/pci-required: "true"
    security.company.com/classification: "confidential"
spec:
  replicas: 3
  template:
    spec:
      affinity:
        nodeAffinity:
          # REQUIRED: Strict compliance requirements
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              # PCI-compliant nodes only
              - key: compliance.company.com/pci-compliant
                operator: In
                values: ["true"]
              # Specific geographic zones for data sovereignty
              - key: topology.kubernetes.io/zone
                operator: In
                values: ["us-east-1a", "us-east-1b"]
              # Dedicated tenancy for isolation
              - key: node.kubernetes.io/tenancy
                operator: In
                values: ["dedicated"]
              # No preemptible instances
              - key: node.kubernetes.io/lifecycle
                operator: NotIn
                values: ["spot", "preemptible"]
              # Minimum security standards
              - key: security.company.com/baseline
                operator: In
                values: ["level-3", "level-4"]
      
      # Additional security context
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      
      containers:
      - name: processor
        image: financial-processor:secure-v1.0
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
```

## Advanced Patterns

### Complex Multi-Requirement Affinity
```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        # Multiple node selector terms = OR logic
        nodeSelectorTerms:
        # Option 1: High-performance nodes in zone A
        - matchExpressions:
          - key: topology.kubernetes.io/zone
            operator: In
            values: ["us-west-2a"]
          - key: node.company.com/performance-tier
            operator: In
            values: ["high"]
        # Option 2: Medium-performance nodes with SSD in zone B  
        - matchExpressions:
          - key: topology.kubernetes.io/zone
            operator: In
            values: ["us-west-2b"]
          - key: node.company.com/performance-tier
            operator: In
            values: ["medium"]
          - key: node.company.com/storage-type
            operator: In
            values: ["ssd"]
```

### Combining with Pod Affinity
```yaml
spec:
  affinity:
    # Node affinity: Control which nodes
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: accelerator
            operator: In
            values: ["nvidia-tesla-p100"]
    
    # Pod affinity: Control which pods are nearby
    podAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values: ["data-cache"]
          topologyKey: kubernetes.io/hostname
```

## Common Operations

### Node Labeling
```bash
# Add labels to nodes
kubectl label node worker-1 accelerator=nvidia-tesla-p100
kubectl label node worker-1 node.company.com/memory-gb=64
kubectl label node worker-1 node.company.com/storage-type=ssd

# Remove labels
kubectl label node worker-1 accelerator-
kubectl label node worker-1 node.company.com/memory-gb-

# View node labels
kubectl get nodes --show-labels
kubectl describe node worker-1
```

### Debugging Placement
```bash
# Check why pod isn't scheduling
kubectl describe pod <pod-name>
kubectl get events --field-selector involvedObject.name=<pod-name>

# View current pod placement
kubectl get pods -o wide
kubectl get pods -o json | jq '.items[] | {name: .metadata.name, node: .spec.nodeName}'

# Check node capacity
kubectl describe node <node-name>
kubectl top node <node-name>
```

### Testing Affinity Rules
```bash
# Create test pod with affinity
kubectl run test-pod --image=busybox --dry-run=client -o yaml -- sleep 3600 > test-pod.yaml

# Add affinity to test-pod.yaml, then apply
kubectl apply -f test-pod.yaml

# Check placement
kubectl get pod test-pod -o wide
kubectl describe pod test-pod | grep -A 10 "Node-Selectors"
```

## Troubleshooting

### Pod Stuck in Pending
```bash
# Check scheduler events
kubectl describe pod <pending-pod>

# Common issues:
# - No nodes match required affinity
# - Insufficient resources on matching nodes
# - Node selector conflicts with taints
# - Spelling errors in label keys/values
```

### Unexpected Pod Placement
```bash
# Verify node labels
kubectl get nodes --show-labels | grep <expected-label>

# Check if preferred affinity is working
kubectl describe pod <pod-name> | grep -A 20 "Events:"

# Verify no conflicting constraints
kubectl describe pod <pod-name> | grep -A 10 "Affinity"
```

### Performance Issues
```bash
# Monitor scheduler performance
kubectl get events | grep "FailedScheduling"

# Check for over-constrained affinity
kubectl get pods --field-selector=status.phase=Pending

# Consider relaxing affinity constraints
```

## Best Practices

### Label Strategy
```yaml
# Use consistent, hierarchical labels
node.company.com/environment: "production"
node.company.com/workload-type: "database"
node.company.com/performance-tier: "high"
node.company.com/cost-tier: "reserved"

# Standard topology labels (auto-populated)
topology.kubernetes.io/zone
topology.kubernetes.io/region
node.kubernetes.io/instance-type
node.kubernetes.io/lifecycle
```

### Affinity Design
```yaml
# Start with required, add preferred for optimization
requiredDuringSchedulingIgnoredDuringExecution:
  # Critical business requirements
  nodeSelectorTerms:
  - matchExpressions:
    - key: compliance.company.com/pci-compliant
      operator: In
      values: ["true"]

preferredDuringSchedulingIgnoredDuringExecution:
  # Performance and cost optimizations
  - weight: 100
    preference:
      matchExpressions:
      - key: node.company.com/performance-tier
        operator: In
        values: ["high"]
```

### Operational Guidelines
```yaml
metadata:
  annotations:
    # Document affinity requirements
    scheduling.company.com/requirements: "PCI-compliant nodes only"
    scheduling.company.com/rationale: "Financial data processing"
    
    # Contact information
    team.company.com/owner: "fintech-team"
    team.company.com/oncall: "#fintech-alerts"
```

## Performance Considerations

### Scheduler Impact
- Use node affinity sparingly in large clusters
- Prefer labels over complex expressions
- Monitor scheduling latency and success rates
- Combine with cluster autoscaler node groups

### Resource Planning
- Ensure sufficient node capacity for required affinity
- Plan for node failures and maintenance
- Monitor resource utilization across zones
- Use preferred affinity for graceful degradation

## Integration with Other Features

### Cluster Autoscaler
```yaml
# Node groups with specific labels
# Cluster autoscaler can scale based on pending pods with affinity
nodeSelector:
  node.company.com/instance-type: "gpu"
```

### Pod Disruption Budgets
```yaml
# Protect critical pods with specific placement
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: database-pdb
spec:
  maxUnavailable: 0
  selector:
    matchLabels:
      app: postgres-primary
```

## Key Insights

**Node affinity is about business requirements** - use it when default scheduling doesn't meet your needs

**Required vs preferred matters** - required can cause pods to be unschedulable, preferred provides graceful degradation

**Label consistency is critical** - establish and maintain consistent node labeling conventions

**Test thoroughly** - verify affinity rules work as expected before deploying to production

**Monitor scheduling success** - track pending pods and scheduling failures in production

**Combine with other scheduling features** - node affinity works well with pod affinity, taints, and topology spread constraints

**Balance specificity with flexibility** - over-constraining can lead to scheduling failures and resource waste