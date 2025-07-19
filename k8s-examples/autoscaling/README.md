# Autoscaling: Handle Traffic Spikes Automatically

## WHY Does Autoscaling Exist?

**Problem**: Traffic spikes overwhelm infrastructure, manual scaling is slow and expensive  
**Solution**: Automatically scale pods AND nodes based on demand

## The Core Questions

**"How do I handle unpredictable traffic without wasting resources?"**  
**"What if I need more nodes for all these new pods?"**

Two levels of scaling:
1. **Pod-level**: More/fewer replicas (HPA/VPA)
2. **Cluster-level**: More/fewer nodes (Cluster Autoscaler/Karpenter)

## The Two-Level Scaling Pattern

```
Traffic Spike → HPA adds pods → No capacity → Cluster Autoscaler adds nodes → Pods scheduled
Traffic Drop → HPA removes pods → Nodes underutilized → Cluster Autoscaler removes nodes
```

## Horizontal Pod Autoscaler (HPA)

### What it Does
- **Scale out**: Add more pods when busy
- **Scale in**: Remove pods when idle  
- **Automatic**: No manual intervention needed
- **Metrics-based**: CPU, memory, or custom metrics

### Basic Pattern
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2          # Never less than 2
  maxReplicas: 10         # Never more than 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70  # Scale when CPU > 70%
```

## Prerequisites

### 1. Resource Requests (Critical!)
```yaml
# ❌ Won't work - no requests defined
containers:
- name: app
  image: myapp:v1
  resources:
    limits:
      cpu: 500m
      memory: 512Mi

# ✅ Will work - requests defined  
containers:
- name: app
  image: myapp:v1
  resources:
    requests:
      cpu: 100m      # HPA uses this for % calculation
      memory: 128Mi  # Required for memory-based scaling
    limits:
      cpu: 500m
      memory: 512Mi
```

### 2. Metrics Server
```bash
# Check if metrics server is installed
kubectl top nodes
kubectl top pods

# Install if missing
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

## Scaling Behavior

### Scale Up (Fast Response)
```
Current: 2 pods at 80% CPU
Action: Add 2 more pods → 4 total
Wait: 3 minutes before next scale up
Check: CPU drops to 40% per pod
```

### Scale Down (Conservative)
```
Current: 10 pods at 20% CPU  
Action: Remove 2 pods → 8 total
Wait: 5 minutes before next scale down
Check: CPU still low → remove more
```

**Why different timings?** 
- Scale up fast (users waiting)
- Scale down slow (avoid thrashing)

## Complete Example

```yaml
# Application with resource requests
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m      # Required for HPA
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi

---
# Service to expose the app
apiVersion: v1
kind: Service
metadata:
  name: web-app-service
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80

---
# HPA to scale automatically
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## Advanced Metrics

### Memory-Based Scaling
```yaml
metrics:
- type: Resource
  resource:
    name: memory
    target:
      type: Utilization
      averageUtilization: 80
```

### Multiple Metrics (OR condition)
```yaml
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      type: Utilization
      averageUtilization: 70
- type: Resource
  resource:
    name: memory
    target:
      type: Utilization
      averageUtilization: 80
```

### Custom Metrics
```yaml
metrics:
- type: Pods
  pods:
    metric:
      name: packets-per-second
    target:
      type: AverageValue
      averageValue: "1k"
```

## Cluster Autoscaling: Node-Level Scaling

### The Node Capacity Problem
```
Scenario: HPA wants to scale from 5 to 20 pods
Current cluster: 3 nodes, each can fit 6 pods (18 total capacity)
Problem: Only room for 13 more pods, need 15
Solution: Add more nodes automatically
```

### Two Approaches: Cluster Autoscaler vs Karpenter

#### Cluster Autoscaler (Traditional)
- **What**: Scales existing node groups up/down
- **How**: Monitors pending pods, adds nodes from predefined groups
- **Good for**: Traditional VM-based clusters, existing node groups
- **Limitation**: Must pre-define node types and sizes

#### Karpenter (Modern - AWS)
- **What**: Provisions optimal nodes on-demand
- **How**: Analyzes pending pod requirements, creates perfect-fit nodes
- **Good for**: Cloud-native, cost optimization, diverse workloads
- **Advantage**: No pre-defined node groups, just-in-time provisioning

## Cluster Autoscaler: Traditional Approach

### How It Works
1. **Pending Pods**: HPA creates pods that can't be scheduled
2. **Scale Decision**: Cluster Autoscaler detects unschedulable pods
3. **Node Addition**: Adds nodes from existing node groups
4. **Pod Scheduling**: Kubernetes schedules pending pods on new nodes
5. **Scale Down**: Removes underutilized nodes after cooldown period

### Basic Setup (AWS EKS Example)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
      - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.21.0
        name: cluster-autoscaler
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/my-cluster
```

