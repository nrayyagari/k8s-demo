# Autoscaling: Handle Traffic Spikes Automatically

## WHY Does Autoscaling Exist?

**Problem**: Traffic spikes overwhelm fixed number of pods, manual scaling is slow  
**Solution**: Automatically add/remove pods based on CPU, memory, or custom metrics

## The Core Question

**"How do I handle unpredictable traffic without wasting resources?"**

Fixed replicas: Traffic spike → overloaded → users suffer  
Autoscaling: Traffic spike → more pods → load distributed → users happy

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

## Files in This Directory

1. **SIMPLE-AUTOSCALING.yaml** - Complete beginner example with CPU scaling
2. **00-setup-prerequisites.yaml** - Metrics server installation guide

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