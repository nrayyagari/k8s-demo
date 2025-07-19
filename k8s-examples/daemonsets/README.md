# DaemonSets: Run One Pod Per Node

## WHY Do DaemonSets Exist?

**Problem**: Need monitoring, logging, or networking on every single node  
**Solution**: DaemonSet automatically runs exactly one pod per node

## The Core Question

**"How do I run something on every node in my cluster?"**

Manual approach: Deploy to each node individually → painful and error-prone  
DaemonSet approach: Define once → automatically runs everywhere

## Common Use Cases

### Node-Level Services
- **Log collection** (fluentd, filebeat)
- **Monitoring agents** (node-exporter, datadog-agent)  
- **Network plugins** (calico, flannel)
- **Security agents** (falco, twistlock)
- **Storage drivers** (ceph, gluster)

### The Pattern
```
Node 1: [log-collector-pod]
Node 2: [log-collector-pod] 
Node 3: [log-collector-pod]
Node 4: [log-collector-pod]
```

## Key Characteristics

### Automatic Scaling
- **Add node** → DaemonSet creates pod automatically
- **Remove node** → DaemonSet cleans up pod automatically
- **No manual intervention** required

### Node Access
```yaml
# DaemonSets typically need host access
volumeMounts:
- name: varlog
  mountPath: /var/log        # Read host logs
- name: proc  
  mountPath: /host/proc      # Read host metrics
- name: docker-socket
  mountPath: /var/run/docker.sock  # Monitor containers
```

## Simple Example

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
spec:
  selector:
    matchLabels:
      app: log-collector
  template:
    metadata:
      labels:
        app: log-collector
    spec:
      containers:
      - name: collector
        image: fluentd:latest
        volumeMounts:
        - name: varlog
          mountPath: /var/log
          readOnly: true
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      # Run on control plane nodes too
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
```

## Tolerations: The Key to Control Plane Access

### Why Tolerations?
Control plane nodes have **taints** that prevent normal pods from running there.  
DaemonSets often need tolerations to run everywhere.

```yaml
tolerations:
- key: node-role.kubernetes.io/control-plane
  operator: Exists
  effect: NoSchedule
- key: node.kubernetes.io/disk-pressure
  operator: Exists
  effect: NoSchedule
```

## Node Selection

### Run on Specific Nodes
```yaml
nodeSelector:
  node-type: worker    # Only worker nodes

# OR use node affinity for complex rules
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
```

## Files in This Directory

1. **01-log-collector-daemonset.yaml** - Basic log collection example

## Quick Start

```bash
# Deploy DaemonSet
kubectl apply -f 01-log-collector-daemonset.yaml

# Check pods on all nodes
kubectl get pods -o wide

# Verify one pod per node
kubectl get daemonset
```

## Monitoring DaemonSets

```bash
# Check DaemonSet status
kubectl get daemonsets
kubectl describe daemonset log-collector

# See which nodes have pods
kubectl get pods -l app=log-collector -o wide

# Check if any nodes are missing pods
kubectl get nodes
```

## Common Patterns

### Host Network Access
```yaml
spec:
  hostNetwork: true  # Use host networking
  dnsPolicy: ClusterFirstWithHostNet
```

### Privileged Access
```yaml
securityContext:
  privileged: true  # Full host access (use carefully!)
```

### Resource Limits
```yaml
resources:
  limits:
    memory: "200Mi"
    cpu: "100m"
  requests:
    memory: "100Mi" 
    cpu: "50m"
```

## When NOT to Use DaemonSets

❌ **Application workloads** → Use Deployments  
❌ **Single-node needs** → Use regular pods  
❌ **Batch processing** → Use Jobs  
❌ **User-facing services** → Use Deployments + Services

✅ **System-level services** that need to run on every node  
✅ **Infrastructure components** (monitoring, logging, networking)  
✅ **Security agents** that monitor host activity

## Key Insights

**DaemonSets follow the node lifecycle** - they scale with your cluster automatically

**Host access comes with responsibility** - be careful with privileged containers

**Tolerations are usually required** - to run on control plane nodes

**One pod per node, always** - no replicas concept like Deployments

## Troubleshooting

```bash
# Pod not running on some nodes
kubectl describe daemonset log-collector
# Check: node selectors, tolerations, resource constraints

# Pod can't access host resources  
kubectl logs -l app=log-collector
# Check: volume mounts, security context, host paths

# DaemonSet not updating
kubectl rollout status daemonset/log-collector
# Check: update strategy, pod disruption budgets
```

DaemonSets are the "set it and forget it" solution for node-level services - deploy once, runs everywhere automatically.