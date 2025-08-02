# Autoscaling: Handle Dynamic Resource Demands

## WHY Does Autoscaling Exist?

**Problem**: Applications have unpredictable resource needs - traffic spikes, varying workloads, unknown resource requirements  
**Solution**: Automatically adjust resources based on real-time metrics and usage patterns

## The Core Questions

**"How do I handle unpredictable demand without manual intervention?"**  
**"Should I add more containers or make existing containers bigger?"**

## Two Dimensions of Autoscaling

Kubernetes provides two complementary approaches to automatic scaling:

### Horizontal Scaling (HPA) - Scale OUT
- **What**: Add/remove pod replicas
- **When**: Variable traffic, stateless applications
- **Benefit**: Handle traffic spikes with more instances
- **Use Case**: Web apps, APIs, microservices

### Vertical Scaling (VPA) - Scale UP  
- **What**: Adjust CPU/memory requests per container
- **When**: Unknown resource requirements, single-instance apps
- **Benefit**: Right-size containers for optimal cost/performance
- **Use Case**: Databases, caches, batch jobs

## The Scaling Decision Matrix

```
Traffic Pattern    | Container Sizing | Recommended Approach
-------------------|------------------|--------------------
Variable traffic   | Known resources  | HPA only
Variable traffic   | Unknown resources| HPA + Resource Quotas
Steady traffic     | Unknown resources| VPA only  
Variable traffic   | Unknown resources| HPA + VPA (advanced)
Predictable traffic| Known resources  | Manual scaling
```

## Directory Structure

```
autoscaling/
├── hpa/              # Horizontal Pod Autoscaler (Scale OUT)
│   ├── README.md     # Complete HPA guide
│   ├── 01-basic-hpa.yaml
│   ├── 02-multi-metric-hpa.yaml
│   ├── 03-advanced-behavior.yaml
│   └── SIMPLE-HPA.yaml
├── vpa/              # Vertical Pod Autoscaler (Scale UP)
│   ├── README.md     # Complete VPA guide
│   ├── 01-basic-vpa.yaml
│   ├── 02-recommendation-only.yaml
│   └── SIMPLE-VPA.yaml
├── SIMPLE-AUTOSCALING.yaml  # Quick start with both concepts
└── README.md         # This overview file
```

## Production Trade-Off Analysis: Business Impact Decisions

### **Critical Thinking: HPA vs VPA vs Manual Scaling**

**Question**: "What would happen if we used the wrong scaling approach?"

| Scaling Method | Cost Impact | Performance | Risk Level | When It Fails |
|----------------|-------------|-------------|------------|---------------|
| **HPA** | Higher (more pods) | Excellent resilience | Low | During cluster resource exhaustion |
| **VPA** | Lower (right-sized) | Single point of failure | Medium | During pod restart (brief downtime) |
| **Manual** | Lowest upfront | Fails during spikes | High | Traffic exceeds capacity |

### **Real-World Business Scenarios**

#### **Scenario 1: E-commerce Black Friday (HPA)**
**Business Context**: 10x normal traffic, $50K/hour revenue  
**Decision**: Use HPA for frontend, manual scaling for database  
**Why**: Frontend can handle multiple replicas, database needs careful scaling  
**Trade-off**: Higher infrastructure cost vs guaranteed revenue capture

#### **Scenario 2: Financial Risk Calculation (VPA)**  
**Business Context**: Single ML model, CPU usage varies 100-800%, compliance requirements  
**Decision**: Use VPA with careful monitoring  
**Why**: Cannot run multiple instances (consistency), unpredictable resource needs  
**Trade-off**: Risk of brief downtime vs cost optimization

#### **Scenario 3: Startup MVP (Manual)**
**Business Context**: <1000 users, tight budget, simple app  
**Decision**: Start with manual scaling, add HPA at 10K users  
**Why**: Predictable load, cost control critical  
**Trade-off**: Risk of outages vs operational simplicity

## Quick Start: When To Use What?

### **Evolution Context: How We Got Here**
- **2000s**: Manual scaling with load balancers
- **2010s**: Auto Scaling Groups (AWS), still infrastructure-focused  
- **2015+**: Kubernetes HPA - Application-aware scaling
- **2018+**: VPA - Right-sizing automation
- **Now**: Multi-dimensional autoscaling with custom metrics

