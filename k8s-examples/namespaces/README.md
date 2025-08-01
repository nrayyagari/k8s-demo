# Namespaces: Organize and Isolate Your Cluster

## WHY Do Namespaces Exist?

**Problem**: Multiple teams/apps sharing one cluster creates naming conflicts and resource chaos  
**Solution**: Namespaces provide virtual clusters within physical cluster for organization and isolation

## The Core Question

**"How do I organize multiple teams and applications in one Kubernetes cluster?"**

Single cluster: Everyone's apps mixed together → Name conflicts, resource fights, security issues  
Namespaces: Logical separation → Teams isolated, resources organized, security boundaries

## What Namespaces Do

### Logical Isolation
- Separate environments (dev, staging, prod)  
- Team boundaries (frontend, backend, data)
- Application grouping (microservices, batch jobs)
- Multi-tenancy support

### Resource Organization
- Scoped resource names (same names in different namespaces)
- Resource quotas per namespace
- Network policies for traffic control
- RBAC permissions per namespace

### Production Management
- Environment separation for deployment pipelines
- Team access control and responsibility
- Resource allocation and cost tracking
- Disaster recovery boundaries

## Basic Pattern

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: prod
    team: platform
    cost-center: engineering
  annotations:
    contact.company.com/owner: "platform-team"
    budget.company.com/limit: "10000"
    compliance.company.com/level: "high"
```

## Default Namespaces

Kubernetes creates these by default:

### default
- Where resources go if no namespace specified
- Generally avoid using in production
- Good for quick testing and experiments

### kube-system
- Core Kubernetes components
- DNS, networking, controllers
- **Never deploy user applications here**

### kube-public
- Publicly readable by all users
- Cluster information and public data
- Rarely used in practice

### kube-node-lease
- Node heartbeat objects for cluster health
- Performance optimization for large clusters
- Internal Kubernetes use only

## Namespace Organization Patterns

### 1. Environment-Based
```yaml
# Development environment
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    environment: dev
    lifecycle: temporary
  annotations:
    auto-cleanup.company.com/enabled: "true"
    auto-cleanup.company.com/retention: "30d"

---
# Staging environment  
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    environment: staging
    lifecycle: stable
  annotations:
    deployment.company.com/promote-to: "production"

---
# Production environment
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: prod
    lifecycle: permanent
    criticality: high
  annotations:
    backup.company.com/enabled: "true"
    monitoring.company.com/level: "enhanced"
```

### 2. Team-Based
```yaml
# Frontend team namespace
apiVersion: v1
kind: Namespace
metadata:
  name: frontend-team
  labels:
    team: frontend
    department: engineering
  annotations:
    team.company.com/lead: "sarah@company.com"
    team.company.com/slack: "#frontend-team"

---
# Backend team namespace
apiVersion: v1
kind: Namespace
metadata:
  name: backend-team
  labels:
    team: backend
    department: engineering
  annotations:
    team.company.com/lead: "mike@company.com"
    team.company.com/slack: "#backend-team"

---
# Data team namespace
apiVersion: v1
kind: Namespace
metadata:
  name: data-team
  labels:
    team: data
    department: analytics
  annotations:
    team.company.com/lead: "alex@company.com"
    team.company.com/slack: "#data-team"
```

### 3. Application-Based
```yaml
# E-commerce application
apiVersion: v1
kind: Namespace
metadata:
  name: ecommerce
  labels:
    application: ecommerce
    tier: business-critical
  annotations:
    application.company.com/owner: "product-team"
    application.company.com/repository: "github.com/company/ecommerce"

---
# Analytics application
apiVersion: v1
kind: Namespace
metadata:
  name: analytics
  labels:
    application: analytics
    tier: data-processing
  annotations:
    application.company.com/owner: "data-team"
    application.company.com/schedule: "batch-processing"
```

## Working with Namespaces

### Creating Resources in Namespaces
```yaml
# Method 1: Specify in resource metadata
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: production  # Explicit namespace
spec:
  # deployment spec...

---
# Method 2: Use kubectl with -n flag
# kubectl apply -f deployment.yaml -n production
```

### Cross-Namespace Communication
```yaml
# Services can be accessed across namespaces
# Format: service-name.namespace-name.svc.cluster.local

apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: frontend-team
data:
  DATABASE_URL: "postgres://db-service.backend-team.svc.cluster.local:5432/app"
  CACHE_URL: "redis://cache-service.data-team.svc.cluster.local:6379"
```

### Namespace Resource Quotas
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: frontend-team
spec:
  hard:
    # Compute resources
    requests.cpu: "10"         # 10 CPU cores requested
    requests.memory: 20Gi      # 20GB memory requested
    limits.cpu: "20"           # 20 CPU cores limit
    limits.memory: 40Gi        # 40GB memory limit
    
    # Storage resources
    requests.storage: 100Gi    # 100GB storage
    persistentvolumeclaims: "4" # Max 4 PVCs
    
    # Object counts
    pods: "20"                 # Max 20 pods
    services: "10"             # Max 10 services
    deployments.apps: "10"     # Max 10 deployments
    secrets: "20"              # Max 20 secrets
    configmaps: "20"           # Max 20 configmaps
```

