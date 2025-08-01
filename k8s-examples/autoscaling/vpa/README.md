# Vertical Pod Autoscaler (VPA): Right-Size Your Containers

## WHY Does VPA Exist?

**Problem**: Containers are sized wrong - too small (performance issues) or too large (wasted resources)  
**Solution**: Automatically adjust CPU/memory requests and limits based on actual usage

## The Core Question

**"What if I don't know how much CPU and memory my app actually needs?"**

Without VPA: Guess resource requirements → either waste money or hurt performance  
With VPA: Monitor actual usage → automatically right-size containers → optimal cost and performance

## VPA vs HPA: Different Scaling Approaches

### Horizontal Pod Autoscaler (HPA)
- **Scale Out**: More pods when busy
- **Use Case**: Variable traffic, stateless apps
- **Result**: Same container size, more instances

### Vertical Pod Autoscaler (VPA)  
- **Scale Up**: Bigger containers when needed
- **Use Case**: Single-instance apps, unpredictable resource needs
- **Result**: Same pod count, different container sizes

```
HPA Approach: 1 pod (1 CPU, 1GB) → 3 pods (1 CPU, 1GB each) = 3 CPU, 3GB total
VPA Approach: 1 pod (1 CPU, 1GB) → 1 pod (3 CPU, 3GB) = 3 CPU, 3GB total
```

## Simple VPA Pattern

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: my-app-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  updatePolicy:
    updateMode: "Auto"      # Automatically apply recommendations
  resourcePolicy:
    containerPolicies:
    - containerName: app
      maxAllowed:
        cpu: 2            # Never exceed 2 CPU cores
        memory: 4Gi       # Never exceed 4GB memory
      minAllowed:
        cpu: 100m         # Never go below 0.1 CPU
        memory: 128Mi     # Never go below 128MB
```

## VPA Update Modes

### 1. "Off" Mode (Recommendation Only)
```yaml
updatePolicy:
  updateMode: "Off"
```
- **What it does**: Provides recommendations without changing anything
- **Use case**: Analysis and planning phase
- **Safety**: Completely safe, no pod disruption

### 2. "Initial" Mode (New Pods Only)
```yaml
updatePolicy:
  updateMode: "Initial"
```
- **What it does**: Sets resources for new pods only
- **Use case**: Gradual rollout with deployments
- **Safety**: No disruption to existing pods

### 3. "Auto" Mode (Full Automation)
```yaml
updatePolicy:
  updateMode: "Auto"
```
- **What it does**: Automatically updates existing pods (requires restart)
- **Use case**: Full automation for appropriate workloads
- **Safety**: Causes pod restarts when resources change

## Critical VPA Prerequisites

### 1. VPA Installation (Not Included by Default)
```bash
# Check if VPA is installed
kubectl get crd verticalpodautoscalers.autoscaling.k8s.io

# Install VPA (example for most clusters)
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler/
./hack/vpa-install.sh

# Verify installation
kubectl get pods -n kube-system | grep vpa
```

### 2. Initial Resource Requests (Recommended)
```yaml
# Provide starting point for VPA
containers:
- name: app
  image: myapp:v1
  resources:
    requests:
      cpu: 100m      # VPA will adjust from here
      memory: 128Mi  # VPA will adjust from here
```

### 3. Understanding Pod Restart Behavior
**Important**: VPA in "Auto" mode restarts pods to apply new resource allocations
- Plan for brief service interruption
- Ensure multiple replicas for availability
- Consider using "Initial" mode for critical services

## Complete VPA Example

```yaml
# Application that we want to right-size
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-hungry-app
  labels:
    app: resource-hungry-app
spec:
  replicas: 2           # Multiple replicas to handle VPA restarts
  selector:
    matchLabels:
      app: resource-hungry-app
  template:
    metadata:
      labels:
        app: resource-hungry-app
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        # Initial resource guess (VPA will optimize these)
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 1
            memory: 1Gi
        # Health checks are important for VPA restarts
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5

---
# Service for the application
apiVersion: v1
kind: Service
metadata:
  name: resource-hungry-service
spec:
  selector:
    app: resource-hungry-app
  ports:
  - port: 80
    targetPort: 80

