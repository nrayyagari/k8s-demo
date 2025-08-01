# Pod Security Standards: Container Runtime Security

## WHY Pod Security Standards Exist

**Problem**: Containers can run with dangerous privileges, escape to host, or access sensitive resources  
**Solution**: Standardized security policies that control pod and container security contexts

## The Fundamental Question

**How do I prevent containers from doing dangerous things at runtime?**

Answer: Pod Security Standards define three security profiles (Privileged, Baseline, Restricted) that control security contexts

## Core Concepts: First Principles

### Security Context Hierarchy
1. **Pod Security Context**: Applies to all containers in the pod
2. **Container Security Context**: Overrides pod-level settings for specific containers
3. **Security Standards**: Predefined security profiles with specific restrictions

### The Three Security Profiles

**Privileged** (Least Secure):
- No restrictions applied
- Allows known privilege escalations
- For system workloads and infrastructure

**Baseline** (Default Security):
- Minimal restrictions that prevent known privilege escalations
- Allows most common workload patterns
- Good balance of security and usability

**Restricted** (Most Secure):
- Heavily restricted profile
- Follows current pod hardening best practices
- May require application changes

## Understanding Security Context Controls

### User and Group IDs
```yaml
securityContext:
  runAsUser: 1000        # Run as specific user ID
  runAsGroup: 1000       # Run as specific group ID
  runAsNonRoot: true     # Prevent running as root
  fsGroup: 2000          # Group ownership for volumes
```

### Privilege Controls
```yaml
securityContext:
  privileged: false            # No privileged containers
  allowPrivilegeEscalation: false  # No privilege escalation
  capabilities:
    drop:
    - ALL                      # Drop all capabilities
    add:
    - NET_BIND_SERVICE         # Add specific capabilities only
```

### File System Controls
```yaml
securityContext:
  readOnlyRootFilesystem: true  # Read-only root filesystem
  fsGroup: 2000                 # Group for volume ownership
  fsGroupChangePolicy: "OnRootMismatch"  # When to change ownership
```

### Seccomp and SELinux/AppArmor
```yaml
securityContext:
  seccompProfile:
    type: RuntimeDefault       # Use default seccomp profile
  seLinuxOptions:
    level: "s0:c123,c456"     # SELinux context
  appArmorProfile:
    type: RuntimeDefault       # AppArmor profile
```

## Pod Security Standards Implementation

### Method 1: Pod Security Admission Controller (Recommended)
Built into Kubernetes 1.23+ - enforces standards at namespace level

### Method 2: Pod Security Policies (Deprecated)
Legacy approach, removed in Kubernetes 1.25

### Method 3: External Admission Controllers
OPA Gatekeeper, Falco, Admission webhooks

## Pod Security Admission Controller

### Namespace-Level Enforcement
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: secure-namespace
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Three Enforcement Modes

**enforce**: Violating pods are rejected  
**audit**: Violations are logged but pods are allowed  
**warn**: Violations generate warnings but pods are allowed

### Gradual Migration Strategy
```yaml
# Step 1: Start with warnings
pod-security.kubernetes.io/warn: baseline

# Step 2: Add auditing
pod-security.kubernetes.io/audit: baseline

# Step 3: Enforce when ready
pod-security.kubernetes.io/enforce: baseline

# Step 4: Move to restricted
pod-security.kubernetes.io/enforce: restricted
```

## Common Security Context Patterns

### 1. Non-Root User Pattern
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65534  # nobody user
  runAsGroup: 65534
```

### 2. Read-Only Root Filesystem
```yaml
securityContext:
  readOnlyRootFilesystem: true
# Mount tmpfs for writable directories
volumeMounts:
- name: tmp
  mountPath: /tmp
volumes:
- name: tmp
  emptyDir: {}
```

### 3. Minimal Capabilities
```yaml
securityContext:
  capabilities:
    drop:
    - ALL
    add:
    - NET_BIND_SERVICE  # Only if needed for port 80/443
```

### 4. Seccomp Security
```yaml
securityContext:
  seccompProfile:
    type: RuntimeDefault  # Use CRI default seccomp profile
