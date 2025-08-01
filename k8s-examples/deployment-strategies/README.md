# Kubernetes Deployment Strategies

This section provides comprehensive examples and guidance for implementing different deployment strategies in Kubernetes. Learn how to deploy applications with zero downtime, manage risk, and optimize user experience through various deployment patterns.

## Why Deployment Strategies Matter

**Traditional Deployment Problems:**
- **Downtime**: Service interruptions during updates
- **Risk**: All users affected by buggy releases simultaneously  
- **No Rollback**: Difficult to revert problematic deployments
- **Poor User Experience**: Inconsistent application behavior

**Modern Deployment Solutions:**
- **Zero Downtime**: Keep services available during updates
- **Risk Mitigation**: Gradual rollouts with limited user exposure
- **Quick Recovery**: Instant rollback capabilities
- **Data-Driven Decisions**: Use real metrics to guide deployments

## Deployment Strategy Overview

### 1. Rolling Updates
**What**: Gradually replace old pods with new ones while maintaining service availability.

**When to Use:**
- ✅ Default strategy for most applications
- ✅ When you can tolerate mixed versions temporarily
- ✅ Stateless applications with good health checks
- ✅ When cluster resources are limited

**Benefits:**
- Zero downtime deployments
- Built into Kubernetes by default
- Resource efficient
- Gradual migration reduces risk

**Trade-offs:**
- Mixed versions during rollout
- Slower than instant switches
- Requires good health checks

### 2. Blue-Green Deployments
**What**: Run two identical environments, switch traffic instantly between them.

**When to Use:**
- ✅ Critical applications requiring instant rollback
- ✅ When you can't tolerate mixed versions
- ✅ Applications with complex startup procedures
- ✅ When you have sufficient infrastructure capacity

**Benefits:**
- Instant rollback capability
- No mixed versions
- Complete environment testing
- Clean separation

**Trade-offs:**
- Requires 2x infrastructure
- More complex orchestration
- Database migration challenges
- Higher costs

### 3. Canary Deployments
**What**: Release new version to small subset of users, gradually increase exposure.

**When to Use:**
- ✅ Testing new features with real users
- ✅ When user impact metrics are critical
- ✅ Applications with large user bases
- ✅ Risk-averse environments

**Benefits:**
- Limited blast radius
- Real user feedback
- Gradual risk increase
- Data-driven decisions

**Trade-offs:**
- More complex setup
- Requires good monitoring
- Longer rollout times
- User assignment complexity

### 4. A/B Testing
**What**: Compare different versions to measure impact on user behavior and business metrics.

**When to Use:**
- ✅ Testing UI/UX changes
- ✅ Optimizing conversion rates
- ✅ Validating new features
- ✅ Making data-driven product decisions

**Benefits:**
- Statistical validation
- Business metric optimization
- User behavior insights
- Risk mitigation

**Trade-offs:**
- Requires significant traffic
- Complex statistical analysis
- Longer decision cycles
- User segmentation complexity

### 5. Feature Flags
**What**: Control feature availability at runtime without code deployment.

**When to Use:**
- ✅ Decoupling deployment from release
- ✅ Gradual feature rollouts
- ✅ A/B testing and experimentation
- ✅ Kill switches for problematic features

**Benefits:**
- Deploy without releasing
- Instant feature toggling
- User segment targeting
- Risk mitigation

**Trade-offs:**
- Code complexity increase
- Technical debt accumulation
- Additional infrastructure
- Flag lifecycle management

## Strategy Comparison Matrix

| Strategy | Complexity | Rollback Speed | Resource Cost | Risk Level | Use Case |
|----------|------------|----------------|---------------|------------|----------|
| Rolling Updates | Low | Medium | Low | Medium | Default for most apps |
| Blue-Green | Medium | Instant | High | Low | Critical applications |
| Canary | High | Fast | Medium | Very Low | Risk-averse rollouts |
| A/B Testing | Very High | Medium | Medium | Low | Product optimization |
| Feature Flags | Medium | Instant | Low | Very Low | Feature control |

## Getting Started

### Quick Start (5 minutes)
1. **Rolling Updates**: Start with `rolling-updates/01-basic-rolling-update.yaml`
2. **Deploy**: `kubectl apply -f rolling-updates/01-basic-rolling-update.yaml`
3. **Test Update**: `kubectl set image deployment/webapp-rolling webapp=nginx:1.27-alpine`
4. **Monitor**: `kubectl rollout status deployment/webapp-rolling`

### Progressive Learning Path

**Beginner (Week 1)**
1. Master rolling updates with the basic example
2. Practice rollback scenarios: `kubectl rollout undo deployment/webapp`
3. Understand health checks and their importance
4. Experiment with different rollout parameters

**Intermediate (Week 2-3)**
1. Implement blue-green deployments manually
2. Set up canary deployments with percentage-based traffic splitting
3. Create basic feature flags with ConfigMaps
4. Practice emergency rollback procedures

**Advanced (Week 4+)**
1. Integrate with service mesh (Istio) for advanced traffic control
2. Implement automated canary analysis with Flagger or Argo Rollouts
3. Set up A/B testing with statistical analysis
4. Use LaunchDarkly or similar for enterprise feature flags