---
# VPA configuration
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: resource-hungry-vpa
spec:
  # Target the deployment
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: resource-hungry-app
  
  # Update policy
  updatePolicy:
    updateMode: "Auto"    # Automatically apply recommendations
  
  # Resource boundaries and policies
  resourcePolicy:
    containerPolicies:
    - containerName: app
      # Minimum allowed resources
      minAllowed:
        cpu: 50m          # Never go below 50m CPU
        memory: 64Mi      # Never go below 64MB memory
      
      # Maximum allowed resources  
      maxAllowed:
        cpu: 4            # Never exceed 4 CPU cores
        memory: 8Gi       # Never exceed 8GB memory
      
      # Which resources VPA can control
      controlledResources: ["cpu", "memory"]
      
      # How VPA handles resource values
      controlledValues: RequestsAndLimits  # Update both requests and limits
```

## VPA Resource Policies

### Container-Level Policies
```yaml
resourcePolicy:
  containerPolicies:
  - containerName: "app"
    # Control which resources VPA manages
    controlledResources: ["cpu", "memory"]
    
    # Control what VPA updates
    controlledValues: RequestsAndLimits  # Options: RequestsAndLimits, RequestsOnly
    
    # Resource boundaries
    minAllowed:
      cpu: 100m
      memory: 128Mi
    maxAllowed:
      cpu: 2
      memory: 4Gi
    
    # Scaling mode for this container
    mode: Auto  # Options: Auto, Off
```

### Advanced Resource Controls
```yaml
resourcePolicy:
  containerPolicies:
  - containerName: "web-server"
    # CPU-focused scaling
    controlledResources: ["cpu"]
    maxAllowed:
      cpu: 2
    minAllowed:
      cpu: 100m
      
  - containerName: "cache"
    # Memory-focused scaling  
    controlledResources: ["memory"]
    maxAllowed:
      memory: 8Gi
    minAllowed:
      memory: 512Mi
```

## Files in This Directory

1. **01-basic-vpa.yaml** - Simple VPA with auto mode
2. **02-recommendation-only.yaml** - VPA in "Off" mode for analysis
3. **03-advanced-policies.yaml** - Complex resource policies and boundaries
4. **04-multi-container-vpa.yaml** - VPA for pods with multiple containers
5. **SIMPLE-VPA.yaml** - Quick start example

## Quick Start

```bash
# Check if VPA is installed
kubectl get crd verticalpodautoscalers.autoscaling.k8s.io

# Deploy VPA example (if VPA is installed)
kubectl apply -f 01-basic-vpa.yaml

# Check VPA status and recommendations
kubectl get vpa
kubectl describe vpa resource-hungry-vpa

# Watch VPA recommendations develop over time
kubectl get vpa resource-hungry-vpa -o yaml | grep -A 10 recommendation

# Monitor pod resource changes (if using Auto mode)
kubectl get pods -o custom-columns=NAME:.metadata.name,CPU-REQ:.spec.containers[0].resources.requests.cpu,MEM-REQ:.spec.containers[0].resources.requests.memory
```

## Monitoring VPA Recommendations

### View Current Recommendations
```bash
# List all VPAs
kubectl get vpa

# Detailed VPA information
kubectl describe vpa my-app-vpa

# Raw recommendation data
kubectl get vpa my-app-vpa -o jsonpath='{.status.recommendation.containerRecommendations[0]}'
```

### Understanding VPA Metrics
```yaml
# VPA provides three types of recommendations:
status:
  recommendation:
    containerRecommendations:
    - containerName: app
      lowerBound:         # Minimum recommended resources
        cpu: 150m
        memory: 256Mi
      target:             # Optimal recommended resources  
        cpu: 300m
        memory: 512Mi
      upperBound:         # Maximum beneficial resources
        cpu: 500m
        memory: 1Gi
```

## VPA Best Practices

### 1. Start with Recommendation Mode
```yaml
# Begin with analysis, not automation
updatePolicy:
  updateMode: "Off"