### Node Group Configuration
```yaml
# Auto Scaling Group tags for discovery
tags:
  k8s.io/cluster-autoscaler/enabled: "true"
  k8s.io/cluster-autoscaler/my-cluster: "owned"
  
# Node group settings
min_size: 1
max_size: 10
desired_capacity: 3
```

## Karpenter: Modern Node Provisioning

### WHY Karpenter is Better
**Problem with Cluster Autoscaler**: Pre-defined node groups waste resources
- Need CPU-intensive pods → adds general-purpose nodes → waste memory
- Need GPU workloads → no GPU node group → pods stay pending

**Karpenter Solution**: Just-in-time optimal node provisioning
- Analyzes exact requirements of pending pods
- Provisions cheapest compatible instance types
- Supports diverse workloads without pre-planning

### How Karpenter Works
1. **Pod Analysis**: Reads pending pod requirements (CPU, memory, GPU, etc.)
2. **Instance Selection**: Finds cheapest instance types that satisfy requirements
3. **Node Provisioning**: Creates nodes with optimal instance types
4. **Fast Scheduling**: Pods scheduled within ~30 seconds
5. **Consolidation**: Continuously optimizes node utilization

### Karpenter NodePool Configuration
```yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
spec:
  # Template for provisioned nodes
  template:
    metadata:
      labels:
        intent: apps
    spec:
      # Requirements for node provisioning
      requirements:
      - key: kubernetes.io/arch
        operator: In
        values: ["amd64"]
      - key: kubernetes.io/os
        operator: In
        values: ["linux"]
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["spot", "on-demand"]  # Cost optimization
      - key: node.kubernetes.io/instance-type
        operator: In
        values:
        - c5.large
        - c5.xlarge
        - c5.2xlarge
        - m5.large
        - m5.xlarge
        - m5.2xlarge
        - r5.large
        - r5.xlarge
      
      # Node configuration
      nodeClassRef:
        apiVersion: karpenter.k8s.aws/v1beta1
        kind: EC2NodeClass
        name: default
      
      # Kubelet configuration
      kubelet:
        maxPods: 110
        
  # Scaling limits
  limits:
    cpu: 1000      # Max 1000 CPU cores
    memory: 1000Gi # Max 1TB memory
  
  # Disruption settings
  disruption:
    consolidationPolicy: WhenUnderutilized
    consolidateAfter: 30s
    expireAfter: 30m  # Nodes expire after 30 minutes if idle
```

### EC2NodeClass for AWS
```yaml
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
spec:
  # Instance configuration
  amiFamily: AL2
  subnetSelectorTerms:
  - tags:
      karpenter.sh/discovery: "my-cluster"
  securityGroupSelectorTerms:
  - tags:
      karpenter.sh/discovery: "my-cluster"
  
  # Instance profile for nodes
  role: KarpenterNodeInstanceProfile
  
  # User data for node initialization
  userData: |
    #!/bin/bash
    /etc/eks/bootstrap.sh my-cluster
    
  # Storage configuration
  blockDeviceMappings:
  - deviceName: /dev/xvda
    ebs:
      volumeSize: 100Gi
      volumeType: gp3
      encrypted: true
```

### Workload-Specific Node Provisioning
```yaml
# GPU workload
apiVersion: v1
kind: Pod
metadata:
  name: gpu-training
spec:
  containers:
  - name: tensorflow
    image: tensorflow/tensorflow:latest-gpu
    resources:
      requests:
        nvidia.com/gpu: 1
        memory: 8Gi
        cpu: 4
  # Karpenter will provision p3.2xlarge or similar GPU instance
  
---
# Memory-intensive workload  
apiVersion: v1
kind: Pod
metadata:
  name: memory-intensive
spec:
  containers:
  - name: bigdata
    image: apache/spark:latest
    resources:
      requests:
        memory: 32Gi
        cpu: 2
  # Karpenter will provision r5.2xlarge or similar high-memory instance
```

## Cluster Autoscaling Best Practices

### 1. Pod Disruption Budgets
```yaml
# Prevent autoscaling from breaking your app
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: web-app
```

### 2. Node Affinity for Workload Isolation
```yaml
# Keep expensive workloads on dedicated nodes
apiVersion: v1
kind: Pod
metadata:
  name: gpu-workload
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: karpenter.sh/capacity-type
            operator: In
            values: ["on-demand"]  # Only on-demand for GPU workloads
```

### 3. Resource Requests (Critical!)
```yaml
# Cluster autoscaler needs accurate resource requests
spec:
  containers:
  - name: app
    image: myapp:v1
    resources:
      requests:
        cpu: 500m      # Actual CPU needed for scheduling decisions
        memory: 1Gi    # Actual memory needed for scheduling decisions
```

### 4. Spot Instance Handling
```yaml
# NodePool with spot instances
spec:
  template:
    spec:
      requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["spot", "on-demand"]
      
      # Handle spot interruptions gracefully
      taints:
      - key: karpenter.sh/capacity-type
        value: spot
        effect: NoSchedule
```

## Cluster Autoscaler vs Karpenter Comparison