### Use HPA When:
✅ **Web applications** with traffic that varies throughout the day  
✅ **Stateless microservices** that can run multiple instances  
✅ **APIs** that experience request spikes  
✅ **E-commerce sites** with seasonal traffic patterns  
✅ **Applications** that start quickly (<30 seconds)
❗ **Critical**: Requires proper resource requests and readiness probes

```bash
# Production-ready HPA setup
kubectl apply -f hpa/SIMPLE-HPA.yaml
kubectl get hpa --watch
# Monitor for oscillation and tune thresholds
```

### Use VPA When:
✅ **Single-replica applications** (databases, caches)  
✅ **Unknown resource requirements** (new applications)  
✅ **Batch jobs** with varying resource needs  
✅ **Development environments** (cost optimization)  
✅ **Applications** where you're guessing resource allocation
❗ **Warning**: VPA restarts pods - plan for brief downtime

```bash
# VPA setup (requires cluster installation)
kubectl apply -f vpa/SIMPLE-VPA.yaml
kubectl describe vpa simple-vpa
# Review recommendations before enabling updateMode: "Auto"
```

### **Critical Questions to Ask Before Implementing**
1. **Can your application handle multiple replicas?** (State management?)
2. **How fast does your application start?** (Pod startup time affects HPA effectiveness)  
3. **What's the cost of brief downtime?** (VPA restarts pods)
4. **Do you understand your resource patterns?** (Monitoring first, then automate)
5. **What happens when scaling fails?** (Circuit breakers? Degraded mode?)

## The Scaling Workflow

### HPA Workflow (Horizontal)
```
1. HPA monitors CPU/memory metrics every 15 seconds
2. Compares current vs target utilization (e.g., 70% CPU)
3. Calculates desired replica count: current × (actual/target)
4. Updates Deployment replica count
5. Kubernetes schedules/removes pods
6. Load balancer distributes traffic across pods
```

### VPA Workflow (Vertical)
```
1. VPA observes resource usage for 24-48 hours
2. Builds statistical model of resource patterns
3. Provides three recommendations: lowerBound, target, upperBound
4. Updates pod resource requests/limits (requires pod restart)
5. Kubernetes reschedules pods with new resource allocation
```

## Key Concepts Comparison

| Aspect | HPA (Horizontal) | VPA (Vertical) |
|--------|------------------|----------------|
| **Changes** | Number of pods | Container resources |
| **Speed** | Fast (seconds) | Slow (24+ hours to learn) |
| **Disruption** | None (new pods) | Pod restarts required |
| **Cost Model** | Pay per pod | Pay per resource allocation |
| **Use Case** | Variable traffic | Resource optimization |
| **Metrics** | CPU, memory, custom | CPU, memory usage patterns |
| **Complexity** | Simple | Complex (learning phase) |

## Production Patterns

### Pattern 1: Web Application (HPA Only)
```yaml
# Most common pattern - horizontal scaling for web traffic
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: webapp-hpa
spec:
  scaleTargetRef:
    kind: Deployment
    name: webapp
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Pattern 2: Database (VPA Only)
```yaml
# Single-instance application - vertical scaling for resource optimization
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: database-vpa
spec:
  targetRef:
    kind: StatefulSet
    name: postgres
  updatePolicy:
    updateMode: "Initial"  # Only new pods (safer for databases)
  resourcePolicy:
    containerPolicies:
    - containerName: postgres
      controlledResources: ["memory"]
      maxAllowed:
        memory: 16Gi
```

### Pattern 3: Advanced Combination (HPA + VPA)
```yaml
# Advanced: HPA scales pods, VPA optimizes container sizes
# HPA controls CPU scaling
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: advanced-hpa
spec:
  scaleTargetRef:
    kind: Deployment
    name: api-service
  minReplicas: 2
  maxReplicas: 15
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70

---
# VPA controls memory optimization only
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: advanced-vpa
spec:
  targetRef:
    kind: Deployment
    name: api-service
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: api
      controlledResources: ["memory"]  # Only memory, not CPU
      maxAllowed:
        memory: 4Gi
```

## Prerequisites and Setup

### For HPA (Horizontal Pod Autoscaler)
```bash
# 1. Metrics server (usually pre-installed)
kubectl top nodes
kubectl top pods

# 2. Resource requests in your deployments (mandatory)
# containers must have resources.requests defined

# 3. Deploy HPA examples
kubectl apply -f hpa/
```

### For VPA (Vertical Pod Autoscaler)  
```bash
# 1. Install VPA (not included by default)
kubectl get crd verticalpodautoscalers.autoscaling.k8s.io

