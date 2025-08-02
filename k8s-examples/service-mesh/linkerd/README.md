# Linkerd: Ultra-Light Service Mesh for Production

## WHY Linkerd: Simplicity Meets Production Requirements

**Problem**: Need service mesh benefits without operational complexity  
**Solution**: Linkerd provides essential service mesh features with minimal resource overhead and zero configuration complexity

## Core Philosophy: Less is More

### **Linkerd Design Principles**
- **Simplicity**: Zero configuration mTLS, automatic proxy injection
- **Performance**: Rust-based proxy with <1ms latency overhead
- **Reliability**: Battle-tested in production with excellent stability record
- **Observability**: Rich metrics and monitoring out-of-the-box

### **When Linkerd is the Right Choice**
```yaml
Team Characteristics:
- Small to medium engineering teams (5-50 engineers)
- Want service mesh benefits without complexity
- Performance-sensitive applications
- Limited operational resources for service mesh management

Technical Requirements:
- Automatic mTLS for zero-trust security
- Service-to-service observability
- Basic traffic management (load balancing, retries)
- Minimal resource overhead critical
```

## **Production Installation Guide**

### **Prerequisites Check**
```bash
# Verify Kubernetes version (1.21+)
kubectl version --short

# Check cluster resource availability
kubectl top nodes
# Ensure at least 2GB available memory across cluster

# Verify cluster networking
kubectl get pods -A -o wide | grep -E "(coredns|kube-proxy)"
```

### **Install Linkerd CLI**
```bash
# Download and install Linkerd CLI
curl -sL https://run.linkerd.io/install | sh
export PATH=$PATH:$HOME/.linkerd2/bin

# Verify CLI installation
linkerd version
```

### **Pre-Installation Validation**
```bash
# Critical: Run pre-checks before installation
linkerd check --pre
# Must pass all checks before proceeding

# Common issues and resolutions:
# Issue: Clock skew detected
# Solution: Sync cluster node times
# Issue: Pod Security Policy enabled
# Solution: Create PSP for Linkerd (see production setup)
```

### **Production Installation with HA Control Plane**
```bash
# Generate installation manifests for review
linkerd install --ha > linkerd-install.yaml

# Review critical configurations
grep -A 5 -B 5 "resources:" linkerd-install.yaml
grep -A 10 "replicas:" linkerd-install.yaml

# Apply installation
kubectl apply -f linkerd-install.yaml

# Verify installation
linkerd check

# Install visualization dashboard (production optional)
linkerd viz install > linkerd-viz.yaml
kubectl apply -f linkerd-viz.yaml
linkerd viz check
```

## **Service Injection Strategies**

### **Automatic Injection (Recommended for Production)**
```yaml
# Enable automatic injection at namespace level
apiVersion: v1
kind: Namespace
metadata:
  name: production
  annotations:
    linkerd.io/inject: enabled
---
# All new deployments in this namespace get automatic injection
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: payment-service
  template:
    metadata:
      labels:
        app: payment-service
    spec:
      containers:
      - name: payment-service
        image: payment-service:v1.2.3
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

### **Manual Injection (Precise Control)**
```bash
# Inject specific deployments
kubectl get deploy payment-service -o yaml | linkerd inject - | kubectl apply -f -

# Inject with custom proxy configuration
kubectl get deploy payment-service -o yaml | \
  linkerd inject \
    --proxy-cpu-request=50m \
    --proxy-memory-request=64Mi \
    --proxy-cpu-limit=200m \
    --proxy-memory-limit=128Mi \
    - | kubectl apply -f -
```

### **Gradual Rollout Pattern**
```bash
# Phase 1: Non-critical services first
kubectl get deployments -n staging -o name | \
  xargs -I {} sh -c 'kubectl get {} -o yaml | linkerd inject - | kubectl apply -f -'

# Phase 2: Monitor for 24-48 hours
linkerd viz stat deployments -n staging --time-window=24h

# Phase 3: Production rollout (one service at a time)
for service in user-service product-service payment-service; do
  echo "Injecting $service..."
  kubectl get deploy $service -n production -o yaml | linkerd inject - | kubectl apply -f -
  echo "Waiting 15 minutes for stabilization..."
  sleep 900
  linkerd viz stat deploy/$service -n production
done
```

## **Production Observability**

### **Built-in Metrics Dashboard**
```bash
# Access Linkerd dashboard (production: use ingress or port-forward)
linkerd viz dashboard --port 8084