| Feature | Cluster Autoscaler | Karpenter |
|---------|-------------------|-----------|
| **Node Groups** | Requires pre-defined | Dynamic provisioning |
| **Instance Selection** | Limited to group types | Optimal instance selection |
| **Speed** | 3-5 minutes | 30-60 seconds |
| **Cost Optimization** | Manual tuning | Automatic optimization |
| **Spot Instances** | Manual configuration | Built-in support |
| **Mixed Workloads** | Multiple node groups needed | Single configuration |
| **Learning Curve** | Lower | Higher |
| **Cloud Support** | Multi-cloud | AWS (primarily) |

## Files in This Directory

1. **SIMPLE-AUTOSCALING.yaml** - Complete beginner example with CPU scaling
2. **00-setup-prerequisites.yaml** - Metrics server installation guide
3. **06-cluster-autoscaler.yaml** - Traditional cluster autoscaling setup
4. **07-karpenter-setup.yaml** - Modern Karpenter configuration
5. **08-mixed-workloads.yaml** - Different workload types with optimal scaling

## Quick Start

```bash
# 1. Install metrics server (if needed)
kubectl apply -f 00-setup-prerequisites.yaml

# 2. Deploy application with HPA
kubectl apply -f SIMPLE-AUTOSCALING.yaml

# 3. Check HPA status
kubectl get hpa
kubectl describe hpa web-app-hpa

# 4. Generate load to test scaling
kubectl run load-generator --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://web-app-service; done"

# 5. Watch scaling in action
kubectl get hpa --watch
kubectl get pods --watch
```

## Monitoring Autoscaling

### Check HPA Status
```bash
# List all HPAs
kubectl get hpa

# Detailed view
kubectl describe hpa web-app-hpa

# Watch real-time changes
kubectl get hpa --watch
```

### Monitor Resource Usage
```bash
# Current resource usage
kubectl top pods
kubectl top nodes

# HPA metrics
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods | jq .
```

## Autoscaling Best Practices

### Resource Requests
```yaml
# Set realistic requests based on actual usage
resources:
  requests:
    cpu: 100m     # Actual baseline usage
    memory: 256Mi # Actual memory needed
  limits:
    cpu: 1000m    # Reasonable ceiling
    memory: 1Gi   # Prevent memory leaks
```

### Scaling Parameters
```yaml
# Conservative settings for production
spec:
  minReplicas: 3        # High availability
  maxReplicas: 20       # Reasonable ceiling
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60  # Leave headroom
```

### Application Requirements
```yaml
# Apps should be:
# ✅ Stateless
# ✅ Fast startup
# ✅ Graceful shutdown
# ✅ Handle load balancing

# ❌ Don't autoscale:
# - Databases (use StatefulSets)
# - Single-instance apps
# - Apps with long startup times
# - Apps that don't handle load balancing
```

## Troubleshooting

### HPA Not Scaling
```bash
# Check metrics are available
kubectl top pods
kubectl describe hpa web-app-hpa

# Common issues:
# - No resource requests defined
# - Metrics server not installed
# - Target deployment doesn't exist
# - Pods not reaching target utilization
```

### Scaling Too Aggressively
```yaml
# Adjust scaling behavior
spec:
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 300  # Wait 5 min between scale ups
    scaleDown:
      stabilizationWindowSeconds: 600  # Wait 10 min between scale downs
```

### Wrong Metrics
```bash
# Check actual resource usage
kubectl top pods -l app=web-app

# Adjust target utilization based on real usage
# If pods typically run at 50%, set target to 60-70%
```

## Vertical Pod Autoscaler (VPA)

### What it Does
VPA adjusts resource requests/limits automatically:
- Bigger containers instead of more containers
- Good for single-replica workloads
- Requires pod restart to apply changes

### Basic VPA Example
```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: web-app-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  updatePolicy:
    updateMode: "Auto"  # Automatically apply recommendations
```

## HPA vs VPA vs Manual

### Use HPA When:
✅ **Traffic varies** throughout the day  
✅ **App can scale horizontally** (stateless)  
✅ **Fast startup** times  
✅ **Need high availability** (multiple replicas)

### Use VPA When:
✅ **Single replica** workloads  
✅ **Resource requirements change** over time  
✅ **Manual sizing is difficult**  
✅ **Restart tolerance** exists

### Use Manual Scaling When:
✅ **Predictable traffic** patterns  
✅ **Cost optimization** is priority  
✅ **Complex scaling logic** needed  
✅ **Testing/development** environments

## Key Insights

**Autoscaling saves money and improves performance** - but requires proper setup

**Resource requests are mandatory** - HPA can't work without them

**Start conservative** - easier to loosen constraints than fix aggressive scaling

**Monitor and adjust** - initial settings are rarely perfect

**Not all applications can autoscale** - stateful apps and databases usually can't

**Combine with proper health checks** - ensure new pods are ready before receiving traffic

**Test your scaling** - generate load and verify behavior before production