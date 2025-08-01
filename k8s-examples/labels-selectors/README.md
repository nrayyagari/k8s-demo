# Labels and Selectors: Organize and Query Your Resources

## WHY Do Labels and Selectors Exist?

**Problem**: Need to organize, group, and select Kubernetes resources efficiently across large clusters  
**Solution**: Labels provide metadata tags, selectors enable powerful queries and operations on resource groups

## The Core Question

**"How do I organize thousands of resources and operate on related groups efficiently?"**

Without labels: Find resources by name, manual tracking, no grouping → Operational chaos  
With labels: Tag resources with metadata, query by attributes, bulk operations → Organized management

## What Labels and Selectors Provide

### Resource Organization
- Group related resources by application, team, environment
- Track ownership, versions, and lifecycle stages
- Enable batch operations on resource groups
- Support complex queries across resource types

### Operational Control
- Service selectors find pods to route traffic
- ReplicaSet selectors manage pod replicas
- Network policy selectors control traffic flow
- RBAC selectors grant permissions to resource groups

### Monitoring and Observability
- Prometheus metrics collection by labels
- Log aggregation and filtering
- Cost tracking and chargeback
- Resource utilization analysis

## Label Structure and Best Practices

### Label Anatomy
```yaml
metadata:
  labels:
    key: value
    
# Examples:
app: nginx                           # Simple application name
app.kubernetes.io/name: nginx        # Recommended label
app.kubernetes.io/version: "1.21"    # Version tracking  
app.kubernetes.io/component: frontend # Component role
app.kubernetes.io/part-of: ecommerce  # Application group
app.kubernetes.io/managed-by: helm    # Management tool
environment: production              # Environment designation
team: platform                      # Team ownership
cost-center: engineering             # Cost allocation
```

### Recommended Labels
Kubernetes recommends these standard labels for all resources:

```yaml
metadata:
  labels:
    # Application identification
    app.kubernetes.io/name: wordpress
    app.kubernetes.io/instance: wordpress-blog
    app.kubernetes.io/version: "6.2"
    app.kubernetes.io/component: frontend
    app.kubernetes.io/part-of: blog-platform
    app.kubernetes.io/managed-by: helm
    
    # Custom organizational labels
    team.company.com/owner: content-team
    environment.company.com/stage: production
    cost.company.com/center: marketing
```

## Selector Types and Operations

### Equality-Based Selectors
```yaml
# Simple equality
selector:
  environment: production
  tier: frontend

# Multiple labels (AND logic)
selector:
  app: nginx
  version: "1.21"
  environment: production
```

### Set-Based Selectors
```yaml
# Matchlabels (equality)
selector:
  matchLabels:
    app: nginx
    tier: frontend

# MatchExpressions (advanced operations)  
selector:
  matchExpressions:
  - key: environment
    operator: In
    values: ["production", "staging"]
  - key: tier
    operator: NotIn
    values: ["cache"]
  - key: release
    operator: Exists
  - key: beta
    operator: DoesNotExist
```

### Selector Operators
```yaml
# In: Label value must be in the list
- key: environment
  operator: In
  values: ["prod", "staging"]

# NotIn: Label value must not be in the list  
- key: tier
  operator: NotIn
  values: ["cache", "proxy"]

# Exists: Label key must exist (value ignored)
- key: release
  operator: Exists

# DoesNotExist: Label key must not exist
- key: canary
  operator: DoesNotExist
```

## Files in This Directory

1. **SIMPLE-LABELS-SELECTORS.yaml** - Basic label and selector examples with explanations
2. **01-application-labeling.yaml** - Complete application labeling strategy
3. **02-service-selectors.yaml** - Service discovery and traffic routing with selectors
4. **03-operational-labels.yaml** - Labels for monitoring, cost tracking, and operations
5. **04-advanced-selectors.yaml** - Complex selector patterns and use cases

## Quick Start

```bash
# Apply label examples
kubectl apply -f SIMPLE-LABELS-SELECTORS.yaml

# Query resources by labels
kubectl get pods -l app=nginx
kubectl get pods -l environment=production
kubectl get pods -l 'environment in (prod,staging)'
kubectl get pods -l app=nginx,version!=1.20

# Show labels in output
kubectl get pods --show-labels
kubectl get pods -L app,version,environment

# Add/remove labels
kubectl label pod my-pod version=1.21
kubectl label pod my-pod version-  # Remove label
```

## Basic Patterns