```

## Profile Requirements Matrix

| Control | Privileged | Baseline | Restricted |
|---------|------------|----------|------------|
| `privileged` | Allowed | Forbidden | Forbidden |
| `hostNetwork` | Allowed | Forbidden | Forbidden |
| `hostPID` | Allowed | Forbidden | Forbidden |
| `hostIPC` | Allowed | Forbidden | Forbidden |
| `hostPath` | Allowed | Forbidden | Forbidden |
| `runAsNonRoot` | Ignored | Ignored | Required |
| `runAsUser` | Ignored | Ignored | Must be > 0 |
| `allowPrivilegeEscalation` | Allowed | Must be false | Must be false |
| `capabilities` | Allowed | Limited | Drop ALL |
| `seccompProfile` | Ignored | Ignored | Required |
| `readOnlyRootFilesystem` | Ignored | Ignored | Required |
| Volume Types | All | Restricted | Very Restricted |

## Enterprise Compliance Mapping

### PCI DSS Requirements
- Use Restricted profile for payment processing workloads
- Read-only root filesystems
- Non-root execution
- Minimal capabilities

### SOC 2 Compliance
- Baseline profile minimum
- Audit logging enabled
- Regular security context reviews
- Documented security policies

### NIST Guidelines
- Defense in depth with multiple security layers
- Principle of least privilege
- Regular security assessments

## Learning Path

### 1. Understand Current Security Posture
```bash
kubectl apply -f 01-security-context-demo.yaml
```

### 2. Implement Baseline Security
```bash
kubectl apply -f 02-baseline-security.yaml
```

### 3. Apply Restricted Profile
```bash
kubectl apply -f 03-restricted-security.yaml
```

### 4. Namespace-Level Enforcement
```bash
kubectl apply -f 04-namespace-enforcement.yaml
```

### 5. Migration Strategy
```bash
kubectl apply -f 05-migration-strategy.yaml
```

### 6. Production Security Hardening
```bash
kubectl apply -f 06-production-hardening.yaml
```

## Common Issues and Solutions

### 1. Application Writes to Root Filesystem
**Problem**: `readOnlyRootFilesystem: true` breaks app
**Solution**: Mount emptyDir volumes for writable directories

### 2. Application Requires Root User
**Problem**: `runAsNonRoot: true` fails
**Solution**: Modify Dockerfile to create non-root user

### 3. Application Needs Network Binding
**Problem**: Port 80/443 requires capabilities
**Solution**: Add `NET_BIND_SERVICE` capability or use port > 1024

### 4. Legacy Applications
**Problem**: Cannot modify application
**Solution**: Start with Baseline profile, gradually migrate

## Testing and Validation

### Test Security Context
```bash
# Check if pod runs as expected user
kubectl exec -it <pod-name> -- id

# Verify read-only filesystem
kubectl exec -it <pod-name> -- touch /test-file

# Check capabilities
kubectl exec -it <pod-name> -- capsh --print

# Verify non-root execution
kubectl exec -it <pod-name> -- whoami
```

### Audit Violations
```bash
# View audit logs for violations
kubectl get events --field-selector reason=FailedCreate

# Check namespace security labels
kubectl get namespace <namespace> -o yaml | grep pod-security

# View pod security context
kubectl get pod <pod-name> -o yaml | grep -A20 securityContext
```

## Best Practices

### 1. Start with Warnings
Always begin migration with `warn` mode to understand impact

### 2. Use Least Privilege
Start with Restricted profile and relax only as needed

### 3. Implement Gradually
```bash
# Week 1: Add warnings
# Week 2: Add auditing  
# Week 3: Enforce baseline
# Week 4: Move to restricted
```

### 4. Document Exceptions
When you must relax security, document why and review regularly

### 5. Regular Security Reviews
Audit security contexts quarterly, update as needed

## Real-World Impact

**Security incidents**: Prevents container escapes and privilege escalation
**Compliance**: Meets regulatory requirements for container security
**Defense in depth**: Adds runtime security layer beyond image scanning
**Operational safety**: Prevents accidental dangerous configurations

## The 90/10 Rule Applied

**90% of use cases**: Baseline profile with minor adjustments
- Use: Standard web applications, APIs, batch jobs

**10% of use cases**: Privileged access for system workloads
- Use: Infrastructure pods, monitoring agents, CNI pods

## Key Questions

**1. What problem does this solve?**
- Prevents containers from escaping isolation
- Reduces attack surface of containerized applications
- Provides standardized security baseline

**2. What would happen without it?**
- Containers could run with dangerous privileges
- Easy path to host system compromise
- No consistent security standards

**3. How does this connect to fundamentals?**
- Built on Linux security primitives (capabilities, namespaces, cgroups)
- Follows defense in depth security strategy
- Implements principle of least privilege

## Connection to Container Security Ecosystem

Pod Security Standards work with:
1. **Image Security**: Scan images for vulnerabilities
2. **Network Security**: Network policies control traffic
3. **Runtime Security**: Falco, Aqua for runtime monitoring
4. **Admission Control**: OPA Gatekeeper for policy enforcement
5. **RBAC**: Control who can create pods with specific security contexts