# Command-line observability
linkerd viz stat deployments --all-namespaces
linkerd viz stat deploy/payment-service --from deploy/order-service
linkerd viz routes svc/payment-service
```

### **Prometheus Integration**
```yaml
# Expose Linkerd metrics to external Prometheus
apiVersion: v1
kind: Service
metadata:
  name: linkerd-prometheus
  namespace: linkerd-viz
  labels:
    app: prometheus
spec:
  type: ClusterIP
  ports:
  - name: admin-http
    port: 9090
    protocol: TCP
    targetPort: 9090
  selector:
    linkerd.io/control-plane-component: prometheus
---
# ServiceMonitor for Prometheus Operator
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: linkerd-proxy
  namespace: linkerd-viz
spec:
  selector:
    matchLabels:
      linkerd.io/control-plane-component: prometheus
  endpoints:
  - port: admin-http
    interval: 30s
    path: /federate
    params:
      'match[]':
      - '{job="linkerd-proxy"}'
      - '{job="linkerd-controller"}'
```

### **Custom Grafana Dashboards**
```yaml
# Essential production dashboards
1. Service Success Rate Dashboard
   - Success rate by service over time
   - P99, P95, P50 latency percentiles
   - Request rate (RPS) by service

2. Service Dependency Dashboard  
   - Service topology with health status
   - Inter-service communication patterns
   - Error rate propagation analysis

3. Linkerd Health Dashboard
   - Control plane component health
   - Proxy resource usage across cluster
   - Certificate expiry monitoring
```

## **Traffic Management**

### **Load Balancing Algorithms**
```yaml
# Linkerd supports multiple load balancing algorithms
# Default: EWMA (Exponentially Weighted Moving Average)

# Override via annotation on service
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  annotations:
    # Options: round_robin, least_request, ring_hash, random
    balancer.linkerd.io/algorithm: least_request
spec:
  selector:
    app: payment-service
  ports:
  - port: 80
    targetPort: 8080
```

### **Retry Configuration**
```yaml
# Automatic retries for failed requests
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  annotations:
    # Retry budget: maximum % of requests that can be retried
    retry.linkerd.io/budget: "0.2"  # 20% of requests
    # Retry conditions
    retry.linkerd.io/response-statuses: "5xx"
    # Timeout for each retry attempt
    retry.linkerd.io/timeout: "1s"
spec:
  selector:
    app: payment-service
  ports:
  - port: 80
    targetPort: 8080
```

### **Traffic Splitting for Canary Deployments**
```yaml
# Install Linkerd SMI extension for traffic splitting
kubectl apply -f https://run.linkerd.io/install-smi

# Create traffic split for canary deployment
apiVersion: split.smi-spec.io/v1alpha1
kind: TrafficSplit
metadata:
  name: payment-service-canary
  namespace: production
spec:
  service: payment-service
  backends:
  - service: payment-service-stable
    weight: 90
  - service: payment-service-canary
    weight: 10
---
# Stable version service
apiVersion: v1
kind: Service
metadata:
  name: payment-service-stable
  namespace: production
spec:
  selector:
    app: payment-service
    version: stable
  ports:
  - port: 80
    targetPort: 8080
---
# Canary version service
apiVersion: v1
kind: Service
metadata:
  name: payment-service-canary
  namespace: production
spec:
  selector:
    app: payment-service
    version: canary
  ports:
  - port: 80
    targetPort: 8080
```

## **Security Configuration**

### **Automatic mTLS**
```bash
# Check mTLS status across services
linkerd viz edges deployments

# Verify specific service mTLS
linkerd viz stat deploy/payment-service --from deploy/order-service
# Look for "🔒" icon indicating mTLS is active

# Debug mTLS issues
linkerd viz tap deploy/payment-service | grep -E "(req|rsp)"
```

### **Pod Security Standards Integration**
```yaml
# Linkerd proxy security context (automatically applied)
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 2102  # linkerd-proxy user
  seccompProfile:
    type: RuntimeDefault
```

### **Network Policies for Defense in Depth**
```yaml
# Complement Linkerd mTLS with Kubernetes NetworkPolicies
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: payment-service-netpol
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: payment-service
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: order-service
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: user-service
    ports:
    - protocol: TCP
      port: 8080
  # Allow DNS resolution
  - to: []
    ports:
    - protocol: UDP
      port: 53
```

## **Production Troubleshooting**

### **Performance Issues**
```bash
# Scenario: Increased latency after Linkerd installation

# Step 1: Check proxy resource usage
kubectl top pods -A | grep linkerd-proxy

