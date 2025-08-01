# Kubernetes API: Direct Cluster Control

## WHY Do You Need to Understand the Kubernetes API?

**Problem**: kubectl is convenient but limited; production automation needs direct API access  
**Solution**: Kubernetes API provides programmatic access to all cluster operations and resources

## The Core Question

**"How do I interact with Kubernetes programmatically for automation, monitoring, and custom tooling?"**

Without API knowledge: Limited to kubectl commands, no automation, manual operations  
With API knowledge: Custom controllers, automation scripts, monitoring tools, CI/CD integration

## API Structure Fundamentals

### API Groups and Versions
```
/api/v1                          # Core API group (legacy)
/apis/apps/v1                    # apps API group
/apis/networking.k8s.io/v1       # networking API group
/apis/batch/v1                   # batch API group
/apis/apiextensions.k8s.io/v1    # CRD API group
```

### Basic API Object Structure
```yaml
apiVersion: apps/v1    # API group and version
kind: Deployment       # Resource type
metadata:             # Object metadata
  name: my-app
  namespace: default
spec:                 # Desired state
  replicas: 3
status:               # Current state (read-only)
  replicas: 3
  readyReplicas: 3
```

### Common API Endpoints
```bash
# Core resources (pods, services)
/api/v1/namespaces/{namespace}/pods
/api/v1/namespaces/{namespace}/services

# Apps resources (deployments)
/apis/apps/v1/namespaces/{namespace}/deployments

# Cluster-scoped resources
/api/v1/nodes
/api/v1/persistentvolumes
```

## Files in This Directory

1. **SIMPLE-KUBERNETES-API.yaml** - Basic API interaction examples and patterns
2. **01-api-discovery.yaml** - API exploration and discovery techniques
3. **02-direct-api-calls.yaml** - HTTP API calls with curl and authentication
4. **03-custom-resources.yaml** - CRDs and custom API resources

## Quick Start

```bash
# Start kubectl proxy for API access
kubectl proxy --port=8080 &

# Explore API endpoints
curl http://localhost:8080/api/v1
curl http://localhost:8080/apis/apps/v1

# List resources
curl http://localhost:8080/api/v1/namespaces/default/pods
curl http://localhost:8080/apis/apps/v1/namespaces/default/deployments

# Apply YAML examples
kubectl apply -f SIMPLE-KUBERNETES-API.yaml
```

## API Discovery and Exploration

### Find Available Resources
```bash
# List all API groups and resources
kubectl api-resources

# List API versions
kubectl api-versions

# Get resource details
kubectl explain deployment
kubectl explain deployment.spec

# Server capabilities
kubectl version
kubectl cluster-info
```

## Direct API Access Patterns

### Basic CRUD Operations
```bash
# CREATE - POST resource
curl -X POST \
  http://localhost:8080/api/v1/namespaces/default/pods \
  -H "Content-Type: application/yaml" \
  -d @pod.yaml

# READ - GET resource
curl http://localhost:8080/api/v1/namespaces/default/pods/my-pod

# UPDATE - PATCH resource
curl -X PATCH \
  http://localhost:8080/api/v1/namespaces/default/pods/my-pod \
  -H "Content-Type: application/merge-patch+json" \
  -d '{"metadata":{"labels":{"version":"2.0"}}}'

# DELETE - Remove resource
curl -X DELETE \
  http://localhost:8080/api/v1/namespaces/default/pods/my-pod
```

### Query and Filtering
```bash
# Label selectors
curl "http://localhost:8080/api/v1/namespaces/default/pods?labelSelector=app=nginx"

# Field selectors  
curl "http://localhost:8080/api/v1/namespaces/default/pods?fieldSelector=status.phase=Running"

# Watch for changes
curl "http://localhost:8080/api/v1/namespaces/default/pods?watch=true"
```

## Authentication Methods

### Service Account (In-Cluster)
```bash
# Use service account token
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl -H "Authorization: Bearer $TOKEN" \
  https://kubernetes.default.svc/api/v1/namespaces/default/pods
```

### External Access
```bash
# Use kubeconfig credentials
kubectl config view --raw --minify

# Client certificates
curl --cert client.crt --key client.key --cacert ca.crt \
  https://kubernetes-api:6443/api/v1/namespaces
```

## Programming with the API

### Python Client Example
```python
from kubernetes import client, config

# Load kubeconfig
config.load_kube_config()
v1 = client.CoreV1Api()

# List all pods
pods = v1.list_pod_for_all_namespaces()
for pod in pods.items:
    print(f"{pod.metadata.name} in {pod.metadata.namespace}")

# Watch pod events
import watch
w = watch.Watch()
for event in w.stream(v1.list_namespaced_pod, namespace="default"):
    print(f"Event: {event['type']} Pod: {event['object'].metadata.name}")
```

### Watch API for Real-time Events
```bash
# Watch pods (HTTP streaming)
curl -N "http://localhost:8080/api/v1/namespaces/default/pods?watch=true"

# Watch with kubectl
kubectl get pods --watch
kubectl get events --watch
```

## Custom Resources

### Simple CRD Example
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: webapps.example.com
spec:
  group: example.com
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              replicas:
                type: integer
              image:
                type: string
              port:
                type: integer
  scope: Namespaced
  names:
    plural: webapps
    singular: webapp
    kind: WebApp
```

### Using Custom Resources
```yaml
apiVersion: example.com/v1
kind: WebApp
metadata:
  name: my-webapp
spec:
  replicas: 3
  image: nginx:1.21
  port: 80
```

## Common Operations

### Testing API Access
```bash
# Check permissions
kubectl auth can-i create pods
kubectl auth can-i list nodes

# Test with service account
kubectl auth can-i get pods --as=system:serviceaccount:default:my-sa
```

### Debugging API Issues
```bash
# Check API server health
kubectl get --raw='/healthz'

# View API server logs
kubectl logs -n kube-system kube-apiserver-master-1

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

## Best Practices

### Efficient API Usage
```python
# Good: Use selectors to filter server-side
pods = v1.list_namespaced_pod(
    namespace="default",
    label_selector="app=nginx"
)

# Bad: Get all pods then filter client-side
all_pods = v1.list_namespaced_pod(namespace="default")
nginx_pods = [pod for pod in all_pods.items 
             if pod.metadata.labels.get("app") == "nginx"]
```

### Security
```yaml
# Use least privilege service accounts
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: api-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]  # Only what's needed
```

### Error Handling
```python
try:
    result = v1.create_namespaced_pod(namespace="default", body=pod)
except client.rest.ApiException as e:
    if e.status == 409:
        print("Pod already exists")
    elif e.status == 403:
        print("Insufficient permissions")
    else:
        print(f"API error: {e}")
```

## API Usage Patterns

### ✅ Use API For:
- **Automation scripts** - CI/CD pipelines, deployment tools
- **Custom controllers** - Operators and custom logic
- **Monitoring systems** - Cluster metrics and health checks
- **Multi-cluster management** - Tools managing multiple clusters

### ❌ Don't Use API For:
- **Simple operations** → Use kubectl instead
- **One-off tasks** → kubectl is easier
- **Learning Kubernetes** → Start with kubectl first

## Key Insights

**The Kubernetes API is the foundation of everything** - kubectl, operators, and all tooling use the REST API

**Watch API enables real-time automation** - essential for controllers and monitoring systems

**Efficient API usage prevents cluster overload** - use selectors and pagination instead of polling

**Custom resources extend Kubernetes** - CRDs allow domain-specific APIs

**Security is built-in** - RBAC, admission controllers, and audit logging protect the cluster

**Authentication matters** - service accounts, tokens, and certificates control access