### Application Component Labeling
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-deployment
  labels:
    # Standard recommended labels
    app.kubernetes.io/name: ecommerce
    app.kubernetes.io/instance: ecommerce-prod
    app.kubernetes.io/version: "2.1.0"
    app.kubernetes.io/component: frontend
    app.kubernetes.io/part-of: ecommerce-platform
    app.kubernetes.io/managed-by: kubectl
    
    # Organizational labels
    team.company.com/owner: frontend-team
    environment.company.com/stage: production
    release.company.com/version: "2.1.0"
    cost.company.com/center: product-development
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: ecommerce
      app.kubernetes.io/instance: ecommerce-prod
      app.kubernetes.io/component: frontend
  template:
    metadata:
      labels:
        # Pod labels must include selector labels
        app.kubernetes.io/name: ecommerce
        app.kubernetes.io/instance: ecommerce-prod
        app.kubernetes.io/version: "2.1.0"
        app.kubernetes.io/component: frontend
        app.kubernetes.io/part-of: ecommerce-platform
        
        # Additional pod-specific labels
        pod.company.com/role: web-server
        monitoring.company.com/scrape: "true"
    spec:
      containers:
      - name: frontend
        image: ecommerce-frontend:2.1.0
        ports:
        - containerPort: 80
```

### Service Selection with Labels
```yaml
# Service selects pods by labels
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  labels:
    app.kubernetes.io/name: ecommerce
    app.kubernetes.io/component: frontend
    service.company.com/type: web
spec:
  selector:
    app.kubernetes.io/name: ecommerce
    app.kubernetes.io/component: frontend
    # Service routes traffic to pods with matching labels
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP

---
# Load balancer for external traffic
apiVersion: v1
kind: Service
metadata:
  name: frontend-external
  labels:
    app.kubernetes.io/name: ecommerce
    service.company.com/exposure: external
spec:
  selector:
    app.kubernetes.io/name: ecommerce
    app.kubernetes.io/component: frontend
    environment.company.com/stage: production  # Only production pods
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
```

## Production Labeling Strategies

### Multi-Environment Application
```yaml
# Production deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server-prod
  labels:
    app.kubernetes.io/name: api-server
    app.kubernetes.io/instance: api-server-prod
    app.kubernetes.io/version: "3.2.1"
    environment.company.com/stage: production
    environment.company.com/region: us-west-2
    team.company.com/owner: backend-team
    monitoring.company.com/level: enhanced
    backup.company.com/required: "true"
spec:
  replicas: 5
  selector:
    matchLabels:
      app.kubernetes.io/name: api-server
      app.kubernetes.io/instance: api-server-prod
  template:
    metadata:
      labels:
        app.kubernetes.io/name: api-server
        app.kubernetes.io/instance: api-server-prod
        app.kubernetes.io/version: "3.2.1"
        app.kubernetes.io/component: api
        environment.company.com/stage: production
        pod.company.com/lifecycle: long-running

---
# Staging deployment (same app, different instance)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server-staging
  labels:
    app.kubernetes.io/name: api-server
    app.kubernetes.io/instance: api-server-staging
    app.kubernetes.io/version: "3.3.0-rc1"
    environment.company.com/stage: staging
    environment.company.com/region: us-west-2
    team.company.com/owner: backend-team
    monitoring.company.com/level: standard
    testing.company.com/automated: "true"
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: api-server
      app.kubernetes.io/instance: api-server-staging
  template:
    metadata:
      labels:
        app.kubernetes.io/name: api-server
        app.kubernetes.io/instance: api-server-staging
        app.kubernetes.io/version: "3.3.0-rc1"
        app.kubernetes.io/component: api
        environment.company.com/stage: staging
        pod.company.com/lifecycle: long-running
```

### Microservices with Relationships
```yaml
# Database service
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-primary
  labels:
    app.kubernetes.io/name: postgres
    app.kubernetes.io/instance: ecommerce-db
    app.kubernetes.io/version: "15.3"
    app.kubernetes.io/component: database
    app.kubernetes.io/part-of: ecommerce-platform
    database.company.com/role: primary
    database.company.com/engine: postgresql
    tier.company.com/level: data
spec:
  serviceName: postgres-primary
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: postgres
      app.kubernetes.io/instance: ecommerce-db
      database.company.com/role: primary
  template:
    metadata:
      labels:
        app.kubernetes.io/name: postgres
        app.kubernetes.io/instance: ecommerce-db
        app.kubernetes.io/version: "15.3"
        app.kubernetes.io/component: database
        app.kubernetes.io/part-of: ecommerce-platform
        database.company.com/role: primary
        database.company.com/engine: postgresql
        tier.company.com/level: data
        pod.company.com/storage-type: persistent

