# Canary Deployments

Canary deployment is a technique that reduces the risk of introducing new software versions by slowly rolling out changes to a small subset of users before making it available to everyone.

## Why Use Canary Deployments?

**Problems Solved:**
- **Risk Mitigation**: Test new versions with real users while limiting exposure
- **Early Detection**: Catch issues before they affect all users
- **Gradual Rollout**: Controlled expansion based on confidence and metrics
- **Data-Driven Decisions**: Use real metrics to decide on promotion or rollback

**When to Use:**
- ✅ Applications with large user bases where issues impact many users
- ✅ When you need to validate new features with real traffic
- ✅ Applications with complex integration points
- ✅ When you have good monitoring and can measure success metrics

## Core Concepts

### Traffic Splitting Approaches

**1. Pod-Based Splitting (Simple)**
```yaml
# 90% stable pods, 10% canary pods
stable-deployment: replicas: 9
canary-deployment: replicas: 1
# Service routes to both deployments
```

**2. Service Mesh-Based (Advanced)**
```yaml
# Istio VirtualService with percentage-based routing
http:
- route:
  - destination:
      subset: stable
    weight: 90
  - destination:
      subset: canary
    weight: 10
```

### Canary Progression Strategy

**Conservative Approach:**
- 5% → 10% → 25% → 50% → 100%
- Monitor 24-48 hours between steps
- Rollback at first sign of issues

**Aggressive Approach:**
- 10% → 50% → 100%
- Monitor 2-6 hours between steps
- Suitable for low-risk changes

## Deployment Process

### Phase 1: Initial State (100% Stable)
```
┌─────────────────────────────────────────────────────────────┐
│                    STABLE (v1.0)                           │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐  │
│  │Pod│ │Pod│ │Pod│ │Pod│ │Pod│ │Pod│ │Pod│ │Pod│ │Pod│  │
│  └───┘ └───┘ └───┘ └───┘ └───┘ └───┘ └───┘ └───┘ └───┘  │
└─────────────────────────────────────────────────────────────┘
                             ▲
                        100% Traffic
```

### Phase 2: Canary Introduction (90% / 10%)
```
┌─────────────────────────────────────────────────────┐ ┌─────┐
│                STABLE (v1.0)                       │ │CANARY│
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐  │ │ ┌───┐│
│  │Pod│ │Pod│ │Pod│ │Pod│ │Pod│ │Pod│ │Pod│ │Pod│  │ │ │Pod││
│  └───┘ └───┘ └───┘ └───┘ └───┘ └───┘ └───┘ └───┘  │ │ └───┘│
└─────────────────────────────────────────────────────┘ └─────┘
                             ▲                            ▲
                        90% Traffic                  10% Traffic
```

### Phase 3: Progressive Expansion
```
# 25% Canary
┌─────────────────────────────────────────────┐ ┌─────────────┐
│            STABLE (v1.0)                   │ │   CANARY    │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ │ │ ┌───┐ ┌───┐ │
│  │Pod│ │Pod│ │Pod│ │Pod│ │Pod│ │Pod│ │Pod│ │ │ │Pod│ │Pod│ │
│  └───┘ └───┘ └───┘ └───┘ └───┘ └───┘ └───┘ │ │ └───┘ └───┘ │
└─────────────────────────────────────────────┘ └─────────────┘
                             ▲                        ▲
                        75% Traffic              25% Traffic
```

## Implementation Approaches

### 1. Basic Pod-Based Canary

**Deployment Configuration:**
```yaml
# Stable deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-stable
spec:
  replicas: 9  # 90% of traffic
  selector:
    matchLabels:
      app: webapp
      version: stable

# Canary deployment  
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-canary
spec:
  replicas: 1  # 10% of traffic
  selector:
    matchLabels:
      app: webapp
      version: canary

# Service routes to both
apiVersion: v1
kind: Service
spec:
  selector:
    app: webapp  # Selects both stable and canary
```

