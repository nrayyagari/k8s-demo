# Horizontal Pod Autoscaler (HPA): Scale Out When Busy

## WHY Does HPA Exist?

**Problem**: Traffic spikes overwhelm fixed number of pods, causing slowdowns and timeouts  
**Solution**: Automatically add/remove pods based on real-time metrics

## The Core Question

**"How do I handle unpredictable traffic without manually watching metrics?"**

Without HPA: Traffic spike → pods overloaded → users wait → manual scaling → too late  
With HPA: Traffic spike → CPU rises → HPA adds pods → load distributed → users happy

## HPA Fundamentals

### What HPA Does
- **Scale Out**: Add more pod replicas when metrics exceed targets
- **Scale In**: Remove pod replicas when metrics drop below targets  
- **Automatic**: No human intervention required
- **Metrics-Based**: CPU, memory, or custom application metrics

### How HPA Works
```
1. HPA checks metrics every 15 seconds
2. Compares current vs target utilization
3. Calculates desired replica count
4. Updates Deployment replica count
5. Kubernetes schedules/removes pods
6. Load balancer distributes traffic
```

## Simple HPA Pattern

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
  minReplicas: 2          # Never less than 2 (availability)
  maxReplicas: 10         # Never more than 10 (cost control)
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70  # Scale when average CPU > 70%
```

## Critical Prerequisites

### 1. Resource Requests (Mandatory!)
```yaml
# ❌ HPA cannot work - no requests
containers:
- name: app
  image: myapp:v1
  resources:
    limits:
      cpu: 500m

# ✅ HPA can calculate percentages
containers:
- name: app  
  image: myapp:v1
  resources:
    requests:
      cpu: 100m      # HPA uses this for % calculation
      memory: 128Mi  # Required for memory-based scaling
    limits:
      cpu: 500m      # Prevents runaway resource usage
      memory: 512Mi
```

### 2. Metrics Server Installation
```bash
# Check if metrics server exists
kubectl top nodes
kubectl top pods

# Install if missing (required for resource metrics)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify installation
kubectl get deployment metrics-server -n kube-system
```

## HPA Scaling Behavior

### Scale Up Decision (Aggressive)
```
Current: 3 pods at 80% CPU average
Target: 70% CPU
Calculation: 3 * (80/70) = 3.4 → 4 pods
Action: Add 1 pod
Wait: 3 minutes before next scale up decision
```

### Scale Down Decision (Conservative)  
```
Current: 8 pods at 40% CPU average
Target: 70% CPU
Calculation: 8 * (40/70) = 4.6 → 5 pods
Action: Remove 3 pods gradually
Wait: 5 minutes between scale down actions
```

**Why different timings?**
- **Scale up fast**: Users are waiting, performance matters
- **Scale down slow**: Avoid thrashing, maintain stability

## Complete Production Example

```yaml
# Application with proper resource specifications
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-api
  labels:
    app: web-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-api
  template:
    metadata:
      labels:
        app: web-api
    spec:
      containers:
      - name: api
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 200m        # Baseline CPU need
            memory: 256Mi    # Baseline memory need
          limits:
            cpu: 1           # Max CPU per pod
            memory: 1Gi      # Max memory per pod
        # Health checks are critical for HPA
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5

---
# Service for load balancing
apiVersion: v1
kind: Service
metadata:
  name: web-api-service
spec:
  selector:
    app: web-api
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP

---  
# HPA configuration
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-api
  minReplicas: 3            # High availability baseline
  maxReplicas: 20           # Reasonable cost ceiling
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60  # Conservative target
  # Advanced scaling behavior
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60    # Wait 1 min to stabilize
      policies:
      - type: Percent
        value: 50           # Max 50% increase per scale event
        periodSeconds: 60
      - type: Pods  
        value: 4            # Max 4 pods per scale event
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300   # Wait 5 min to stabilize
      policies:
      - type: Percent
        value: 10           # Max 10% decrease per scale event
        periodSeconds: 60
```

## Metric Types and Configurations

### 1. CPU-Based Scaling (Most Common)
```yaml
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      type: Utilization
      averageUtilization: 70    # Scale when average CPU > 70%
```

### 2. Memory-Based Scaling
```yaml
metrics:
- type: Resource
  resource:
    name: memory
    target:
      type: Utilization
      averageUtilization: 80    # Scale when average memory > 80%
```

### 3. Multiple Metrics (OR Logic)
```yaml
# Scale if EITHER CPU > 70% OR memory > 80%
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

### 4. Custom Application Metrics
```yaml
# Requires custom metrics API (Prometheus Adapter)
metrics:
- type: Pods
  pods:
    metric:
      name: requests_per_second
    target:
      type: AverageValue
      averageValue: "100"      # Scale when RPS > 100 per pod

- type: Object
  object:
    metric:
      name: queue_length
    describedObject:
      apiVersion: v1
      kind: Service
      name: message-queue
    target:
      type: Value
      value: "50"             # Scale when queue length > 50
```

## Files in This Directory

1. **01-basic-hpa.yaml** - Simple CPU-based autoscaling
2. **02-multi-metric-hpa.yaml** - CPU and memory metrics combined
3. **03-advanced-behavior.yaml** - Custom scaling behavior policies
4. **04-custom-metrics.yaml** - Application-specific metrics scaling
5. **05-production-setup.yaml** - Complete production-ready configuration
6. **SIMPLE-HPA.yaml** - Quick start example

## Quick Start

```bash
# Deploy basic HPA example
kubectl apply -f 01-basic-hpa.yaml

# Check HPA status
kubectl get hpa
kubectl describe hpa web-app-hpa

# Generate load to test scaling
kubectl run load-generator --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://web-app-service; done"

# Watch scaling in action
kubectl get hpa --watch
kubectl get pods --watch

# Clean up load test
kubectl delete pod load-generator
```

