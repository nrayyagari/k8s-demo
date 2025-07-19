# ConfigMaps & Secrets: External Configuration

## WHY Do ConfigMaps and Secrets Exist?

**Problem**: Hardcoding passwords and config in your app = security risk + rebuild for changes  
**Solution**: Store configuration externally, inject at runtime

## The Core Questions

**"Where do I put my database password?"** → Secrets  
**"Where do I put my app settings?"** → ConfigMaps  
**"How do I change config without rebuilding?"** → External configuration

## ConfigMaps vs Secrets

### ConfigMaps (Non-sensitive data)
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  database.host: "db.example.com"
  database.port: "5432"
  debug.enabled: "true"
  feature.flags: "new-ui,fast-checkout"
```

### Secrets (Sensitive data)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  database.password: cGFzc3dvcmQxMjM=  # base64 encoded
  api.key: bXlzZWNyZXRhcGlrZXk=        # base64 encoded
```

## Two Ways to Use Configuration

### Method 1: Environment Variables (Most Common)
```yaml
containers:
- name: app
  image: myapp:v1
  env:
  - name: DATABASE_HOST
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: database.host
  - name: DATABASE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: app-secrets
        key: database.password
```

### Method 2: Files (For Complex Config)
```yaml
containers:
- name: app
  image: myapp:v1
  volumeMounts:
  - name: config-volume
    mountPath: /etc/config
  - name: secret-volume
    mountPath: /etc/secrets
volumes:
- name: config-volume
  configMap:
    name: app-config
- name: secret-volume
  secret:
    secretName: app-secrets
```

## Creating ConfigMaps and Secrets

### From Command Line
```bash
# ConfigMap from literals
kubectl create configmap app-config \
  --from-literal=database.host=db.example.com \
  --from-literal=debug.enabled=true

# Secret from literals  
kubectl create secret generic app-secrets \
  --from-literal=database.password=password123 \
  --from-literal=api.key=secret-key

# From files
kubectl create configmap app-config --from-file=config.properties
kubectl create secret generic app-secrets --from-file=secrets.env
```

### From YAML Files
```bash
# Apply YAML definitions
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
```

## Base64 Encoding for Secrets

### Manual Encoding
```bash
# Encode
echo -n "password123" | base64
# Output: cGFzc3dvcmQxMjM=

# Decode  
echo "cGFzc3dvcmQxMjM=" | base64 -d
# Output: password123
```

**Important**: Base64 is encoding, NOT encryption - anyone can decode it

## Real-World Example

```yaml
# Database configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
data:
  host: "postgres.example.com"
  port: "5432"
  database: "myapp"
  ssl_mode: "require"

---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secrets
type: Opaque
data:
  username: cG9zdGdyZXM=      # postgres
  password: c3VwZXJzZWNyZXQ=  # supersecret

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: app
        image: myapp:v1
        env:
        # ConfigMap values
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: postgres-config
              key: host
        - name: DB_PORT
          valueFrom:
            configMapKeyRef:
              name: postgres-config
              key: port
        # Secret values
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: postgres-secrets
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secrets
              key: password
```

## Files in This Directory

1. **SIMPLE-CONFIG.yaml** - Complete example with ConfigMaps, Secrets, and usage patterns

## Quick Start

```bash
# Deploy complete example
kubectl apply -f SIMPLE-CONFIG.yaml

# Check what was created
kubectl get configmaps
kubectl get secrets

# View ConfigMap contents
kubectl describe configmap app-config

# View Secret (values hidden)
kubectl describe secret app-secrets

# Decode secret values
kubectl get secret app-secrets -o yaml
```

## Configuration Patterns

### Environment-Specific ConfigMaps
```yaml
# dev-config
data:
  database.host: "dev-db.company.com"
  debug.enabled: "true"
  
# prod-config  
data:
  database.host: "prod-db.company.com"
  debug.enabled: "false"
```

### Feature Flags
```yaml
data:
  feature.new_ui: "true"
  feature.beta_checkout: "false"
  feature.experimental_api: "true"
```

### Complex Configuration Files
```yaml
# Mount as file at /etc/config/nginx.conf
data:
  nginx.conf: |
    server {
      listen 80;
      location / {
        proxy_pass http://backend;
      }
    }
```

## Security Best Practices

### Secrets Management
```yaml
# ✅ Good: Use Secrets for sensitive data
secretKeyRef:
  name: app-secrets
  key: api-key

# ❌ Bad: Secrets in ConfigMaps
configMapKeyRef:
  name: app-config  
  key: api-key  # DON'T PUT SECRETS HERE
```

### RBAC (Role-Based Access Control)
```yaml
# Limit who can read secrets
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
```

### External Secret Management
Consider external tools for production:
- **HashiCorp Vault**
- **AWS Secrets Manager**  
- **Azure Key Vault**
- **Google Secret Manager**

## Common Operations

### Updating Configuration
```bash
# Update ConfigMap
kubectl patch configmap app-config -p '{"data":{"debug.enabled":"false"}}'

# Update Secret (base64 encode first)
kubectl patch secret app-secrets -p '{"data":{"api.key":"bmV3LXNlY3JldA=="}}'

# Or edit directly
kubectl edit configmap app-config
kubectl edit secret app-secrets
```

### Viewing Configuration
```bash
# List all ConfigMaps/Secrets
kubectl get configmaps
kubectl get secrets

# View contents
kubectl describe configmap app-config
kubectl get configmap app-config -o yaml

# Decode secret
kubectl get secret app-secrets -o jsonpath='{.data.password}' | base64 -d
```

## Troubleshooting

### Configuration Not Loading
```bash
# Check if ConfigMap/Secret exists
kubectl get configmap app-config
kubectl get secret app-secrets

# Check pod environment
kubectl exec pod-name -- env | grep DATABASE

# Check mounted files
kubectl exec pod-name -- ls -la /etc/config
kubectl exec pod-name -- cat /etc/config/database.host
```

### Common Issues
1. **Key name mismatch** - Check exact key names in ConfigMap/Secret
2. **Missing references** - Ensure ConfigMap/Secret exists before deployment
3. **Base64 encoding** - Secrets must be base64 encoded
4. **Namespace** - ConfigMaps/Secrets must be in same namespace as pods

## When to Use What

### ✅ ConfigMaps
- Database hostnames and ports
- Feature flags and settings
- Non-sensitive configuration files
- Environment-specific settings

### ✅ Secrets  
- Passwords and API keys
- TLS certificates
- OAuth tokens
- Any sensitive data

### ❌ Neither (External Solutions)
- Frequently rotating secrets
- Secrets shared across multiple clusters
- Complex secret workflows
- Compliance requirements (SOC2, PCI)

## Key Insights

**Configuration should be external to your application** - enables the same image to run in different environments

**Use ConfigMaps for settings, Secrets for sensitive data** - clear separation of concerns

**Base64 encoding is not encryption** - Secrets are just slightly obfuscated, not truly encrypted

**Environment variables are the simplest pattern** - files are useful for complex configuration

**Update configuration without rebuilding** - change ConfigMap/Secret, restart pods to reload

**Consider external secret management for production** - Kubernetes Secrets are basic, external tools provide more features