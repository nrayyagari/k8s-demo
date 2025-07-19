# RBAC: Roles and ClusterRoles

## WHY RBAC Exists

**Problem**: Without RBAC, everyone has cluster admin access - massive security risk  
**Solution**: Fine-grained permissions using principle of least privilege

## The Fundamental Question

**How do I control WHO can do WHAT in my cluster?**

Answer: Roles + RoleBindings (namespace-scoped) or ClusterRoles + ClusterRoleBindings (cluster-wide)

## Core Concepts: First Principles

### The RBAC Triplet
1. **Subject** (WHO): Users, Groups, ServiceAccounts
2. **Verb** (WHAT ACTION): get, list, create, update, delete, patch, watch
3. **Resource** (ON WHAT): pods, services, deployments, nodes, namespaces

### Role vs ClusterRole Decision Tree

```
Need access to cluster resources (nodes, namespaces, PVs)?
├─ YES → ClusterRole
└─ NO → Continue

Need same permissions across ALL namespaces?
├─ YES → ClusterRole  
└─ NO → Continue

Need permissions in ONE specific namespace?
└─ Role
```

## Key Distinction: Template vs Application

### Role/ClusterRole = Permission Template
Defines WHAT permissions exist (just a template, no targeting)

### RoleBinding/ClusterRoleBinding = WHERE Applied
Determines scope and WHO gets the permissions

## Pattern: ClusterRole + Different Bindings

**One ClusterRole, Multiple Use Cases**:
- `ClusterRoleBinding` → Apply to ALL namespaces
- `RoleBinding` → Apply to SPECIFIC namespace

## Learning Path

### 1. Basic Team Permissions (Role)
```bash
kubectl apply -f 01-team-role.yaml
```

### 2. Cross-Namespace CI/CD (ClusterRole + RoleBindings)
```bash
kubectl apply -f 02-ci-clusterrole.yaml
kubectl apply -f 03-ci-rolebindings.yaml
```

### 3. Platform Admin (ClusterRole + ClusterRoleBinding)
```bash
kubectl apply -f 04-platform-admin.yaml
```

### 4. Read-Only Monitoring (ClusterRole)
```bash
kubectl apply -f 05-monitoring-reader.yaml
```

## Resource Scope Reference

### Namespace-Scoped Resources
Use with Roles OR ClusterRoles:
- pods, services, deployments, configmaps, secrets
- replicasets, statefulsets, daemonsets
- persistentvolumeclaims (not PVs)

### Cluster-Scoped Resources  
REQUIRE ClusterRoles:
- nodes, namespaces, persistentvolumes
- storageclasses, clusterroles, clusterrolebindings
- customresourcedefinitions

## Common Enterprise Patterns

### Development Teams
- **Scope**: Single namespace per team
- **Pattern**: Role + RoleBinding
- **Resources**: pods, services, deployments, configmaps

### Platform Engineering
- **Scope**: Cluster-wide infrastructure
- **Pattern**: ClusterRole + ClusterRoleBinding  
- **Resources**: nodes, namespaces, storageclasses

### CI/CD Systems
- **Scope**: Multiple specific namespaces
- **Pattern**: ClusterRole + Multiple RoleBindings
- **Resources**: deployments, services (reusable template)

### Monitoring Systems
- **Scope**: Read-only access across cluster
- **Pattern**: ClusterRole + ClusterRoleBinding
- **Resources**: pods, nodes, services (metrics collection)

## Testing Commands

### Check permissions:
```bash
kubectl auth can-i create pods --as=system:serviceaccount:team-alpha:developer
kubectl auth can-i list nodes --as=system:serviceaccount:team-alpha:developer
```

### View role assignments:
```bash
kubectl get rolebindings -A
kubectl get clusterrolebindings
```

### Describe roles:
```bash
kubectl describe role developer -n team-alpha
kubectl describe clusterrole platform-admin
```

## Security Best Practices

### 1. Principle of Least Privilege
Grant minimum permissions needed for the job

### 2. Use ServiceAccounts for Applications
Never use User accounts for pods

### 3. Separate Roles by Function
- Developer: create/update applications
- Viewer: read-only access
- Admin: infrastructure management

### 4. Audit Regularly
```bash
kubectl get clusterrolebindings -o wide
kubectl auth can-i --list --as=system:serviceaccount:default:my-sa
```

## The 90/10 Rule Applied

**90% of use cases**: Namespace-scoped teams
- Use: Role + RoleBinding per namespace

**10% of use cases**: Cross-cutting concerns  
- Use: ClusterRole + appropriate binding strategy

## Key Questions

**1. What problem does this solve?**
- Prevents unauthorized access to sensitive resources
- Enables secure multi-tenancy
- Provides audit trail of permissions

**2. What would happen without it?**
- Everyone would have cluster admin access
- No isolation between teams/environments
- Security nightmare in production

**3. How does this connect to fundamentals?**
- Built on Kubernetes API groups and resources
- Uses standard HTTP verbs (GET, POST, PUT, DELETE)
- Follows declarative configuration pattern

## Real-World Impact

**Multi-tenant clusters**: Teams can't see each other's resources
**Compliance**: SOC2/PCI requirements for access control
**Security incidents**: Blast radius limited by permissions
**CI/CD automation**: Automated deployments with limited scope