## Directory Structure

```
deployment-strategies/
├── README.md                    # This overview document
├── SIMPLE-DEPLOYMENT-STRATEGIES.yaml  # Quick reference guide
│
├── rolling-updates/             # Zero-downtime updates
│   ├── README.md
│   ├── 01-basic-rolling-update.yaml
│   └── 02-advanced-rolling-update.yaml
│
├── blue-green/                  # Instant traffic switching
│   ├── README.md
│   ├── 01-basic-blue-green.yaml
│   └── 02-automated-blue-green.yaml
│
├── canary/                      # Gradual rollouts
│   ├── README.md
│   ├── 01-basic-canary.yaml
│   └── 02-advanced-canary-istio.yaml
│
├── ab-testing/                  # User behavior experiments
│   ├── README.md
│   ├── 01-basic-ab-testing.yaml
│   └── 02-advanced-ab-testing-istio.yaml
│
└── feature-flags/               # Runtime feature control
    ├── README.md
    ├── 01-basic-feature-flags.yaml
    └── 02-advanced-feature-flags-launchdarkly.yaml
```

## Strategy Selection Guide

### Decision Tree

**For New Applications:**
```
Are you deploying for the first time?
├─ Yes → Use Rolling Updates (simplest, proven)
└─ No → Continue below

Do you need instant rollback capability?
├─ Yes → Use Blue-Green Deployment
└─ No → Continue below

Is this a high-risk change?
├─ Yes → Use Canary Deployment
└─ No → Continue below

Do you need to measure user behavior impact?
├─ Yes → Use A/B Testing
└─ No → Use Rolling Updates with Feature Flags
```

**For Existing Applications:**
```
What's your primary concern?

Minimize Risk:
└─ Canary Deployment → Monitor metrics → Promote/Rollback

Maximize Speed:
└─ Blue-Green → Test in green → Instant switch

Optimize Business Metrics:
└─ A/B Testing → Statistical analysis → Data-driven decision

Control Feature Rollouts:
└─ Feature Flags → Gradual enablement → Monitor impact
```

## Production Deployment Checklist

### Pre-Deployment
- [ ] **Health Checks**: Proper readiness and liveness probes configured
- [ ] **Resource Limits**: CPU and memory requests/limits set appropriately
- [ ] **Monitoring**: Metrics collection and alerting configured
- [ ] **Backup Plan**: Rollback procedures documented and tested
- [ ] **Testing**: Changes tested in staging environment
- [ ] **Communication**: Stakeholders notified of deployment window

### During Deployment
- [ ] **Monitor Metrics**: Watch error rates, latency, and business metrics
- [ ] **Check Health**: Verify new pods pass health checks
- [ ] **Validate Functionality**: Test critical user journeys
- [ ] **Resource Usage**: Monitor CPU and memory consumption
- [ ] **Traffic Distribution**: Verify traffic routing as expected
- [ ] **Error Monitoring**: Watch for increased error rates or exceptions

### Post-Deployment
- [ ] **Stability Period**: Monitor for 24-48 hours after completion
- [ ] **Business Metrics**: Verify no negative impact on KPIs
- [ ] **Performance Review**: Compare response times and throughput
- [ ] **User Feedback**: Monitor support tickets and user reports
- [ ] **Cleanup**: Remove old resources after successful deployment
- [ ] **Documentation**: Update runbooks and deployment notes

## Integration with CI/CD

### GitLab CI Example
```yaml
stages:
  - build
  - test
  - deploy-canary
  - validate
  - promote

deploy_canary:
  stage: deploy-canary
  script:
    - kubectl apply -f k8s/canary-deployment.yaml
    - kubectl set image deployment/webapp-canary webapp=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  environment:
    name: production-canary
    url: https://canary.myapp.com

validate_canary:
  stage: validate
  script:
    - python scripts/validate_metrics.py --deployment=canary --duration=30m
    - python scripts/run_smoke_tests.py --target=canary
  artifacts:
    reports:
      junit: canary-validation-results.xml

promote_canary:
  stage: promote
  when: manual
  script:
    - python scripts/promote_canary.py
    - kubectl patch service webapp-service -p '{"spec":{"selector":{"version":"canary"}}}'
```

### GitHub Actions Example
```yaml
name: Canary Deployment

on:
  push:
    branches: [main]

jobs:
  deploy-canary:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Deploy to Canary
      run: |
        kubectl apply -f k8s/canary/
        kubectl set image deployment/webapp-canary webapp=${{ github.sha }}
        kubectl rollout status deployment/webapp-canary --timeout=300s
    
    - name: Run Canary Tests
      run: |
        ./scripts/test-canary.sh
        ./scripts/monitor-metrics.sh --duration=1800  # 30 minutes
    
    - name: Promote or Rollback
      run: |
        if ./scripts/evaluate-canary.sh; then
          ./scripts/promote-canary.sh
        else
          ./scripts/rollback-canary.sh
          exit 1
        fi
```

## Monitoring and Observability