---
# Cache service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-cache
  labels:
    app.kubernetes.io/name: redis
    app.kubernetes.io/instance: ecommerce-cache
    app.kubernetes.io/version: "7.0"
    app.kubernetes.io/component: cache
    app.kubernetes.io/part-of: ecommerce-platform
    cache.company.com/type: memory
    tier.company.com/level: cache
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: redis
      app.kubernetes.io/instance: ecommerce-cache
  template:
    metadata:
      labels:
        app.kubernetes.io/name: redis
        app.kubernetes.io/instance: ecommerce-cache
        app.kubernetes.io/version: "7.0"
        app.kubernetes.io/component: cache
        app.kubernetes.io/part-of: ecommerce-platform
        cache.company.com/type: memory
        tier.company.com/level: cache
        pod.company.com/storage-type: ephemeral

---
# Application service that depends on database and cache
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  labels:
    app.kubernetes.io/name: order-service
    app.kubernetes.io/instance: ecommerce-orders
    app.kubernetes.io/version: "1.8.2"
    app.kubernetes.io/component: microservice
    app.kubernetes.io/part-of: ecommerce-platform
    service.company.com/domain: orders
    tier.company.com/level: application
spec:
  replicas: 4
  selector:
    matchLabels:
      app.kubernetes.io/name: order-service
      app.kubernetes.io/instance: ecommerce-orders
  template:
    metadata:
      labels:
        app.kubernetes.io/name: order-service
        app.kubernetes.io/instance: ecommerce-orders
        app.kubernetes.io/version: "1.8.2"
        app.kubernetes.io/component: microservice
        app.kubernetes.io/part-of: ecommerce-platform
        service.company.com/domain: orders
        tier.company.com/level: application
        
        # Dependency labels for network policies
        access.company.com/database: "required"
        access.company.com/cache: "required"
        access.company.com/external-api: "required"
```

## Advanced Selector Patterns

### Complex Service Selection
```yaml
# Service that routes to multiple component types
apiVersion: v1
kind: Service
metadata:
  name: application-backends
  labels:
    service.company.com/type: backend-aggregate
spec:
  selector:
    # Select all backend components of the ecommerce app
    app.kubernetes.io/part-of: ecommerce-platform
    tier.company.com/level: application
  ports:
  - port: 8080
    targetPort: 8080

---
# Service with advanced selector (set-based)
apiVersion: v1
kind: Service
metadata:
  name: production-apis
spec:
  # Note: Services only support equality-based selectors
  # For set-based selection, use other resources like NetworkPolicy
  selector:
    environment.company.com/stage: production
    tier.company.com/level: application
  ports:
  - port: 80
    targetPort: 8080
```

### Network Policy with Advanced Selectors
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-access-policy
  labels:
    policy.company.com/type: database-access
spec:
  # Apply to all database pods
  podSelector:
    matchLabels:
      tier.company.com/level: data
  
  policyTypes:
  - Ingress
  
  ingress:
  # Allow access from application tier only
  - from:
    - podSelector:
        matchExpressions:
        - key: tier.company.com/level
          operator: In
          values: ["application"]
        - key: environment.company.com/stage
          operator: In
          values: ["production", "staging"]
        # Deny access from cache and frontend tiers
        - key: tier.company.com/level
          operator: NotIn
          values: ["cache", "frontend"]
    ports:
    - protocol: TCP
      port: 5432

---
# Network policy for external API access
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: external-api-egress
spec:
  # Apply to pods that need external API access
  podSelector:
    matchLabels:
      access.company.com/external-api: "required"
  
  policyTypes:
  - Egress
  
  egress:
  # Allow external API calls
  - to: []  # External traffic
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
  # Allow DNS resolution
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

### RBAC with Label Selectors
```yaml
# Role that grants access to resources by labels
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: frontend-team-role
rules:
# Can manage all resources labeled with frontend team
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
  resourceNames: []  # Apply to all resources
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]

---
# ClusterRole with label-based resource selection
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-reader
rules:
# Read access to pods with monitoring labels
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]
# Access to metrics endpoints
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list"]
  resourceNames: []
```

## Operational Use Cases

### Cost Tracking and Chargeback
```yaml
# Resources labeled for cost allocation
apiVersion: apps/v1
kind: Deployment
metadata:
  name: analytics-service
  labels:
    # Cost tracking labels
    cost.company.com/center: analytics-department
    cost.company.com/project: customer-insights
    cost.company.com/owner: data-team
    cost.company.com/budget-code: PROJ-2024-001
    
    # Usage classification
    usage.company.com/category: batch-processing
    usage.company.com/priority: normal
    usage.company.com/schedule: business-hours
