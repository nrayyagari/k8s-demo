# Rolling Updates

Rolling updates are Kubernetes' default deployment strategy for zero-downtime application updates. This strategy gradually replaces old pod instances with new ones while maintaining service availability.

## Why Use Rolling Updates?

**Problems Solved:**
- **Zero Downtime**: Service remains available during updates
- **Gradual Migration**: Pods are replaced incrementally, reducing risk  
- **Automatic Rollback**: Built-in rollback capabilities
- **Resource Efficiency**: Only creates necessary extra pods during update

**When to Use:**
- ✅ Stateless applications that can run multiple versions simultaneously
- ✅ Applications with proper health checks
- ✅ When you have sufficient cluster resources for temporary pod surge
- ✅ Applications that can handle gradual traffic migration

## Core Concepts

### Rolling Update Parameters

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 25%    # Max pods that can be unavailable
    maxSurge: 25%          # Max extra pods during update
```

**maxUnavailable**: Controls how many pods can be unavailable during the update
- Higher values = faster rollout, less availability
- Lower values = slower rollout, better availability
- Can be absolute number (2) or percentage (25%)

**maxSurge**: Controls how many extra pods can be created during the update
- Higher values = faster rollout, more resources needed
- Lower values = slower rollout, less resource usage
- Can be absolute number (2) or percentage (25%)

### Health Check Requirements

Rolling updates rely heavily on pod health checks:

```yaml
readinessProbe:        # Controls when pod receives traffic
  httpGet:
    path: /health/ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 2

livenessProbe:         # Detects and restarts failed pods
  httpGet:
    path: /health/live
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

startupProbe:          # For slow-starting applications
  httpGet:
    path: /health/startup
    port: 8080
  failureThreshold: 30
  periodSeconds: 5
```

## Rolling Update Process

### Phase-by-Phase Breakdown

**Initial State**: 6 pods running version 1
```
Pod-A (v1) ✓    Pod-B (v1) ✓    Pod-C (v1) ✓
Pod-D (v1) ✓    Pod-E (v1) ✓    Pod-F (v1) ✓
```

**Phase 1**: Create new pods (respecting maxSurge)
```
Pod-A (v1) ✓    Pod-B (v1) ✓    Pod-C (v1) ✓
Pod-D (v1) ✓    Pod-E (v1) ✓    Pod-F (v1) ✓
Pod-G (v2) ⏳   Pod-H (v2) ⏳   
```

**Phase 2**: Wait for new pods ready, terminate old pods (respecting maxUnavailable)  
```
Pod-A (v1) ❌   Pod-B (v1) ❌   Pod-C (v1) ✓
Pod-D (v1) ✓    Pod-E (v1) ✓    Pod-F (v1) ✓
Pod-G (v2) ✓    Pod-H (v2) ✓    
```

**Final State**: All pods running version 2
```
Pod-G (v2) ✓    Pod-H (v2) ✓    Pod-I (v2) ✓
Pod-J (v2) ✓    Pod-K (v2) ✓    Pod-L (v2) ✓
```

## Configuration Examples

### Conservative Rollout (Slow, Safe)
```yaml
rollingUpdate:
  maxUnavailable: 1        # Only 1 pod unavailable at a time
  maxSurge: 1              # Only 1 extra pod at a time
```
- **Use Case**: Critical production services, limited resources
- **Duration**: Longest rollout time
- **Risk**: Lowest risk of service disruption

### Balanced Rollout (Moderate Speed and Risk)
```yaml
rollingUpdate:
  maxUnavailable: 25%      # 25% of pods can be unavailable
  maxSurge: 25%            # 25% extra pods during update
```
- **Use Case**: Most production applications
- **Duration**: Moderate rollout time
- **Risk**: Balanced risk and speed

### Aggressive Rollout (Fast, Higher Risk)
```yaml
rollingUpdate:
  maxUnavailable: 50%      # Half the pods can be unavailable
  maxSurge: 50%            # Double pods during peak
```
- **Use Case**: Development environments, high-resource clusters
- **Duration**: Fastest rollout time
- **Risk**: Higher chance of service impact

## Production Best Practices

### 1. Health Check Strategy
```yaml
# Startup probe for slow applications
startupProbe:
  httpGet:
    path: /health/startup
    port: 8080
  failureThreshold: 30      # Allow 150s for startup
  periodSeconds: 5

# Readiness probe for traffic control
readinessProbe:
  httpGet:
    path: /health/ready
    port: 8080
  periodSeconds: 2          # Quick checks for responsiveness
  failureThreshold: 3

