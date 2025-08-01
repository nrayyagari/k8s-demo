# Annotations: Metadata for Tools and Humans

## WHY Do Annotations Exist?

**Problem**: Need to attach metadata that tools, automation, and humans can use, but shouldn't affect pod selection  
**Solution**: Annotations provide arbitrary metadata storage without influencing Kubernetes object selection

## The Core Question

**"How do I store metadata about my resources for tools and people to use?"**

Labels: Used for selection and grouping → `app=web-server`  
Annotations: Used for metadata and context → `team.company.com/owner="platform-team"`

## What Annotations Do

### Tool Integration
- Prometheus scraping configuration
- Ingress controller routing rules  
- Build and deployment information
- Backup and monitoring instructions

### Human Context
- Team ownership and contact information
- Operational procedures and runbooks
- Change tracking and audit trails
- Documentation and links

### External System Communication
- Cloud provider resource tagging
- CI/CD pipeline metadata
- Security scanner configuration
- Cost allocation and tracking

## Basic Pattern

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  annotations:
    # Tool configuration
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
    
    # Team information  
    team.company.com/owner: "platform-team"
    team.company.com/slack: "#platform-alerts"
    
    # Build metadata
    build.company.com/version: "v1.2.3"
    build.company.com/commit: "abc123def"
    build.company.com/pipeline: "jenkins-prod-123"
spec:
  # ... deployment spec
```

## Annotation Key Format

### Syntax Rules
```yaml
# Format: [prefix/]name
# Prefix (optional): Valid DNS subdomain  
# Name (required): 63 chars max, alphanumeric + hyphens/underscores/dots

# Valid examples:
imageregistry: "https://hub.docker.com/"                    # No prefix
deployment.kubernetes.io/revision: "1"                      # K8s prefix
example.com/build-info: "build-123"                         # Custom prefix
team/owner: "platform"                                      # Simple prefix
```

### Reserved Prefixes
- `kubernetes.io/` - Core Kubernetes components
- `k8s.io/` - Kubernetes ecosystem tools

## Files in This Directory

1. **SIMPLE-ANNOTATIONS.yaml** - Basic annotation examples with explanations
2. **01-deployment-metadata.yaml** - Complete deployment with production annotations
3. **02-service-configuration.yaml** - Service with tool-specific annotations
4. **03-production-patterns.yaml** - Enterprise annotation patterns

## Quick Start

```bash
# Apply basic annotations example
kubectl apply -f SIMPLE-ANNOTATIONS.yaml

# Check annotations on resources
kubectl get deployment webapp -o yaml | grep -A 10 annotations
kubectl describe deployment webapp

# Add annotation to existing resource
kubectl annotate deployment webapp version=v1.0.1

# Remove annotation
kubectl annotate deployment webapp version-
```

## Common Production Annotations

### Team and Ownership
```yaml
annotations:
  # Team ownership
  team.company.com/owner: "platform-team"
  team.company.com/slack: "#platform-alerts"  
  team.company.com/email: "platform@company.com"
  team.company.com/escalation: "#oncall-platform"
  
  # Cost and billing
  cost.company.com/center: "engineering"
  cost.company.com/project: "user-platform"
  cost.company.com/environment: "production"
```

### Monitoring and Observability
```yaml
annotations:
  # Prometheus scraping
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
  
  # Logging configuration
  logging.company.com/level: "info"
  logging.company.com/format: "json"
  
  # Tracing
  tracing.company.com/enabled: "true"
  tracing.company.com/sample-rate: "0.1"
```

### Build and Deployment
```yaml
annotations:
  # Build information
  build.company.com/version: "v1.2.3"
  build.company.com/commit: "abc123def456"
  build.company.com/branch: "main"
  build.company.com/pipeline: "jenkins-prod-123"
  build.company.com/timestamp: "2024-01-15T10:30:00Z"
  
  # Deployment tracking
  deployment.company.com/strategy: "blue-green"
  deployment.company.com/approver: "jane.doe@company.com"
  deployment.company.com/rollback-version: "v1.2.2"
```

### Security and Compliance
```yaml
annotations:
  # Security scanning
  security.company.com/scanned: "true"
  security.company.com/scanner: "trivy-v0.18.0"
  security.company.com/scan-date: "2024-01-15T09:00:00Z"
  
  # Compliance
  compliance.company.com/pci-required: "true"
  compliance.company.com/data-classification: "confidential"
  compliance.company.com/audit-required: "true"
```

## Tool-Specific Annotations

### Ingress Controllers
```yaml
# NGINX Ingress
nginx.ingress.kubernetes.io/rewrite-target: /
nginx.ingress.kubernetes.io/ssl-redirect: "true"
nginx.ingress.kubernetes.io/rate-limit: "100"