## Files in This Directory

1. **SIMPLE-NAMESPACES.yaml** - Basic namespace examples with explanations
2. **01-environment-namespaces.yaml** - Dev/staging/prod namespace setup
3. **02-team-namespaces.yaml** - Team-based namespace organization
4. **03-application-namespaces.yaml** - Application-centric namespace design
5. **04-namespace-quotas.yaml** - Resource quota examples per namespace
6. **05-cross-namespace-access.yaml** - Service discovery across namespaces

## Quick Start

```bash
# Create namespace
kubectl create namespace my-team

# Or apply from file
kubectl apply -f SIMPLE-NAMESPACES.yaml

# List namespaces
kubectl get namespaces
kubectl get ns  # Short form

# Set default namespace for kubectl
kubectl config set-context --current --namespace=my-team

# Deploy to specific namespace
kubectl apply -f app.yaml -n production

# View resources in namespace
kubectl get all -n production
```

## Advanced Namespace Features

### Namespace Labels and Selectors
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: secure-workloads
  labels:
    security.company.com/level: "high"
    compliance.company.com/required: "true"
    network.company.com/isolation: "strict"
  annotations:
    policy.company.com/pod-security-standard: "restricted"
    network.company.com/allowed-egress: "limited"
```

### Namespace Finalizers
```yaml
# Namespace with finalizers (for cleanup control)
apiVersion: v1
kind: Namespace
metadata:
  name: temporary-project
  finalizers:
  - custom-cleanup.company.com/database
  - custom-cleanup.company.com/external-resources
# Namespace won't delete until finalizers removed
```

### Automatic Namespace Creation
```yaml
# Using namespace-as-a-service pattern
apiVersion: v1
kind: ConfigMap
metadata:
  name: namespace-template
  namespace: platform-system
data:
  template.yaml: |
    apiVersion: v1
    kind: Namespace
    metadata:
      name: {{.TeamName}}
      labels:
        team: {{.TeamName}}
        created-by: platform-automation
      annotations:
        team.company.com/lead: {{.TeamLead}}
        quota.company.com/cpu: {{.CpuQuota}}
        quota.company.com/memory: {{.MemoryQuota}}
```

## Network Policies with Namespaces

### Namespace Isolation
```yaml
# Deny all traffic to namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  podSelector: {}  # Selects all pods in namespace
  policyTypes:
  - Ingress
  - Egress
  # No ingress/egress rules = deny all

---
# Allow specific namespace communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: backend-team
spec:
  podSelector:
    matchLabels:
      tier: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          team: frontend
    ports:
    - protocol: TCP
      port: 8080
```

### Cross-Namespace Service Access
```yaml
# Allow database access from multiple namespaces
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-access
  namespace: data-team
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          database-access: "allowed"
    ports:
    - protocol: TCP
      port: 5432
```

## RBAC with Namespaces

### Namespace-Scoped Permissions
```yaml
# Role for namespace-specific access
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: frontend-team
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]

---
# Bind role to users for this namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: frontend-developers
  namespace: frontend-team
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: developer
subjects:
- kind: User
  name: alice@company.com
- kind: User
  name: bob@company.com
- kind: Group
  name: frontend-team
```

### Multi-Namespace Access
```yaml
# ClusterRole for multi-namespace read access
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: multi-namespace-reader
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list"]
  resourceNames: []

---
# Apply to specific namespaces
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: sre-access
  namespace: production
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: multi-namespace-reader
subjects:
- kind: Group
  name: sre-team
```

## Common Operations

### Namespace Management
```bash
# Create namespace with labels
kubectl create namespace development --dry-run=client -o yaml | \
  kubectl label --local -f - environment=dev -o yaml | \
  kubectl apply -f -

# Delete namespace (WARNING: deletes all resources)
kubectl delete namespace development

# Switch default namespace context
kubectl config set-context --current --namespace=production

# View current context namespace
kubectl config view --minify | grep namespace
```

### Resource Operations
```bash
# List all resources in namespace
kubectl get all -n production

# Describe namespace details
kubectl describe namespace production

# Get resources across all namespaces
kubectl get pods --all-namespaces
kubectl get pods -A  # Short form

# Copy resources between namespaces
kubectl get secret mysecret -n source-ns -o yaml | \
  sed 's/namespace: source-ns/namespace: target-ns/' | \
  kubectl apply -f -
```

### Monitoring and Debugging
```bash
# Check namespace resource usage
kubectl top pods -n production
kubectl top nodes

# View namespace events
kubectl get events -n production
kubectl get events --sort-by='.lastTimestamp' -n production

