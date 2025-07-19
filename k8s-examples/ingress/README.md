# Ingress: Get Traffic to Your Apps

## WHY Does Ingress Exist?

**Problem**: You have 5 web apps in Kubernetes. Each needs external access.  
**Without Ingress**: 5 LoadBalancers = $$$$ + complex management  
**With Ingress**: 1 LoadBalancer + smart routing = $ + simple

## The Core Question

**"How do external users reach my apps inside Kubernetes?"**

Answer: Route traffic through a single entry point based on URL patterns.

## The Three Components

### 1. **Ingress Controller** (The Engine)
- Actual software that implements routing (nginx, traefik, etc.)
- Runs as pods in your cluster
- Reads ingress rules and configures itself

### 2. **Ingress Resource** (The Rules)  
- Kubernetes configuration defining routing logic
- Tells controller "send traffic for api.example.com to api-service"

### 3. **Ingress Rules** (The Logic)
- Host-based routing: `app1.com` → service1
- Path-based routing: `/api` → api-service

## Traffic Flow

```
Internet Request: http://myapp.local/
            ↓
    [Ingress Controller] (nginx pod)
            ↓
    Reads Ingress Rules:
    "myapp.local → frontend-service"
            ↓
    [frontend-service] (ClusterIP)
            ↓
    [frontend-app pods]
```

## Key Pattern: ClusterIP + Ingress

**Step 1**: Create services with `type: ClusterIP` (internal only)
**Step 2**: Create ingress rules pointing to those services

```yaml
# Service (internal only)
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
spec:
  type: ClusterIP  # No external access
  selector:
    app: my-app
  ports:
  - port: 80

# Ingress (routes external traffic to service)
apiVersion: networking.k8s.io/v1
kind: Ingress
spec:
  rules:
  - host: myapp.com
    http:
      paths:
      - path: /
        backend:
          service:
            name: my-app-service  # Points to ClusterIP
            port:
              number: 80
```

## Examples in This Directory

### Basic Setup
1. **01-ingress-controller.yaml** - Deploy nginx ingress controller
2. **02-sample-apps.yaml** - Create sample apps with ClusterIP services
3. **03-basic-ingress.yaml** - Basic host and path routing
4. **04-tls-ingress.yaml** - HTTPS/SSL termination

## Quick Start

```bash
# 1. Setup ingress controller
kubectl apply -f 01-ingress-controller.yaml

# 2. Deploy sample applications  
kubectl apply -f 02-sample-apps.yaml

# 3. Create ingress rules
kubectl apply -f 03-basic-ingress.yaml

# 4. Test (add to /etc/hosts first)
curl http://myapp.local
curl http://api.local/api
```

## Testing Locally

Add to `/etc/hosts`:
```
127.0.0.1 myapp.local
127.0.0.1 api.local
127.0.0.1 secure.myapp.local
```

## Path Types

- **Prefix**: `/api` matches `/api/users`, `/api/posts`
- **Exact**: `/health` matches only `/health`
- **ImplementationSpecific**: Controller-dependent behavior

## Why Not LoadBalancer for Each Service?

❌ **LoadBalancer per service**:
- Expensive (cloud provider cost per LB)
- Multiple public IPs to manage
- No HTTP routing features

✅ **Single Ingress**:
- One LoadBalancer for ingress controller
- Smart HTTP routing (host, path, headers)
- SSL termination
- Rate limiting, authentication

## Common Annotations

```yaml
annotations:
  # Nginx-specific
  nginx.ingress.kubernetes.io/rewrite-target: /
  nginx.ingress.kubernetes.io/ssl-redirect: "false"
  nginx.ingress.kubernetes.io/rate-limit: "100"
  
  # Traefik-specific  
  traefik.ingress.kubernetes.io/router.middlewares: auth@file
```

## Troubleshooting

```bash
# Check ingress controller pods
kubectl get pods -n ingress-nginx

# Check ingress resources
kubectl get ingress

# Describe ingress for events
kubectl describe ingress basic-web-ingress

# Check service endpoints
kubectl get endpoints frontend-service
```

## Clean Up

```bash
kubectl delete -f .
kubectl delete namespace ingress-nginx
```