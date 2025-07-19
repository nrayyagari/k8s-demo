# Health Probes: Keep Your Apps Alive

## WHY Do Health Probes Exist?

**Problem**: App crashes, Kubernetes doesn't know, users get errors  
**Solution**: Tell Kubernetes when your app is broken

## The Core Question

**"How does Kubernetes know if my app is working?"**

Without probes: Kubernetes only knows if the container process is running  
With probes: Kubernetes knows if your app can actually serve users

## Two Essential Probes

### 1. Readiness Probe
**Question**: "Can my app handle traffic right now?"  
**Action**: Remove from service if fails  
**Use**: Always use this

### 2. Liveness Probe  
**Question**: "Is my app completely stuck?"  
**Action**: Restart container if fails  
**Use**: Only when restart actually fixes problems

## When Apps Need Different Startup Time

### 3. Startup Probe
**Question**: "Give me more time to start, then use normal rules"  
**Action**: Replaces liveness probe during startup only  
**Use**: Slow-starting apps (databases, Java apps)

## Simple Pattern

```yaml
containers:
- name: my-app
  # READINESS: Remove from traffic when broken
  readinessProbe:
    httpGet:
      path: /health
      port: 8080
    periodSeconds: 5
    
  # LIVENESS: Restart when completely stuck  
  livenessProbe:
    httpGet:
      path: /health
      port: 8080
    periodSeconds: 30
    initialDelaySeconds: 60
```

## What Happens When Probes Fail

**Readiness fails** → Pod removed from service → No traffic → Might recover  
**Liveness fails** → Container restarted → Fresh start → New container, same pod

## Files in This Directory

1. **SIMPLE-GUIDE.yaml** - Start here, covers 90% of use cases
2. **01-startup-probe-demo.yaml** - For slow-starting apps  
3. **02-probe-failure-scenarios.yaml** - What happens when probes fail
4. **03-detailed-probe-config.yaml** - Advanced configuration examples
5. **04-liveness-failure-demo.yaml** - See container restarts in action

## Quick Start

```bash
# Basic health checks
kubectl apply -f SIMPLE-GUIDE.yaml

# Watch pod behavior
kubectl get pods -w
kubectl describe pod <pod-name>
```

## Key Insight

**Different problems need different solutions**:
- Traffic problems → Readiness probe
- App hanging problems → Liveness probe  
- Slow startup problems → Startup probe

Start simple, add complexity only when needed.