# Debug namespace issues
kubectl describe namespace production
kubectl get resourcequotas -n production
kubectl get limitranges -n production
```

## Troubleshooting

### Namespace Stuck in Terminating
```bash
# Check what's preventing deletion
kubectl describe namespace stuck-namespace

# Check for finalizers
kubectl get namespace stuck-namespace -o yaml

# Force remove finalizers (dangerous!)
kubectl patch namespace stuck-namespace -p '{"metadata":{"finalizers":null}}' --type=merge
```

### Resource Quota Exceeded
```bash
# Check current quota usage
kubectl describe resourcequota -n my-namespace

# Check what's using resources
kubectl top pods -n my-namespace
kubectl describe pods -n my-namespace | grep -A5 "Requests:"

# Adjust quota if needed
kubectl patch resourcequota team-quota -n my-namespace --type='merge' -p='{"spec":{"hard":{"requests.cpu":"20"}}}'
```

### Cross-Namespace Access Issues
```bash
# Test service discovery
kubectl run test-pod --image=busybox --rm -it -- nslookup service-name.namespace-name.svc.cluster.local

# Check network policies
kubectl get networkpolicies -n target-namespace
kubectl describe networkpolicy policy-name -n target-namespace

# Test connectivity
kubectl exec -it pod-name -n source-namespace -- wget -qO- http://service.target-namespace.svc.cluster.local
```

## Best Practices

### Naming Conventions
```yaml
# Consistent naming patterns
metadata:
  name: team-environment-purpose
  # Examples:
  # frontend-prod
  # backend-dev  
  # data-staging
  # platform-tools
```

### Resource Management
```yaml
# Always set quotas in shared clusters
apiVersion: v1
kind: ResourceQuota
metadata:
  name: default-quota
  namespace: team-namespace
spec:
  hard:
    requests.cpu: "2"      # Start conservative
    requests.memory: 4Gi   # Monitor and adjust
    limits.cpu: "4"        # Prevent resource hogging
    limits.memory: 8Gi     # Allow some headroom
```

### Security
```yaml
# Use labels for policy enforcement
metadata:
  labels:
    security.company.com/level: "high"
    network.company.com/isolation: "strict"
    pod-security.kubernetes.io/enforce: "restricted"
```

### Monitoring and Observability
```yaml
metadata:
  annotations:
    # Contact information
    team.company.com/owner: "platform-team"
    team.company.com/slack: "#platform-alerts"
    
    # Operational information
    runbook.company.com/url: "https://wiki.company.com/runbooks/namespace"
    monitoring.company.com/dashboard: "https://grafana.company.com/namespace-overview"
```

## Production Patterns

### Multi-Environment Pipeline
```yaml
# Development → Staging → Production flow
apiVersion: v1
kind: Namespace
metadata:
  name: myapp-dev
  labels:
    app: myapp
    environment: development
    promote-to: myapp-staging
  annotations:
    ci.company.com/auto-deploy: "true"
    ci.company.com/source-branch: "develop"

---
apiVersion: v1
kind: Namespace
metadata:
  name: myapp-staging
  labels:
    app: myapp
    environment: staging
    promote-to: myapp-prod
  annotations:
    ci.company.com/auto-deploy: "false"  # Manual promotion
    ci.company.com/smoke-tests: "true"

---
apiVersion: v1
kind: Namespace
metadata:
  name: myapp-prod
  labels:
    app: myapp
    environment: production
    criticality: high
  annotations:
    backup.company.com/enabled: "true"
    monitoring.company.com/level: "enhanced"
```

### Tenant Isolation
```yaml
# Multi-tenant SaaS application
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-acme-corp
  labels:
    tenant: acme-corp
    tier: premium
    region: us-east-1
  annotations:
    tenant.company.com/id: "12345"
    tenant.company.com/plan: "enterprise"
    tenant.company.com/support-level: "premium"
    billing.company.com/account-id: "acc-67890"
```

## Performance Considerations

### Resource Planning
- Set appropriate resource quotas based on workload patterns
- Monitor namespace resource utilization over time
- Plan for peak usage scenarios
- Consider node affinity for namespace workloads

### Network Performance
- Use network policies judiciously (they add overhead)
- Co-locate frequently communicating services in same namespace
- Monitor cross-namespace communication patterns
- Consider service mesh for complex communication

## Key Insights

**Namespaces are virtual clusters** - they provide isolation within a physical cluster without the overhead of separate clusters

**Default namespace is not for production** - always create explicit namespaces for organized resource management

**Cross-namespace communication is possible** - services can reach each other using FQDN: service.namespace.svc.cluster.local

**RBAC integrates with namespaces** - use namespace-scoped roles and bindings for team access control

**Resource quotas prevent resource hogging** - always set quotas in shared clusters to ensure fairness

**Network policies provide security boundaries** - use them to control traffic flow between namespaces

**Labels and annotations enable automation** - use consistent metadata for policy enforcement and operational automation

**Namespace deletion is destructive** - it removes ALL resources in the namespace, use carefully in production