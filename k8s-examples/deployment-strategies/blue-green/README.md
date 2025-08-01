# Blue-Green Deployments

Blue-Green deployment is a technique where you run two identical production environments called "Blue" and "Green". At any time, only one environment is live, serving all production traffic, while the other is idle or used for final testing.

## Why Use Blue-Green Deployments?

**Problems Solved:**
- **Instant Rollback**: Switch back to previous version immediately if issues arise
- **Zero Downtime**: Complete environment switch with no service interruption
- **Risk Reduction**: Test complete environment before switching traffic
- **Clean Separation**: No mixed versions during deployment

**When to Use:**
- ✅ Critical applications requiring instant rollback capability
- ✅ Applications with complex startup procedures
- ✅ When you have sufficient infrastructure resources (2x capacity)
- ✅ Stateless applications or applications with externalized state

## Core Concepts

### Environment States

**Blue Environment (Current Production)**
```yaml
metadata:
  labels:
    version: blue
    environment: production
```

**Green Environment (New Version)**
```yaml
metadata:
  labels:
    version: green
    environment: staging
```

### Traffic Switching

The core of blue-green deployments is instant traffic switching through service selectors:

```yaml
# Production Service (switches between blue/green)
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  selector:
    app: webapp
    version: blue    # Switch this to 'green' for deployment
  ports:
  - port: 80
    targetPort: 80
```

## Deployment Process

### Phase 1: Initial State (Blue Active)
```
┌─────────────────┐    ┌─────────────────┐
│  BLUE (v1.0)    │    │  GREEN (empty)  │
│  ┌───┐ ┌───┐    │    │                 │
│  │Pod│ │Pod│    │    │                 │
│  └───┘ └───┘    │    │                 │
│     ACTIVE      │    │    INACTIVE     │
└─────────────────┘    └─────────────────┘
         ▲                       
     Production                  
      Traffic                    
```

### Phase 2: Deploy to Green
```
┌─────────────────┐    ┌─────────────────┐
│  BLUE (v1.0)    │    │  GREEN (v2.0)   │
│  ┌───┐ ┌───┐    │    │  ┌───┐ ┌───┐    │
│  │Pod│ │Pod│    │    │  │Pod│ │Pod│    │
│  └───┘ └───┘    │    │  └───┘ └───┘    │
│     ACTIVE      │    │   TESTING       │
└─────────────────┘    └─────────────────┘
         ▲                       ▲
     Production              Staging
      Traffic                Traffic
```

### Phase 3: Switch Traffic to Green
```
┌─────────────────┐    ┌─────────────────┐
│  BLUE (v1.0)    │    │  GREEN (v2.0)   │
│  ┌───┐ ┌───┐    │    │  ┌───┐ ┌───┐    │
│  │Pod│ │Pod│    │    │  │Pod│ │Pod│    │
│  └───┘ └───┘    │    │  └───┘ └───┘    │
│    STANDBY      │    │     ACTIVE      │
└─────────────────┘    └─────────────────┘
                                  ▲
                              Production
                               Traffic
```

## Implementation Strategies

### 1. Manual Blue-Green (Basic)

**Service Selector Update:**
```bash
# Deploy new version to green
kubectl apply -f green-deployment.yaml

# Test green environment
kubectl port-forward service/webapp-staging-service 8080:80

# Switch traffic to green
kubectl patch service webapp-service -p '{"spec":{"selector":{"version":"green"}}}'

# Rollback if needed
kubectl patch service webapp-service -p '{"spec":{"selector":{"version":"blue"}}}'
```

### 2. Automated Blue-Green (Advanced)

Using Argo Rollouts for sophisticated automation:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    blueGreen:
      activeService: webapp-active
      previewService: webapp-preview
      autoPromotionEnabled: false
      prePromotionAnalysis:
        templates:
        - templateName: success-rate-analysis
```

## Testing Strategies

### Pre-Switch Testing

**Smoke Tests:**
```bash
# Test green environment endpoints
curl http://green.myapp.local/health
curl http://green.myapp.local/api/status

# Run integration tests
kubectl apply -f smoke-tests-job.yaml
kubectl wait --for=condition=complete job/smoke-test --timeout=300s
```

**Load Testing:**
```bash
# Generate load against green environment
kubectl run load-test --image=busybox --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://webapp-staging-service; sleep 0.1; done"
```

### Post-Switch Monitoring

**Health Verification:**
```bash
# Monitor new version
kubectl get pods -l version=green --watch
kubectl logs -l version=green --tail=100

# Check service endpoints
kubectl get endpoints webapp-service
kubectl describe service webapp-service
```

## Database Considerations

### Schema Migration Strategy

**Backward Compatible Changes:**
```sql
-- Phase 1: Add new columns (nullable)
ALTER TABLE users ADD COLUMN email_verified BOOLEAN;
ALTER TABLE users ADD COLUMN created_by VARCHAR(255);

-- Phase 2: Populate new columns
UPDATE users SET email_verified = true WHERE email IS NOT NULL;
UPDATE users SET created_by = 'migration' WHERE created_by IS NULL;