# If missing, install VPA:
# git clone https://github.com/kubernetes/autoscaler.git
# cd autoscaler/vertical-pod-autoscaler/
# ./hack/vpa-install.sh

# 2. Deploy VPA examples
kubectl apply -f vpa/
```

## Monitoring and Commands

### Check Autoscaling Status
```bash
# List all autoscalers
kubectl get hpa,vpa

# Watch HPA scaling in real-time
kubectl get hpa --watch

# Check VPA recommendations
kubectl describe vpa <vpa-name>
kubectl get vpa <vpa-name> -o yaml | grep -A 10 recommendation
```

### Resource Usage Monitoring
```bash
# Current pod resource usage
kubectl top pods

# Node resource usage
kubectl top nodes

# Detailed resource allocation
kubectl describe node <node-name>
```

### Load Testing
```bash
# Generate CPU load for HPA testing
kubectl run load-generator --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://my-service; done"

# Clean up load test
kubectl delete pod load-generator
```

## Best Practices

### 1. Start Simple
- **Begin with HPA** for most web applications
- **Use VPA in "Off" mode** first (recommendations only)
- **Test in staging** before production

### 2. Resource Specifications
```yaml
# Always define resource requests (mandatory for HPA)
resources:
  requests:
    cpu: 200m      # HPA uses this for percentage calculations
    memory: 256Mi  # VPA uses this as starting point
  limits:
    cpu: 1         # Prevent resource monopolization
    memory: 1Gi    # Prevent memory leaks
```

### 3. Scaling Boundaries
```yaml
# Set reasonable min/max values
spec:
  minReplicas: 2    # High availability
  maxReplicas: 20   # Cost control
  # VPA boundaries
  maxAllowed:
    cpu: 4          # Based on node capacity
    memory: 8Gi     # Based on workload needs
```

### 4. Health Checks
```yaml
# Critical for HPA - new pods must be ready before traffic
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
```

## Common Pitfalls

### ❌ Missing Resource Requests
```yaml
# This won't work with HPA
containers:
- name: app
  image: myapp:v1
  # No resources defined - HPA cannot calculate percentages
```

### ❌ Using Both HPA and VPA on Same Resource
```yaml
# Dangerous - can cause conflicts
# HPA scaling CPU + VPA scaling CPU = unstable behavior
# Solution: HPA for CPU, VPA for memory only
```

### ❌ VPA in Auto Mode for Critical Services
```yaml
# Risky - VPA restarts pods to apply new resources
updatePolicy:
  updateMode: "Auto"  # Can cause service disruption
# Solution: Use "Initial" mode for critical services
```

## Troubleshooting

### HPA Issues
```bash
# HPA shows "unknown" metrics
kubectl describe hpa <hpa-name>
# Check: metrics server installed, resource requests defined

# HPA not scaling
kubectl get events --field-selector involvedObject.name=<hpa-name>
# Check: actual resource usage, target thresholds
```

### VPA Issues
```bash
# VPA not providing recommendations
kubectl describe vpa <vpa-name>
# Wait: 24-48 hours for learning phase
# Check: VPA components running in kube-system

# VPA recommendations seem wrong
kubectl top pods -l app=<app-name>
# Verify: actual usage patterns, resource policies
```

## Next Steps

1. **Start with HPA** for web applications:
   ```bash
   cd hpa/
   kubectl apply -f SIMPLE-HPA.yaml
   ```

2. **Explore VPA** for resource optimization:
   ```bash
   cd vpa/
   kubectl apply -f SIMPLE-VPA.yaml
   ```

3. **Read detailed guides**:
   - [HPA Guide](hpa/README.md) - Complete horizontal scaling guide
   - [VPA Guide](vpa/README.md) - Complete vertical scaling guide

4. **Monitor and optimize**:
   - Track resource usage and costs
   - Adjust scaling parameters based on real workload patterns
   - Combine with proper resource quotas and limits

## Key Insights

**Autoscaling is about matching resources to demand** - automatically and efficiently

**Different applications need different scaling strategies** - understand your workload patterns

**Start conservative and optimize** - aggressive scaling can be expensive or disruptive

**Monitor the results** - autoscaling configurations need tuning based on real usage

**Combine with other Kubernetes features** - resource quotas, health checks, and proper monitoring create a complete solution

The goal is **automatic efficiency** - applications that scale up for performance and scale down for cost optimization, without manual intervention.