spec:
  template:
    metadata:
      labels:
        cost.company.com/center: analytics-department
        cost.company.com/project: customer-insights
        usage.company.com/category: batch-processing
```

### Monitoring and Alerting Labels
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-processor
  labels:
    # Monitoring configuration
    monitoring.company.com/level: critical
    monitoring.company.com/scrape: "true"
    monitoring.company.com/port: "8080"
    monitoring.company.com/path: "/metrics"
    
    # Alerting configuration
    alert.company.com/pager-duty: "true"
    alert.company.com/slack-channel: "#payments-alerts"
    alert.company.com/escalation: "level-2"
    
    # SLA requirements
    sla.company.com/availability: "99.9"
    sla.company.com/response-time: "200ms"
spec:
  template:
    metadata:
      labels:
        monitoring.company.com/scrape: "true"
        monitoring.company.com/port: "8080"
        alert.company.com/critical: "true"
```

### Lifecycle and Deployment Labels
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service-canary
  labels:
    # Deployment strategy labels
    deployment.company.com/strategy: canary
    deployment.company.com/traffic-split: "10"
    deployment.company.com/baseline-version: "2.1.0"
    deployment.company.com/canary-version: "2.2.0"
    
    # Lifecycle labels
    lifecycle.company.com/stage: testing
    lifecycle.company.com/promotion-ready: "false"
    lifecycle.company.com/rollback-version: "2.1.0"
    
    # Feature flags
    feature.company.com/new-ui: "enabled"
    feature.company.com/payment-v2: "disabled"
spec:
  replicas: 1  # Small canary deployment
  selector:
    matchLabels:
      app.kubernetes.io/name: user-service
      deployment.company.com/type: canary
  template:
    metadata:
      labels:
        app.kubernetes.io/name: user-service
        app.kubernetes.io/version: "2.2.0"
        deployment.company.com/type: canary
        deployment.company.com/traffic-split: "10"
```

## Query Operations and Commands

### Basic Label Queries
```bash
# Equality-based queries
kubectl get pods -l app=nginx
kubectl get pods -l environment=production
kubectl get pods -l app=nginx,environment=production

# Show labels in output
kubectl get pods --show-labels
kubectl get pods -L app,version,environment

# Query across resource types
kubectl get all -l app.kubernetes.io/part-of=ecommerce-platform
```

### Advanced Label Queries
```bash
# Set-based queries
kubectl get pods -l 'environment in (production,staging)'
kubectl get pods -l 'tier notin (cache,proxy)'
kubectl get pods -l 'release'  # Has release label
kubectl get pods -l '!canary'  # Doesn't have canary label

# Complex combinations
kubectl get pods -l 'app=nginx,environment in (prod,staging),!canary'

# Query by prefix
kubectl get pods -l 'app.kubernetes.io/name'
kubectl get pods -l 'team.company.com/owner'
```

### Label Management Operations
```bash
# Add labels
kubectl label pod my-pod version=1.21
kubectl label pod my-pod team.company.com/owner=backend-team

# Update labels
kubectl label pod my-pod version=1.22 --overwrite

# Remove labels
kubectl label pod my-pod version-
kubectl label pod my-pod team.company.com/owner-

# Bulk label operations
kubectl label pods -l app=nginx version=1.21
kubectl label nodes -l region=us-west-2 environment=production
```

### Resource Cleanup by Labels
```bash
# Delete resources by labels
kubectl delete pods -l app=old-version
kubectl delete services -l tier=deprecated
kubectl delete deployments -l environment=development

# Conditional cleanup
kubectl delete pods -l 'environment in (dev,test),version!=latest'
```

## Monitoring and Observability

### Prometheus Label Integration
```yaml
# Service monitor for Prometheus
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: application-metrics
  labels:
    monitoring.company.com/team: platform
spec:
  selector:
    matchLabels:
      monitoring.company.com/scrape: "true"
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics

---
# Pod monitor with label selectors
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: batch-job-metrics
spec:
  selector:
    matchExpressions:
    - key: job.company.com/type
      operator: In
      values: ["batch", "ml-training"]
    - key: monitoring.company.com/scrape
      operator: In
      values: ["true"]
  podMetricsEndpoints:
  - port: metrics
    interval: 60s
