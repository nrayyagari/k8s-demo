# Services: Connect to Your Apps

## WHY Do Services Exist?

**Problem**: Pod IPs change when pods restart, can't hardcode connections  
**Solution**: Service provides stable endpoint that automatically routes to healthy pods

## The Core Question

**"How do I connect to my app when pod IPs keep changing?"**

Direct pod connection: Pod restarts → IP changes → connection breaks  
Service connection: Pod restarts → Service updates automatically → connection stays stable

## The Three Service Types

### 1. ClusterIP (Internal Only)
**Use case**: Internal communication between services
```yaml
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  type: ClusterIP  # Default type
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 8080
```

### 2. NodePort (External Access)  
**Use case**: Simple external access for development/testing
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  type: NodePort
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080  # Access via any-node-ip:30080
```

### 3. LoadBalancer (Production External)
**Use case**: Production external access with cloud load balancer
```yaml
apiVersion: v1
kind: Service
metadata:
  name: prod-service
spec:
  type: LoadBalancer  # Cloud provider creates LB
  selector:
    app: prod-app
  ports:
  - port: 80
    targetPort: 8080
```

## Service Discovery Magic

### DNS Names
Every service gets automatic DNS names:
```bash
# Within same namespace
http://api-service

# Cross-namespace  
http://api-service.production.svc.cluster.local

# Short form cross-namespace
http://api-service.production
```

### Environment Variables
Kubernetes injects service info as environment variables:
```bash
API_SERVICE_HOST=10.96.0.10
API_SERVICE_PORT=80
```

## Port Mapping Explained

```yaml
ports:
- port: 80          # Service listens on port 80
  targetPort: 8080  # Forwards to pod port 8080
  nodePort: 30080   # External port (NodePort only)
```

**Traffic Flow**: External:30080 → Service:80 → Pod:8080

## How Services Find Pods

### Label Selectors
```yaml
# Service selector
spec:
  selector:
    app: web-app
    version: v1

# Pod labels (must match)
metadata:
  labels:
    app: web-app
    version: v1
```

**Rule**: Service selector must match pod labels exactly

### Endpoints
```bash
# See which pods service routes to
kubectl get endpoints my-service

# Example output:
NAME         ENDPOINTS                     AGE
my-service   10.244.1.5:80,10.244.2.3:80  5m
```

## Load Balancing

Services automatically load balance across healthy pods:
```
Request 1 → Pod A
Request 2 → Pod B  
Request 3 → Pod C
Request 4 → Pod A (round-robin)
```

**Health Integration**: Unhealthy pods automatically removed from load balancing

## Files in This Directory

1. **SIMPLE-SERVICE.yaml** - Complete beginner guide with all service types
2. **01-clusterip-service.yaml** - Internal service example
3. **02-nodeport-service.yaml** - External access for development
4. **03-loadbalancer-service.yaml** - Production external access

## Quick Start

```bash
# Deploy service
kubectl apply -f SIMPLE-SERVICE.yaml

# Check service
kubectl get services
kubectl describe service my-service

# Test internal connectivity
kubectl run test-pod --image=busybox --rm -it -- sh
# Inside pod: wget -qO- http://my-service
```

## Service Types Deep Dive

### ClusterIP (90% of use cases)
```
┌─────────────────┐
│   Other Pods    │ ──► ClusterIP Service ──► Your Pods
└─────────────────┘     (10.96.0.10:80)      (Multiple)
```

**When to use**: Internal API calls, database connections, microservice communication

### NodePort (Development/Testing)
```
External User ──► Any Node:30080 ──► NodePort Service ──► Your Pods
   (Internet)      (Node IP)         (Cluster IP)        (Multiple)
```

**When to use**: Quick external access, development, demos
**Limitations**: Port range 30000-32767, no load balancing to nodes

### LoadBalancer (Production)
```
External User ──► Cloud LB ──► NodePort ──► Service ──► Your Pods
   (Internet)      (External IP)  (Random)   (Cluster)  (Multiple)
```

**When to use**: Production external access, automatic load balancing
**Requirements**: Cloud provider (AWS, GCP, Azure)

## Advanced Patterns

### Headless Services
```yaml
spec:
  clusterIP: None  # No cluster IP assigned
  selector:
    app: database
```
**Use case**: Direct pod-to-pod communication (StatefulSets)

### External Services
```yaml
# Connect to external database
spec:
  type: ExternalName
  externalName: my-database.company.com
```

### Multiple Ports
```yaml
ports:
- name: http
  port: 80
  targetPort: 8080
- name: metrics  
  port: 9090
  targetPort: 9090
```

## Common Operations

### Troubleshooting Connectivity
```bash
# Check service exists
kubectl get service my-service

# Check endpoints (are pods healthy?)
kubectl get endpoints my-service

# Test from inside cluster
kubectl run debug --image=busybox --rm -it -- sh
# wget -qO- http://my-service

# Check service configuration
kubectl describe service my-service
```

### Service Not Working Checklist
1. **Labels match?** `kubectl get pods --show-labels`
2. **Pods healthy?** `kubectl get pods`
3. **Endpoints exist?** `kubectl get endpoints`
4. **Port correct?** `kubectl describe service`
5. **DNS working?** `nslookup my-service` from inside pod

## Best Practices

### Naming
```yaml
# Good service names
api-service
user-database
payment-gateway

# Bad service names  
service1
my-svc
app
```

### Port Configuration
```yaml
# Always name your ports
ports:
- name: http      # Clear purpose
  port: 80
  targetPort: 8080
- name: metrics
  port: 9090
  targetPort: 9090
```

### Health Checks
Services work best with proper health checks:
```yaml
# In your deployment
readinessProbe:
  httpGet:
    path: /health
    port: 8080
# Unhealthy pods automatically removed from service
```

## When Services Aren't Enough

### Need HTTP Routing?
Use **Ingress** for:
- Host-based routing (`api.company.com`)
- Path-based routing (`company.com/api`)
- SSL termination
- Multiple services behind one IP

### Need TCP/UDP Load Balancing?
Consider:
- **MetalLB** for bare-metal clusters
- **Cloud provider** load balancers
- **External load balancers** (HAProxy, nginx)

## Key Insights

**Services are the foundation of Kubernetes networking** - almost every communication goes through a service

**ClusterIP for internal, LoadBalancer for external** - NodePort is mainly for development

**Labels connect everything** - service selectors must match pod labels exactly

**DNS makes services discoverable** - use service names instead of IPs

**Services provide load balancing automatically** - no additional configuration needed

**Health checks integrate seamlessly** - unhealthy pods are automatically excluded