# Traefik
traefik.ingress.kubernetes.io/router.middlewares: default-auth@kubernetescrd
traefik.ingress.kubernetes.io/router.tls: "true"
```

### Service Mesh (Istio)
```yaml
# Istio configuration
sidecar.istio.io/inject: "true"
traffic.sidecar.istio.io/includeInboundPorts: "8080,8443"
traffic.sidecar.istio.io/excludeOutboundPorts: "8080"
```

### Cluster Autoscaler
```yaml
# Pod eviction control
cluster-autoscaler.kubernetes.io/safe-to-evict: "true"
cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes: "cache,logs"
```

## Advanced Patterns

### JSON Metadata
```yaml
annotations:
  # Complex configuration as JSON
  backup.company.com/config: |
    {
      "schedule": "0 2 * * *",
      "retention": "30d",
      "destinations": ["s3://backups/", "gs://backup-bucket/"],
      "encryption": true
    }
  
  # Runbook procedures
  runbook.company.com/procedures: |
    {
      "restart": "kubectl rollout restart deployment/webapp",
      "scale": "kubectl scale deployment webapp --replicas=10",
      "logs": "kubectl logs -f deployment/webapp"
    }
```

### Multi-Environment Configuration
```yaml
annotations:
  # Environment-specific overrides
  config.company.com/dev: "debug=true,replicas=1"
  config.company.com/staging: "debug=false,replicas=3"  
  config.company.com/prod: "debug=false,replicas=10"
  
  # Feature flags
  features.company.com/new-ui: "enabled"
  features.company.com/beta-api: "disabled"
```

## Best Practices

### Naming Conventions
```yaml
# Good: Descriptive and organized
team.company.com/owner: "platform-team"
monitoring.company.com/alert-threshold: "90"
backup.company.com/frequency: "daily"

# Bad: Unclear purpose
owner: "platform"
threshold: "90"  
freq: "daily"
```

### Value Structure
```yaml
# Good: Structured and parseable
build.company.com/info: '{"version":"v1.0","commit":"abc123","date":"2024-01-15"}'
contact.company.com/team: "platform-team <platform@company.com>"

# Bad: Unstructured strings
build: "v1.0 abc123 2024-01-15"
contact: "platform team platform@company.com"
```

### Documentation
```yaml
annotations:
  # Always include documentation links
  docs.company.com/runbook: "https://wiki.company.com/platform/webapp-runbook"
  docs.company.com/api: "https://api-docs.company.com/webapp/v1"
  docs.company.com/dashboard: "https://grafana.company.com/d/webapp-overview"
```

## Common Operations

### Adding Annotations
```bash
# Add single annotation
kubectl annotate deployment webapp version=v1.0.1

# Add multiple annotations
kubectl annotate deployment webapp \
  team.company.com/owner=platform \
  build.company.com/version=v1.0.1

# Add from file
kubectl apply -f deployment-with-annotations.yaml
```

### Viewing Annotations
```bash
# View all annotations
kubectl get deployment webapp -o jsonpath='{.metadata.annotations}'

# View specific annotation
kubectl get deployment webapp -o jsonpath='{.metadata.annotations.team\.company\.com/owner}'

# Describe shows annotations
kubectl describe deployment webapp
```

### Removing Annotations
```bash
# Remove single annotation
kubectl annotate deployment webapp version-

# Remove multiple annotations  
kubectl annotate deployment webapp version- build.company.com/commit-
```

### Searching by Annotations
```bash
# Find resources with specific annotation
kubectl get deployments -o json | jq '.items[] | select(.metadata.annotations."team.company.com/owner"=="platform")'

# List all annotation keys
kubectl get deployments -o json | jq '.items[].metadata.annotations | keys[]' | sort | uniq
```

## Troubleshooting

### Annotation Not Visible
```bash
# Check if annotation exists
kubectl get deployment webapp -o yaml | grep -A 20 annotations

# Verify annotation key format
# Common issue: Special characters need escaping
kubectl get deployment webapp -o jsonpath='{.metadata.annotations.prometheus\.io/scrape}'
```

### Tool Not Reading Annotations  
```bash
# Verify annotation format matches tool expectations
kubectl describe deployment webapp

# Check tool documentation for exact annotation format
# Example: Prometheus expects specific keys and values
```

### Annotation Value Too Large
```bash
# Kubernetes limit: 256KB total for all annotations
kubectl get deployment webapp -o json | jq '.metadata.annotations | length'

# Move large data to ConfigMaps/Secrets instead
```

## When Annotations Aren't Enough

### Need Selection/Grouping?
Use **Labels** for:
- Service selectors
- Pod selectors in deployments  
- Resource queries and filtering

### Need Large Data Storage?
Use **ConfigMaps/Secrets** for:
- Configuration files
- Large JSON/YAML data
- Sensitive information

### Need Structured Configuration?
Use **Custom Resources** for:
- Complex application configuration
- Tool-specific settings
- Typed configuration validation

## Key Insights

**Annotations are for metadata, not selection** - use labels for object selection and grouping

**Follow naming conventions** - use DNS-style prefixes to avoid conflicts with other tools

**Keep values meaningful** - future you and your teammates will thank you for clear, structured annotations

**Document your conventions** - establish team standards for annotation usage and naming

**Tools rely on annotations** - many Kubernetes ecosystem tools use annotations for configuration

**Annotations enable automation** - they're the primary way to provide configuration to controllers and operators