**Progression Commands:**
```bash
# Start with 10% canary
kubectl scale deployment webapp-stable --replicas=9
kubectl scale deployment webapp-canary --replicas=1

# Increase to 25% canary
kubectl scale deployment webapp-stable --replicas=7
kubectl scale deployment webapp-canary --replicas=3

# Increase to 50% canary
kubectl scale deployment webapp-stable --replicas=5
kubectl scale deployment webapp-canary --replicas=5

# Complete rollout (100% canary)
kubectl scale deployment webapp-stable --replicas=0
kubectl scale deployment webapp-canary --replicas=10
```

### 2. Istio Service Mesh Canary

**Traffic Splitting Configuration:**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: webapp-vs
spec:
  http:
  - route:
    - destination:
        host: webapp-service
        subset: stable
      weight: 90
    - destination:
        host: webapp-service
        subset: canary
      weight: 10
```

**Advanced Routing Rules:**
```yaml
# Header-based routing for testing
- match:
  - headers:
      x-canary-user:
        exact: "true"
  route:
  - destination:
      subset: canary
    weight: 100

# User-based routing
- match:
  - headers:
      user-id:
        regex: "user-[1-9]"  # Users 1-9 get canary
  route:
  - destination:
      subset: canary
    weight: 100
```

### 3. Automated Canary with Flagger

**Flagger Canary Resource:**
```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: webapp-canary
spec:
  analysis:
    interval: 1m
    threshold: 5
    maxWeight: 50
    stepWeight: 5
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
    - name: request-duration
      thresholdRange:
        max: 500
```

## Monitoring and Metrics

### Essential Metrics to Track

**Technical Metrics:**
```yaml
# Success Rate
sum(rate(http_requests_total{code!~"5.*"}[2m])) / 
sum(rate(http_requests_total[2m])) * 100

# Latency Percentiles
histogram_quantile(0.95, 
  sum(rate(http_request_duration_seconds_bucket[2m])) by (le, version)
)

# Error Rate
sum(rate(http_requests_total{code=~"5.*"}[2m])) by (version)

# Resource Usage
avg(container_memory_usage_bytes) by (version)
avg(rate(container_cpu_usage_seconds_total[2m])) by (version)
```

**Business Metrics:**
- Conversion rates by version
- User engagement metrics
- Revenue per user
- Feature adoption rates
- Customer satisfaction scores

### Monitoring Setup

**Prometheus Queries:**
```yaml
# Compare error rates between versions
(
  sum(rate(http_requests_total{version="canary",code=~"5.*"}[5m])) /
  sum(rate(http_requests_total{version="canary"}[5m]))
) - (
  sum(rate(http_requests_total{version="stable",code=~"5.*"}[5m])) /
  sum(rate(http_requests_total{version="stable"}[5m]))
)

# Compare response times
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket{version="canary"}[5m])) by (le)
) - 
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket{version="stable"}[5m])) by (le)
)
```

**Grafana Dashboard:**
```json
{
  "dashboard": {
    "title": "Canary Deployment Dashboard",
    "panels": [
      {
        "title": "Traffic Split",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{version=\"stable\"}[5m]))",
            "legendFormat": "Stable Traffic"
          },
          {
            "expr": "sum(rate(http_requests_total{version=\"canary\"}[5m]))",
            "legendFormat": "Canary Traffic"
          }
        ]
      }
    ]
  }
}
```

## Decision Criteria

### Promote Canary When:
- ✅ **Error Rate**: Canary error rate ≤ stable error rate
- ✅ **Latency**: Canary p95 latency ≤ 1.2x stable latency
- ✅ **Success Rate**: Canary success rate ≥ 99%
- ✅ **Resource Usage**: CPU/Memory within expected bounds
- ✅ **Business Metrics**: No negative impact on KPIs
- ✅ **Duration**: Metrics stable for defined observation period

### Rollback Canary When:
- ❌ **High Error Rate**: >2% error rate for >5 minutes
- ❌ **Latency Spike**: >2x latency increase for >2 minutes
- ❌ **5xx Errors**: Any 5xx errors >1% of requests
- ❌ **Memory Leaks**: Continuously increasing memory usage
- ❌ **Business Impact**: Revenue drop >5%
- ❌ **User Complaints**: Significant increase in support tickets

## Testing Strategies

### Load Testing
```bash
# Test stable version
kubectl run load-test-stable --image=fortio/fortio --restart=Never -- \
  load -qps 100 -t 60s -c 10 http://webapp-service/