## Monitoring HPA

### Check HPA Status
```bash
# List all HPAs with current metrics
kubectl get hpa

# Detailed HPA information
kubectl describe hpa web-app-hpa

# Watch real-time changes
kubectl get hpa --watch

# HPA events and decisions
kubectl get events --field-selector involvedObject.name=web-app-hpa
```

### Monitor Resource Usage
```bash
# Current pod resource usage
kubectl top pods -l app=web-app

# Node resource usage
kubectl top nodes

# Historical metrics (if monitoring stack exists)
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods | jq '.items[] | {name: .metadata.name, cpu: .containers[0].usage.cpu, memory: .containers[0].usage.memory}'
```

## HPA Best Practices

### 1. Resource Request Sizing
```yaml
# Base requests on actual usage patterns
resources:
  requests:
    cpu: "200m"     # Actual baseline CPU usage
    memory: "256Mi" # Actual baseline memory usage
  limits:
    cpu: "1"        # Allow burst capacity
    memory: "1Gi"   # Prevent memory leaks
```

### 2. Conservative Scaling Targets
```yaml
# Leave headroom for traffic spikes
spec:
  minReplicas: 3              # Never less than 3 for availability
  maxReplicas: 15             # Prevent runaway scaling costs
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60  # Target 60%, not 90%
```

### 3. Application Requirements
Applications must be:
- **Stateless**: No dependency on specific pod instances
- **Fast startup**: Ready to serve traffic quickly (<30 seconds)
- **Graceful shutdown**: Handle SIGTERM properly
- **Load balancer friendly**: Work behind Kubernetes Services

### 4. Health Checks Integration
```yaml
# Ensure new pods are ready before receiving traffic
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  
# Ensure pods restart if unhealthy
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
```

## Advanced Scaling Policies

### Custom Scaling Behavior
```yaml
spec:
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60     # Wait 60s after metrics change
      policies:
      - type: Percent
        value: 100                       # Double replicas at most
        periodSeconds: 60
      - type: Pods
        value: 5                         # Add max 5 pods at once
        periodSeconds: 60
      selectPolicy: Min                  # Use more conservative policy
    scaleDown:
      stabilizationWindowSeconds: 300    # Wait 5 min before scaling down
      policies:
      - type: Percent  
        value: 25                        # Remove max 25% at once
        periodSeconds: 60
```

### Predictive Scaling Hints
```yaml
# For applications with known traffic patterns
metadata:
  annotations:
    # Hint: expect high traffic during business hours
    autoscaling.alpha.kubernetes.io/conditions: '[{"type":"ScalingEnabled","status":"True","lastTransitionTime":"2023-01-01T09:00:00Z"}]'
```

## Common HPA Issues and Solutions

### Issue: HPA Shows "Unknown" Metrics
```bash
# Check metrics server
kubectl get deployment metrics-server -n kube-system
kubectl logs deployment/metrics-server -n kube-system

# Fix: Install or restart metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### Issue: HPA Not Scaling Despite High CPU
```bash
# Check resource requests are set
kubectl describe deployment web-app | grep -A 10 "Requests"

# Check actual pod metrics
kubectl top pods -l app=web-app

# Fix: Ensure resource requests are defined
# HPA cannot calculate percentages without requests
```

### Issue: Scaling Too Aggressively
```yaml
# Solution: Adjust behavior settings
spec:
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 300   # Longer stabilization window
      policies:
      - type: Percent
        value: 50                       # Smaller scaling increments
        periodSeconds: 120
```

### Issue: Pods Not Ready During Scale Up
```yaml
# Solution: Improve readiness probes
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 5      # Faster health checks
  periodSeconds: 2
  timeoutSeconds: 1
  successThreshold: 1
  failureThreshold: 3
```

## When to Use HPA

### ✅ Perfect for HPA
- **Web applications** with variable traffic
- **API services** with request spikes  
- **Stateless microservices**
- **Queue processors** with variable workload
- **Seasonal applications** (e-commerce, gaming)

### ❌ Not suitable for HPA
- **Databases** (stateful, complex scaling)
- **Single-instance apps** (singletons)
- **Long startup time** apps (>2 minutes)
- **Persistent connections** (WebSocket servers)
- **Shared state** applications

## Real-World Scenarios

### E-commerce During Sale Events
```yaml
# Prepare for traffic spikes
spec:
  minReplicas: 10           # Higher baseline during sales
  maxReplicas: 100          # Allow massive scaling
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50  # More aggressive scaling
```

### API Gateway with Variable Load  
```yaml
# Balance cost and performance
spec:
  minReplicas: 3            # Always available
  maxReplicas: 25           # Reasonable cost ceiling
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 65
  - type: Pods
    pods:
      metric:
        name: requests_per_second
      target:
        type: AverageValue
        averageValue: "150"   # Scale based on actual load
```

## Key Insights

**HPA is reactive, not predictive** - it responds to current metrics, not future traffic

**Resource requests are mandatory** - HPA calculates percentages based on requests, not actual usage

**Start conservative, then optimize** - begin with higher targets and longer stabilization windows

**Health checks are critical** - new pods must be ready before receiving traffic

**Monitor and adjust** - initial HPA settings are rarely perfect for production workloads

**Combine with cluster autoscaling** - HPA scales pods, cluster autoscaler scales nodes

**Test your scaling behavior** - use load testing to validate HPA configuration before production

The goal is **automatic performance** without **runaway costs** - HPA provides the foundation for elastic applications that adapt to real user demand.