# Step 2: Analyze proxy performance
linkerd viz stat deploy --all-namespaces | sort -k4 -nr  # Sort by success rate
linkerd viz profile deploy/slow-service --time-window=1h

# Step 3: Tune proxy resources if needed
kubectl patch deployment slow-service -p '{
  "spec": {
    "template": {
      "metadata": {
        "annotations": {
          "config.linkerd.io/proxy-cpu-request": "100m",
          "config.linkerd.io/proxy-memory-request": "128Mi",
          "config.linkerd.io/proxy-cpu-limit": "500m",
          "config.linkerd.io/proxy-memory-limit": "256Mi"
        }
      }
    }
  }
}'
```

### **Certificate Issues**
```bash
# Scenario: mTLS failures between services

# Step 1: Check certificate health
linkerd check --proxy

# Step 2: Check identity controller
kubectl logs -n linkerd deploy/linkerd-identity

# Step 3: Verify certificate distribution
kubectl get secrets -A | grep linkerd-identity-token

# Step 4: Force certificate renewal (emergency)
kubectl delete secret -n linkerd linkerd-identity-issuer
kubectl rollout restart deployment/linkerd-identity -n linkerd
```

### **Proxy Injection Problems**
```bash
# Scenario: Services not getting injected properly

# Step 1: Check injection configuration
kubectl get namespace production -o yaml | grep inject

# Step 2: Verify webhook configuration
kubectl get mutatingwebhookconfiguration linkerd-proxy-injector -o yaml

# Step 3: Check admission controller logs
kubectl logs -n linkerd deploy/linkerd-proxy-injector

# Step 4: Manual injection for debugging
kubectl get deploy problematic-service -o yaml | linkerd inject --debug - > debug-injection.yaml
```

## **Upgrade Strategy**

### **Control Plane Upgrade**
```bash
# Check current version
linkerd version

# Download new version
curl -sL https://run.linkerd.io/install | sh

# Verify upgrade compatibility
linkerd check --pre
linkerd upgrade | kubectl apply --dry-run=client -f -

# Perform upgrade
linkerd upgrade | kubectl apply -f -

# Verify upgrade
linkerd check
```

### **Data Plane Upgrade**
```bash
# Automatic: Restart deployments to pick up new proxy version
kubectl rollout restart deployment -n production

# Manual: Re-inject specific deployments
kubectl get deploy payment-service -o yaml | linkerd inject - | kubectl apply -f -
```

## **Resource Planning**

### **Linkerd Resource Requirements**
```yaml
# Control Plane (per cluster)
linkerd-controller: 100m CPU, 50Mi memory
linkerd-identity: 10m CPU, 10Mi memory  
linkerd-proxy-injector: 100m CPU, 50Mi memory

# Data Plane (per pod)
linkerd-proxy: 10m CPU, 20Mi memory (typical)
# Scales with traffic: +1m CPU per 1000 RPS

# Total overhead calculation for 100-pod cluster:
# Control plane: ~200m CPU, 110Mi memory
# Data plane: ~1000m CPU, 2000Mi memory  
# Total: ~5% cluster overhead (very efficient)
```

### **Production Sizing Guidelines**
```yaml
# Small deployment (< 50 pods)
Proxy resources:
  requests: {cpu: 10m, memory: 20Mi}
  limits: {cpu: 100m, memory: 128Mi}

# Medium deployment (50-200 pods)  
Proxy resources:
  requests: {cpu: 20m, memory: 32Mi}
  limits: {cpu: 200m, memory: 256Mi}

# Large deployment (> 200 pods)
Proxy resources:
  requests: {cpu: 50m, memory: 64Mi}
  limits: {cpu: 500m, memory: 512Mi}
```

## **Best Practices Summary**

### **1. Installation**
- Always run `linkerd check --pre` before installation
- Use HA installation for production clusters
- Plan for gradual rollout, not big-bang deployment

### **2. Observability**
- Integrate with existing Prometheus/Grafana stack
- Set up alerts for certificate expiry and control plane health
- Monitor proxy resource usage and adjust as needed

### **3. Security**
- Leverage automatic mTLS but complement with NetworkPolicies
- Regular certificate rotation monitoring
- Use namespace-level injection for consistent security posture

### **4. Performance**
- Start with default proxy resources, tune based on observed usage
- Monitor Linkerd overhead and adjust cluster capacity accordingly
- Use `linkerd viz profile` for performance troubleshooting

**Remember**: Linkerd's strength is simplicity. Don't over-engineer—let Linkerd handle the complexity while you focus on your applications.