# Liveness probe for failure detection
livenessProbe:
  httpGet:
    path: /health/live  
    port: 8080
  periodSeconds: 10         # Less frequent checks
  failureThreshold: 3
```

### 2. Resource Management
```yaml
resources:
  requests:
    memory: "256Mi"         # Guaranteed resources
    cpu: "100m"
  limits:
    memory: "512Mi"         # Maximum allowed
    cpu: "500m"
```

### 3. Graceful Shutdown
```yaml
terminationGracePeriodSeconds: 60  # Allow time for cleanup

# In application:
# - Stop accepting new requests
# - Complete in-flight requests  
# - Close database connections
# - Clean up temporary files
```

### 4. Pod Disruption Budgets
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: webapp-pdb
spec:
  minAvailable: 75%         # Ensure 75% pods always available
  selector:
    matchLabels:
      app: webapp
```

## Monitoring and Troubleshooting

### Essential Commands

**Monitor Rollout Progress:**
```bash
# Watch rollout status
kubectl rollout status deployment/webapp --timeout=300s

# Watch pods during rollout
kubectl get pods -l app=webapp --watch

# Monitor events
kubectl get events --sort-by='.lastTimestamp'
```

**Rollout Control:**
```bash
# Pause rollout if issues detected
kubectl rollout pause deployment/webapp

# Resume paused rollout
kubectl rollout resume deployment/webapp

# Check rollout history
kubectl rollout history deployment/webapp
```

**Rollback Operations:**
```bash
# Rollback to previous version
kubectl rollout undo deployment/webapp

# Rollback to specific revision
kubectl rollout undo deployment/webapp --to-revision=2
```

### Common Issues and Solutions

**Issue**: Pods stuck in pending state
```bash
# Check resource constraints
kubectl describe pod <pod-name>
kubectl top nodes
```

**Issue**: New pods failing health checks
```bash
# Check application logs
kubectl logs <pod-name> --previous
kubectl describe pod <pod-name>
```

**Issue**: Rollout progress stalled
```bash
# Check deployment status
kubectl describe deployment <deployment-name>
kubectl get replicasets -l app=<app-name>
```

## Testing Rolling Updates

### Load Testing During Rollout
```bash
# Generate continuous load
kubectl run load-test --image=busybox --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://webapp-service; sleep 0.1; done"

# Monitor response times
kubectl run monitor --image=busybox --restart=Never -- \
  /bin/sh -c "while true; do time wget -q -O- http://webapp-service; sleep 1; done"
```

### Automated Testing
```yaml
# Use init containers for pre-deployment tests
initContainers:
- name: migration-check
  image: migrate/migrate
  command: ['migrate', '-path', '/migrations', '-database', 'postgres://...', 'up']

# Use post-deployment hooks
lifecycle:
  postStart:
    exec:
      command: ["/bin/sh", "-c", "curl -f http://localhost:8080/health"]
```

## Integration with CI/CD

### GitOps Workflow
```yaml
# In your CI/CD pipeline
steps:
- name: Update deployment
  run: |
    kubectl set image deployment/webapp webapp=myapp:${{ github.sha }}
    kubectl rollout status deployment/webapp --timeout=300s
    
- name: Run post-deployment tests
  run: |
    kubectl apply -f tests/smoke-tests.yaml
    kubectl wait --for=condition=complete job/smoke-test --timeout=120s
```

### Automated Rollback
```bash
# Check deployment health and rollback if needed
if ! kubectl rollout status deployment/webapp --timeout=300s; then
  echo "Rollout failed, initiating rollback"
  kubectl rollout undo deployment/webapp
  kubectl rollout status deployment/webapp --timeout=300s
fi
```

## Files in This Section

- **`01-basic-rolling-update.yaml`**: Simple rolling update example with detailed explanations
- **`02-advanced-rolling-update.yaml`**: Production-grade configuration with advanced features
- **`SIMPLE-ROLLING-UPDATES.yaml`**: Quick-start template for immediate use

## Next Steps

1. **Start with Basic**: Deploy `01-basic-rolling-update.yaml` to understand fundamentals
2. **Practice Rollbacks**: Intentionally deploy broken versions to practice recovery
3. **Monitor Metrics**: Set up monitoring to observe rollout behavior
4. **Tune Parameters**: Adjust `maxUnavailable` and `maxSurge` based on your needs
5. **Advanced Strategies**: Explore blue-green and canary deployments for more control