```

### Log Aggregation by Labels
```yaml
# Fluentd configuration for label-based log routing
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
data:
  fluent.conf: |
    <filter kubernetes.**>
      @type kubernetes_metadata
      @id filter_kube_metadata
    </filter>
    
    # Route logs by application labels
    <match kubernetes.var.log.containers.**>
      @type copy
      
      # Critical applications to separate index
      <store>
        @type elasticsearch
        index_name critical-apps-${Time.at(time).strftime('%Y.%m.%d')}
        <buffer>
          @type memory
        </buffer>
        <filter>
          key $.kubernetes.labels['monitoring.company.com/level']
          pattern critical
        </filter>
      </store>
      
      # Development logs to dev index
      <store>
        @type elasticsearch
        index_name dev-logs-${Time.at(time).strftime('%Y.%m.%d')}
        <buffer>
          @type memory
        </buffer>
        <filter>
          key $.kubernetes.labels['environment.company.com/stage']
          pattern development
        </filter>
      </store>
    </match>
```

## Troubleshooting

### Selector Mismatch Issues
```bash
# Debug service endpoint selection
kubectl describe service my-service
kubectl get endpoints my-service
kubectl get pods -l app=my-app --show-labels

# Check if pods match service selector
kubectl get pods -l $(kubectl get service my-service -o jsonpath='{.spec.selector}' | sed 's/map\[//g' | sed 's/\]//g' | sed 's/:/=/g')
```

### Label Conflicts
```bash
# Find pods with conflicting labels
kubectl get pods --show-labels | grep -E "(version.*version|app.*app)"

# Check for typos in label keys
kubectl get pods --show-labels | grep -E "(envrionment|applicaton|versoin)"

# Validate label values
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}: {.metadata.labels}{"\n"}{end}'
```

### Performance Issues with Selectors
```bash
# Monitor API server performance
kubectl get --raw /metrics | grep apiserver_request_duration

# Check for expensive label queries
kubectl get events | grep "FailedMount\|FailedScheduling"

# Optimize by using fewer labels in selectors
kubectl get pods -l app=nginx  # Good
kubectl get pods -l 'app=nginx,version=1.21,environment=prod,team=platform'  # May be slow
```

## Best Practices

### Label Naming Conventions
```yaml
# Use consistent prefixes for organization
team.company.com/owner: backend-team
team.company.com/lead: alice@company.com
team.company.com/slack: "#backend-alerts"

cost.company.com/center: engineering
cost.company.com/project: user-authentication
cost.company.com/budget: Q4-2024

monitoring.company.com/level: critical
monitoring.company.com/scrape: "true"
monitoring.company.com/port: "8080"
```

### Selector Strategy
```yaml
# Use stable, meaningful labels for selectors
selector:
  matchLabels:
    app.kubernetes.io/name: nginx        # Stable
    app.kubernetes.io/component: frontend # Stable
    # Avoid: version, build-number (change frequently)

# Prefer matchLabels for simple cases
selector:
  matchLabels:
    app: nginx
    tier: frontend

# Use matchExpressions for complex logic
selector:
  matchExpressions:
  - key: environment
    operator: In
    values: ["production", "staging"]
  - key: canary
    operator: DoesNotExist
```

### Operational Labels
```yaml
metadata:
  labels:
    # Always include these for operations
    app.kubernetes.io/name: myapp
    app.kubernetes.io/version: "1.2.3"
    app.kubernetes.io/component: frontend
    
    # Team and ownership
    team.company.com/owner: platform-team
    
    # Environment and lifecycle
    environment.company.com/stage: production
    
    # Monitoring and alerting
    monitoring.company.com/level: standard
```

## Performance Considerations

### Label Limits
- Maximum 63 characters per label key/value
- Maximum 253 characters for label key prefix
- Avoid too many labels (impacts etcd performance)
- Use meaningful but concise label values

### Selector Efficiency
- Equality-based selectors are faster than set-based
- Fewer labels in selectors perform better
- Index commonly queried labels
- Avoid complex regular expressions in values

### Storage Impact
- Labels are stored in etcd
- Many labels increase resource size
- Consider using annotations for non-selector metadata
- Monitor etcd storage usage

## Key Insights

**Labels are metadata, selectors are queries** - labels describe resources, selectors find them

**Consistency is critical** - establish and enforce label naming conventions across teams

**Less is more for selectors** - use minimal labels for resource selection to improve performance

**Plan for operations** - include labels that support monitoring, cost tracking, and troubleshooting

**Test selector logic** - verify that selectors match intended resources before deploying

**Version your labeling strategy** - evolve labels thoughtfully to avoid breaking existing selectors

**Labels enable automation** - well-designed labels make operations scalable and reliable

**Balance specificity with flexibility** - too specific labels limit reusability, too generic reduce utility