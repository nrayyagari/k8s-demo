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
4. **API Group** (WHERE RESOURCE LIVES): Core (""), apps, rbac.authorization.k8s.io

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

## **Production Security Crisis: Why RBAC Failures Matter**

### **Real-World Incident: Developer Deletes Production Database**
**What Happened**: Junior developer with cluster-admin access accidentally ran `kubectl delete namespace production` thinking it was staging  
**Business Impact**: 4-hour downtime, $500K revenue loss, regulatory fine  
**Root Cause**: Everyone had admin access "for convenience"  
**Prevention**: Proper RBAC with principle of least privilege

### **The Security Evolution in Kubernetes**
- **Early Kubernetes (2014-2016)**: No RBAC, everyone was cluster-admin
- **RBAC Introduction (2017)**: Fine-grained permissions, but complex to implement  
- **Current Enterprise (2024)**: Integrated with company LDAP/SSO, automated onboarding
- **Future Trend**: Zero-trust with just-in-time access and session recording

### **Critical Thinking: The Security vs Productivity Trade-off**

**Question**: "How restrictive should we be vs developer productivity?"

| Approach | Productivity | Security | Operational Overhead | When It Breaks |
|----------|--------------|----------|---------------------|----------------|
| **Cluster Admin** | Maximum | None | None | Data loss, compliance violations |
| **Namespace Admin** | High | Medium | Low | Cross-namespace resource access |
| **Role-Based** | Medium | High | Medium | Permission drift, complex debugging |
| **Just-in-Time** | Low initially | Maximum | High | Access approval delays |

**Enterprise Reality**: Most companies start permissive, then restrict after incidents

## Understanding API Groups

### WHY API Groups Exist
**Problem**: Kubernetes has hundreds of resource types - need organization  
**Solution**: Group related resources together (like directories in filesystem)

### **Business Context: Why API Groups Matter for Security**
- **Core group** ("") - pods, services - high-risk resources
- **apps** - deployments, StatefulSets - application lifecycle  
- **rbac.authorization.k8s.io** - security permissions - extremely sensitive
- **networking.k8s.io** - network policies - compliance requirements

### The API Group Structure
```
kubernetes.io/api/
├── core (legacy "")          # pods, services, configmaps, secrets
├── apps/v1                   # deployments, replicasets, statefulsets  
├── networking.k8s.io/v1      # ingresses, networkpolicies
├── rbac.authorization.k8s.io # roles, clusterroles, bindings
├── storage.k8s.io/v1         # storageclasses, volumeattachments
├── autoscaling/v1            # horizontalpodautoscalers
└── apiextensions.k8s.io/v1   # customresourcedefinitions
```

### Core API Group (Empty String)
```yaml
# Core resources use empty string ""
apiGroups: [""]
resources: ["pods", "services", "configmaps", "secrets", "nodes"]
```

### Named API Groups
```yaml
# Apps API group
apiGroups: ["apps"] 
resources: ["deployments", "replicasets", "statefulsets"]

# RBAC API group
apiGroups: ["rbac.authorization.k8s.io"]
resources: ["roles", "clusterroles", "rolebindings"]

# Networking API group  
apiGroups: ["networking.k8s.io"]
resources: ["ingresses", "networkpolicies"]
```

### Discovering API Groups and Resources

#### List all API groups:
```bash
kubectl api-resources --output=wide
kubectl api-versions
```

#### Find specific resource's API group:
```bash
# What API group contains deployments?
kubectl api-resources | grep deployments
# Output: deployments  deploy   apps/v1  true  Deployment

# What API group contains ingresses?
kubectl api-resources | grep ingress
# Output: ingresses    ing      networking.k8s.io/v1  true  Ingress
```

#### Check API group contents:
```bash
# List resources in core API group
kubectl api-resources --api-group=""

# List resources in apps API group
kubectl api-resources --api-group="apps"

# List resources in networking API group
kubectl api-resources --api-group="networking.k8s.io"
```

#### Explain resource details:
```bash
# Get full API details for a resource
kubectl explain pod
kubectl explain deployment
kubectl explain ingress

# See API version and group
kubectl explain deployment.apiVersion
```

### Common API Groups by Use Case

**Application Workloads**:
- `""` (core): pods, services, configmaps, secrets
- `apps`: deployments, replicasets, statefulsets, daemonsets

**Networking**:
- `""` (core): services, endpoints  
- `networking.k8s.io`: ingresses, networkpolicies

**Storage**:
- `""` (core): persistentvolumes, persistentvolumeclaims
- `storage.k8s.io`: storageclasses, volumeattachments

**Security & RBAC**:
- `rbac.authorization.k8s.io`: roles, clusterroles, rolebindings, clusterrolebindings

**Cluster Management**:
- `""` (core): nodes, namespaces
- `metrics.k8s.io`: node metrics, pod metrics

### RBAC Examples with API Groups

#### Multiple API groups in one role:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: developer-role
rules:
# Core API group (pods, services)
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "create", "update", "delete"]
# Apps API group (deployments)  
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "create", "update", "delete"]
# Networking API group (ingresses)
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "create", "update"]
```

#### Wildcard access to all API groups:
```yaml
# DANGEROUS: Access to everything
rules:
- apiGroups: ["*"]  # All API groups
  resources: ["*"]  # All resources
  verbs: ["*"]      # All actions
```

### Best Practices for API Groups

**1. Be Specific**: List exact API groups, avoid wildcards
```yaml
# Good: Specific API groups
apiGroups: ["", "apps", "networking.k8s.io"]

# Bad: Wildcard (too permissive)  
apiGroups: ["*"]
```

**2. Understand Resource Locations**: Know which API group contains what
```yaml
# pods are in core (""), not apps
apiGroups: [""]
resources: ["pods"]

# deployments are in apps, not core
apiGroups: ["apps"] 
resources: ["deployments"]
```

**3. Version Awareness**: API groups have versions
```bash
# Check available versions
kubectl api-versions | grep networking
# networking.k8s.io/v1
# networking.k8s.io/v1beta1
```

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

### Discover API groups and resources:
```bash
kubectl api-resources --output=wide
kubectl api-resources | grep -i <resource-name>
kubectl api-resources --api-group="apps"
kubectl explain <resource-type>
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