-- Phase 3: Make constraints (after blue-green switch)
ALTER TABLE users ALTER COLUMN created_by SET NOT NULL;
```

**Data Migration Jobs:**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pre-switch-migration
spec:
  template:
    spec:
      containers:
      - name: migrator
        image: migrate/migrate
        command: ['migrate', '-path', '/migrations', '-database', 'postgres://...', 'up']
      restartPolicy: Never
```

## Production Patterns

### 1. Infrastructure as Code

**Terraform Example:**
```hcl
resource "kubernetes_deployment" "webapp_blue" {
  metadata {
    name = "webapp-blue"
    labels = {
      app = "webapp"
      version = "blue"
    }
  }
  spec {
    replicas = var.production_replicas
    # ... deployment spec
  }
}

resource "kubernetes_deployment" "webapp_green" {
  metadata {
    name = "webapp-green"
    labels = {
      app = "webapp"
      version = "green"
    }
  }
  spec {
    replicas = var.production_replicas
    # ... deployment spec
  }
}
```

### 2. Monitoring and Alerting

**Prometheus Metrics:**
```yaml
# Monitor both environments
- name: blue_green_deployment_status
  expr: |
    sum(up{job="webapp", version="blue"}) by (version) and
    sum(up{job="webapp", version="green"}) by (version)

# Alert on traffic switch
- alert: BlueGreenTrafficSwitch
  expr: changes(kube_service_spec_selector{service="webapp-service"}[5m]) > 0
  for: 0s
  annotations:
    summary: "Blue-Green traffic switch detected"
```

### 3. CI/CD Integration

**GitLab CI Example:**
```yaml
deploy_green:
  script:
    - kubectl apply -f k8s/green-deployment.yaml
    - kubectl rollout status deployment/webapp-green --timeout=300s
    - ./scripts/test-green-environment.sh
  environment:
    name: staging
    url: https://green.myapp.com

switch_traffic:
  script:
    - kubectl patch service webapp-service -p '{"spec":{"selector":{"version":"green"}}}'
    - ./scripts/monitor-switch.sh
  when: manual
  environment:
    name: production
    url: https://myapp.com
```

## Advantages and Disadvantages

### ✅ Advantages

**Instant Rollback:**
- Switch back to previous version in seconds
- No complex rollback procedures
- Previous environment always ready

**Zero Downtime:**
- Clean traffic switch
- No mixed versions during deployment
- Complete environment isolation

**Full Testing:**
- Test complete production-like environment
- Validate all integrations before switch
- Catch environment-specific issues

**Disaster Recovery:**
- Always have backup environment ready
- Natural disaster recovery setup
- Simple failover procedures

### ❌ Disadvantages

**Resource Cost:**
- Requires 2x infrastructure
- Higher cloud/hardware costs
- May not be cost-effective for all applications

**Database Complexity:**
- Schema changes need backward compatibility
- Data synchronization challenges
- Stateful application difficulties

**Coordination Overhead:**
- More complex deployment orchestration
- Requires coordination between teams
- More moving parts to manage

**State Management:**
- User sessions may be lost during switch
- In-flight transactions need handling
- Cache warming required

## Best Practices

### 1. Health Check Strategy
```yaml
# Comprehensive health checks
readinessProbe:
  httpGet:
    path: /health/ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 2
  failureThreshold: 3

livenessProbe:
  httpGet:
    path: /health/live
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3
```

### 2. Resource Management
```yaml
# Identical resource allocation
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

### 3. Configuration Management
```yaml
# Use same ConfigMaps/Secrets
envFrom:
- configMapRef:
    name: webapp-config
- secretRef:
    name: webapp-secrets
```

### 4. Monitoring Setup
```yaml
# Label-based monitoring
metadata:
  labels:
    app: webapp
    version: blue  # or green
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
```

## Troubleshooting

### Common Issues

**Traffic Not Switching:**
```bash
# Check service selector
kubectl get service webapp-service -o yaml | grep -A 5 selector

# Verify endpoints
kubectl get endpoints webapp-service
kubectl describe endpoints webapp-service
```

**Pods Not Ready:**
```bash
# Check pod status
kubectl get pods -l version=green
kubectl describe pods -l version=green

# Check health checks
kubectl logs -l version=green --tail=50
```

**Database Connection Issues:**
```bash
# Test database connectivity
kubectl exec -it deployment/webapp-green -- nc -zv database-service 5432

# Check connection pool
kubectl logs -l version=green | grep -i "connection\|database"
```

## Files in This Section

- **`01-basic-blue-green.yaml`**: Manual blue-green deployment with detailed explanations
- **`02-automated-blue-green.yaml`**: Automated blue-green using Argo Rollouts
- **`SIMPLE-BLUE-GREEN.yaml`**: Quick-start template for immediate use

## Next Steps

1. **Start Simple**: Deploy `01-basic-blue-green.yaml` to understand fundamentals
2. **Practice Switches**: Manually switch traffic multiple times
3. **Test Rollbacks**: Practice emergency rollback scenarios
4. **Automation**: Implement Argo Rollouts for sophisticated deployments
5. **Monitoring**: Set up comprehensive monitoring for both environments