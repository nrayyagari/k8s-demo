# Kubernetes Examples Collection

This directory contains organized Kubernetes YAML examples covering the main resource types and concepts.

## Directory Structure

```
k8s-examples/
├── deployments/     # Deployment examples
├── services/        # Service examples (ClusterIP, NodePort, LoadBalancer)
├── statefulsets/    # StatefulSet examples
├── daemonsets/      # DaemonSet examples
├── pdbs/           # Pod Disruption Budget examples
└── README.md       # This file
```

## Quick Reference

### Deployments
- **Use case**: Stateless applications (web servers, APIs, microservices)
- **Features**: Rolling updates, scaling, self-healing
- **Pod names**: Random (webapp-abc123-def456)

### Services
- **ClusterIP**: Internal cluster communication only
- **NodePort**: External access via NodeIP:Port
- **LoadBalancer**: External access via cloud provider load balancer

### StatefulSets
- **Use case**: Stateful applications (databases, message queues)
- **Features**: Persistent identity, ordered deployment, persistent storage
- **Pod names**: Predictable (database-0, database-1, database-2)

### DaemonSets
- **Use case**: Node-level services (logging, monitoring, networking)
- **Features**: One pod per node, automatic scaling with cluster
- **Common examples**: Log collectors, monitoring agents, network plugins

### Pod Disruption Budgets (PDB)
- **Use case**: Maintain availability during voluntary disruptions
- **Features**: Prevents too many pods from being unavailable
- **Protection**: Node maintenance, cluster upgrades, rolling updates

## Usage Examples

### Deploy a basic web application:
```bash
kubectl apply -f deployments/01-basic-deployment.yaml
kubectl apply -f services/01-clusterip-service.yaml
```

### Deploy a database with persistent storage:
```bash
kubectl apply -f statefulsets/02-database-statefulset.yaml
```

### Deploy a log collector on all nodes:
```bash
kubectl apply -f daemonsets/01-log-collector-daemonset.yaml
```

### Protect your application with PDB:
```bash
kubectl apply -f pdbs/01-webapp-pdb.yaml
```

## Key Concepts Demonstrated

### Labels and Selectors
All examples use `app: <name>` labels to connect services to pods:
```yaml
# Pod template
labels:
  app: webapp

# Service selector
selector:
  app: webapp
```

### Port Mapping
Services route traffic through three port types:
- **port**: Service listens on this port
- **targetPort**: Pod container port
- **nodePort**: External port on nodes (NodePort only)

### Persistent Storage
StatefulSets use `volumeClaimTemplates` to create unique storage per pod:
- `data-database-0` for `database-0`
- `data-database-1` for `database-1`
- `data-database-2` for `database-2`

### Node Selection
DaemonSets include tolerations to run on control plane nodes:
```yaml
tolerations:
- key: node-role.kubernetes.io/control-plane
  operator: Exists
  effect: NoSchedule
```

## Commands for Testing

### Check resource status:
```bash
kubectl get deployments
kubectl get services
kubectl get statefulsets
kubectl get daemonsets
kubectl get pdb
```

### View pod distribution:
```bash
kubectl get pods -o wide
```

### Test service connectivity:
```bash
kubectl exec -it <pod-name> -- curl <service-name>
```

### Check PDB status:
```bash
kubectl get pdb <pdb-name>
```

## Clean Up

Remove all resources:
```bash
kubectl delete -f deployments/
kubectl delete -f services/
kubectl delete -f statefulsets/
kubectl delete -f daemonsets/
kubectl delete -f pdbs/
```

## Notes

- All examples use standard images (nginx, postgres, busybox)
- Resource limits are set for production readiness
- Comments explain key concepts inline
- Files are numbered for learning progression