### Key Metrics to Track

**Technical Metrics:**
- **Error Rate**: 5xx errors per second by deployment version
- **Latency**: p50, p95, p99 response times by version
- **Throughput**: Requests per second by version
- **Availability**: Uptime percentage by version
- **Resource Usage**: CPU and memory utilization by version

**Business Metrics:**
- **Conversion Rate**: Percentage of users completing desired actions
- **User Engagement**: Time on site, page views, feature usage
- **Revenue Impact**: Revenue per user, transaction value
- **Customer Satisfaction**: Support ticket volume, user feedback scores

### Prometheus Queries

**Error Rate Comparison:**
```promql
# Compare error rates between versions
sum(rate(http_requests_total{status=~"5.*",version="stable"}[5m])) /
sum(rate(http_requests_total{version="stable"}[5m])) -
sum(rate(http_requests_total{status=~"5.*",version="canary"}[5m])) /
sum(rate(http_requests_total{version="canary"}[5m]))
```

**Latency Comparison:**
```promql
# Compare 95th percentile latency
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket{version="canary"}[5m])) by (le)
) -
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket{version="stable"}[5m])) by (le)
)
```

**Traffic Distribution:**
```promql
# Monitor traffic split between versions
sum(rate(http_requests_total[5m])) by (version) /
sum(rate(http_requests_total[5m])) * 100
```

## Advanced Topics

### Multi-Region Deployments
- Deploy canary to single region first
- Monitor regional metrics separately
- Use geographic routing for isolation
- Consider data locality and compliance

### Database Migration Strategies
- Backward-compatible schema changes
- Data migration in separate phases
- Read-only periods during critical migrations
- Rollback procedures for data changes

### Service Mesh Integration
- Istio VirtualServices for traffic splitting
- Envoy proxy metrics for detailed observability
- Circuit breakers and retry policies
- mTLS for secure service communication

### Cost Optimization
- Spot instances for non-production environments
- Resource right-sizing based on metrics
- Scheduled scaling for predictable traffic
- Multi-cloud strategies for cost comparison

## Troubleshooting Guide

### Common Issues

**Rolling Update Stuck:**
```bash
# Check deployment status
kubectl describe deployment webapp

# Check pod events
kubectl get events --sort-by='.lastTimestamp'

# Check resource constraints
kubectl top nodes
kubectl describe nodes
```

**Traffic Not Switching:**
```bash
# Verify service selectors
kubectl get service webapp-service -o yaml

# Check endpoints
kubectl get endpoints webapp-service

# Test traffic distribution
for i in {1..20}; do curl -s http://webapp-service | grep version; done
```

**Metrics Not Available:**
```bash
# Check ServiceMonitor
kubectl get servicemonitor

# Verify Prometheus targets
kubectl port-forward svc/prometheus 9090:9090
# Visit http://localhost:9090/targets
```

### Emergency Procedures

**Immediate Rollback:**
```bash
# Rolling update rollback
kubectl rollout undo deployment/webapp

# Blue-green traffic switch
kubectl patch service webapp-service -p '{"spec":{"selector":{"version":"blue"}}}'

# Canary removal
kubectl scale deployment webapp-canary --replicas=0

# Feature flag disable
kubectl patch configmap feature-flags -p '{"data":{"problematic_feature":"false"}}'
```

## Learning Resources

### Books
- "Continuous Delivery" by Jez Humble and David Farley
- "Site Reliability Engineering" by Google SRE Team
- "Building Microservices" by Sam Newman

### Online Resources
- [Kubernetes Official Documentation](https://kubernetes.io/docs/)
- [Argo Rollouts Documentation](https://argo-rollouts.readthedocs.io/)
- [Istio Traffic Management](https://istio.io/latest/docs/concepts/traffic-management/)
- [LaunchDarkly Feature Flag Guide](https://docs.launchdarkly.com/)

### Tools and Platforms
- **Argo Rollouts**: Advanced deployment strategies
- **Flagger**: Progressive delivery for Kubernetes
- **Istio**: Service mesh for traffic management
- **LaunchDarkly**: Feature flag management platform
- **Prometheus**: Monitoring and alerting
- **Grafana**: Visualization and dashboards

## Next Steps

1. **Start Simple**: Begin with rolling updates to understand the basics
2. **Add Monitoring**: Implement comprehensive metrics collection
3. **Practice Rollbacks**: Regularly test emergency procedures
4. **Gradual Complexity**: Move to blue-green, then canary deployments
5. **Automate**: Build CI/CD pipelines with automated deployment strategies
6. **Measure Impact**: Use A/B testing to optimize user experience
7. **Advanced Tools**: Integrate service mesh and enterprise feature flag platforms

## Contributing

Found an issue or have an improvement? Please:
1. Check existing issues and discussions
2. Create detailed bug reports or feature requests
3. Submit pull requests with comprehensive examples
4. Share your production experiences and lessons learned

---

**Remember**: The best deployment strategy is the one that fits your specific requirements for risk tolerance, complexity, and business objectives. Start simple, measure everything, and evolve your approach based on real-world experience.