# Test canary version specifically
kubectl run load-test-canary --image=fortio/fortio --restart=Never -- \
  load -qps 10 -t 60s -c 2 -H "x-canary-user:true" http://webapp-service/

# Monitor during load test
kubectl top pods -l app=webapp --sort-by=cpu
```

### Chaos Testing
```yaml
# Inject failures into canary pods
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
spec:
  http:
  - match:
    - headers:
        version:
          exact: canary
    fault:
      delay:
        percentage:
          value: 0.5
        fixedDelay: 5s
      abort:
        percentage:
          value: 0.1
        httpStatus: 500
```

### A/B Testing Integration
```yaml
# Route users based on experiment group
- match:
  - headers:
      x-experiment-group:
        exact: "treatment"
  route:
  - destination:
      subset: canary
    weight: 100
- match:
  - headers:
      x-experiment-group:
        exact: "control"
  route:
  - destination:
      subset: stable
    weight: 100
```

## Production Best Practices

### 1. Gradual Rollout Schedule
```yaml
# Conservative schedule for critical services
Week 1: 5% canary  (1 day monitoring)
Week 1: 10% canary (2 days monitoring)
Week 2: 25% canary (3 days monitoring)
Week 2: 50% canary (5 days monitoring)
Week 3: 100% canary (promote to stable)

# Aggressive schedule for low-risk changes
Day 1: 10% canary (4 hours monitoring)
Day 1: 50% canary (8 hours monitoring)
Day 2: 100% canary (promote to stable)
```

### 2. Automated Decision Making
```yaml
# Automated promotion rules
if (
  canary_error_rate < stable_error_rate AND
  canary_p95_latency < stable_p95_latency * 1.2 AND
  canary_uptime > 0.99 AND
  observation_time > minimum_observation_period
) {
  promote_canary()
}

# Automated rollback rules  
if (
  canary_error_rate > stable_error_rate * 2 OR
  canary_p95_latency > stable_p95_latency * 2 OR
  canary_5xx_rate > 0.01
) {
  rollback_canary()
}
```

### 3. Communication Strategy
```yaml
# Slack notifications
deployment_started:
  message: "🚀 Canary deployment started: webapp v2.0.0 (10% traffic)"
  
metrics_check:
  message: "📊 Canary metrics good: Error rate 0.1%, Latency p95 150ms"
  
promotion:
  message: "✅ Canary promoted: webapp v2.0.0 → 25% traffic"
  
rollback:
  message: "⚠️ Canary rolled back: Error rate exceeded threshold"
```

## Troubleshooting

### Traffic Not Splitting Correctly
```bash
# Check service endpoints
kubectl get endpoints webapp-service -o yaml

# Verify pod labels
kubectl get pods -l app=webapp --show-labels

# Test traffic distribution
for i in {1..20}; do 
  curl -s http://webapp-service | grep version
  sleep 1
done
```

### Monitoring Issues
```bash
# Check Prometheus targets
kubectl port-forward svc/prometheus 9090:9090
# Browse to http://localhost:9090/targets

# Verify metrics collection
kubectl exec -it prometheus-pod -- \
  promtool query instant 'up{job="webapp"}'
```

### Istio Configuration Problems
```bash
# Analyze Istio config
istioctl analyze

# Check proxy configuration
istioctl proxy-config route deployment/webapp-stable

# Debug traffic routing
istioctl proxy-config cluster deployment/webapp-stable
```

## Files in This Section

- **`01-basic-canary.yaml`**: Pod-based canary deployment with manual control
- **`02-advanced-canary-istio.yaml`**: Service mesh-based canary with Istio
- **`SIMPLE-CANARY.yaml`**: Quick-start template for immediate use

## Next Steps

1. **Basic Implementation**: Start with pod-based canary deployment
2. **Monitoring Setup**: Implement comprehensive metrics collection
3. **Service Mesh**: Upgrade to Istio for advanced traffic control
4. **Automation**: Implement automated promotion/rollback logic
5. **Integration**: Connect with CI/CD pipelines and monitoring systems