# Analyze recommendations for 1-2 weeks
# Then switch to "Initial" or "Auto" mode
```

### 2. Set Reasonable Boundaries
```yaml
resourcePolicy:
  containerPolicies:
  - containerName: app
    # Prevent VPA from going too small
    minAllowed:
      cpu: 100m
      memory: 128Mi
    # Prevent VPA from going too large  
    maxAllowed:
      cpu: 4          # Based on node capacity
      memory: 8Gi     # Based on workload requirements
```

### 3. Applications Suitable for VPA
- **Single-replica applications**: Databases, caches, singletons
- **Batch jobs**: ETL processes, data analysis
- **Stateful applications**: Where horizontal scaling is complex
- **Unknown resource requirements**: New applications without historical data
- **Development environments**: Optimize resource usage

### 4. Applications NOT Suitable for VPA
- **High-availability services**: Pod restarts cause downtime
- **Latency-sensitive**: Restart disruption unacceptable  
- **Well-tuned applications**: Already optimized resource usage
- **Frequent deployments**: VPA recommendations become stale quickly

## VPA vs HPA Combination

### Can You Use Both?
**Generally not recommended** on the same resource (CPU), but possible with care:

```yaml
# HPA on CPU, VPA on memory only
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: combined-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: app
      controlledResources: ["memory"]  # Only memory, not CPU
      maxAllowed:
        memory: 4Gi

---
# HPA scales based on CPU
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: combined-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu              # Only CPU, not memory
      target:
        type: Utilization
        averageUtilization: 70
```

## Real-World VPA Scenarios

### Scenario 1: Database Right-Sizing
```yaml
# PostgreSQL instance with unknown memory requirements
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: postgres-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: postgres
  updatePolicy:
    updateMode: "Initial"    # Only new pods (safer for databases)
  resourcePolicy:
    containerPolicies:
    - containerName: postgres
      controlledResources: ["memory"]  # Focus on memory for databases
      minAllowed:
        memory: 1Gi
      maxAllowed:
        memory: 16Gi
```

### Scenario 2: Batch Job Optimization
```yaml
# ETL job with variable resource needs
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: etl-job-vpa
spec:
  targetRef:
    apiVersion: batch/v1
    kind: Job
    name: daily-etl
  updatePolicy:
    updateMode: "Initial"    # New jobs get optimized resources
  resourcePolicy:
    containerPolicies:
    - containerName: etl-worker
      minAllowed:
        cpu: 500m
        memory: 1Gi
      maxAllowed:
        cpu: 8
        memory: 32Gi
```

## Troubleshooting VPA

### VPA Not Providing Recommendations
```bash
# Check VPA installation
kubectl get pods -n kube-system | grep vpa

# Check VPA CRD exists
kubectl get crd verticalpodautoscalers.autoscaling.k8s.io

# Verify target deployment exists
kubectl get deployment my-app

# Check VPA has enough data (wait 24-48 hours for recommendations)
kubectl describe vpa my-app-vpa
```

### VPA Recommendations Seem Wrong
```bash
# Check actual resource usage
kubectl top pods -l app=my-app

# Look at historical usage patterns
kubectl get vpa my-app-vpa -o yaml | grep -A 20 recommendation

# Verify resource policies aren't too restrictive
kubectl describe vpa my-app-vpa | grep -A 10 "Resource Policy"
```

### Pods Not Being Updated (Auto Mode)
```bash
# Check update policy
kubectl get vpa my-app-vpa -o yaml | grep updateMode

# Look for VPA events
kubectl get events --field-selector involvedObject.name=my-app-vpa

# Verify pods have resource requests set
kubectl describe pod <pod-name> | grep -A 5 "Requests"
```

## Key Insights

**VPA is about optimization, not scaling** - it finds the right container size, not the right number of containers

**Recommendations take time** - VPA needs 24-48 hours of data to provide good recommendations

**Pod restarts are inevitable** - "Auto" mode requires restarts to apply new resource allocations

**Start conservative** - begin with "Off" or "Initial" mode, then graduate to "Auto"

**Not all apps benefit** - VPA works best for applications with unpredictable or unknown resource patterns

**Monitor the impact** - track both resource usage and application performance after VPA changes

**Combine thoughtfully** - VPA + HPA can work together but requires careful configuration

VPA helps you **stop guessing** about resource requirements and **start optimizing** based on real usage data - leading to both cost savings and better performance.