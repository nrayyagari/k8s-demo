# Network Policies: Zero-Trust Pod Security

## WHY Network Policies Are Critical for Production

**Problem**: By default, all pods can communicate with all other pods - zero network isolation  
**Solution**: Fine-grained network traffic control implementing zero-trust networking

## **Real-World Security Incident: The Kubernetes Lateral Movement Attack**

**What Happened**: Attacker compromised a frontend pod, moved laterally to database pods, exfiltrated customer data  
**Business Impact**: $2M fine, customer trust loss, regulatory investigation  
**Root Cause**: No network segmentation - compromised pod could access everything  
**Prevention**: Network policies implementing microsegmentation

### **The Security Evolution: From Perimeter to Zero-Trust**
- **Traditional (Firewall Era)**: Perimeter security, trusted internal network
- **Cloud (2010s)**: Security groups, subnet-level isolation
- **Container (2015+)**: Pod-level firewalls with Kubernetes Network Policies
- **Zero-Trust (Now)**: No implicit trust, verify every connection

## The Fundamental Questions

**Primary**: "How do I control WHICH pods can talk to WHICH other pods?"  
**Security**: "What happens when a pod gets compromised?"  
**Compliance**: "How do I prove network isolation for audit?"

**Answer**: Network Policies define ingress/egress rules based on pod selectors, namespaces, and IP blocks

## **Production Security Scenarios**

### **Scenario 1: Multi-Tenant SaaS Platform**
**Business Context**: Different customers must be completely isolated  
**Compliance**: SOC2, GDPR data isolation requirements  
**Implementation**: Namespace per tenant + strict network policies

### **Scenario 2: PCI DSS Compliance**  
**Business Context**: Payment processing application  
**Compliance**: Payment data must be network-isolated  
**Implementation**: Dedicated namespace with locked-down network policies

### **Scenario 3: Defense in Depth**
**Business Context**: Healthcare application with PHI data  
**Compliance**: HIPAA compliance requires network controls  
**Implementation**: Layer network policies with pod security policies

## Core Concepts: First Principles

### The Network Policy Triplet
1. **Pod Selection** (WHO): Which pods the policy applies to
2. **Traffic Direction** (WHAT): Ingress (incoming) and/or Egress (outgoing)  
3. **Allow Rules** (FROM/TO WHERE): Sources/destinations for allowed traffic

### Default Behavior vs Policy Behavior

**Without Network Policies**:
- All traffic allowed between all pods
- "Default Allow All" model
- Like having no firewall rules

**With Network Policies**:
- "Default Deny All" for selected pods
- Only explicitly allowed traffic passes
- Like enabling a firewall with specific rules

### Traffic Direction Understanding

```
┌─────────────┐    Ingress     ┌─────────────┐    Egress      ┌─────────────┐
│   Client    │  ──────────►   │  Your Pod   │  ──────────►   │  Database   │
│    Pod      │                │             │                │    Pod      │
└─────────────┘                └─────────────┘                └─────────────┘
                                      │
                               Policy applied here
                               (controls both directions)
```

**Ingress Rules**: Control traffic **TO** the selected pods  
**Egress Rules**: Control traffic **FROM** the selected pods

## Key Distinction: Pod Selection vs Traffic Rules

### podSelector = Target Pods
Defines which pods the policy applies to (the "protected" pods)

### Ingress/Egress Rules = Allowed Traffic
Defines what traffic is permitted to/from those protected pods

## Understanding Traffic Selectors

### 1. Pod-to-Pod (podSelector)
```yaml
# Allow traffic from pods with specific labels
from:
- podSelector:
    matchLabels:
      role: frontend
```

### 2. Namespace-to-Namespace (namespaceSelector)  
```yaml
# Allow traffic from specific namespaces
from:
- namespaceSelector:
    matchLabels:
      environment: production
```

### 3. External Traffic (ipBlock)
```yaml
# Allow traffic from external IP ranges
from:
- ipBlock:
    cidr: 192.168.1.0/24
    except:
    - 192.168.1.5/32
```

### 4. Combined Selectors (AND logic)
```yaml
# Allow traffic from frontend pods in production namespace
from:
- podSelector:
    matchLabels:
      role: frontend
  namespaceSelector:
    matchLabels:
      environment: production
```

### 5. Multiple Rules (OR logic)
```yaml
# Allow traffic from frontend pods OR monitoring namespace
from:
- podSelector:
    matchLabels:
      role: frontend
- namespaceSelector:
    matchLabels:
      name: monitoring
```

## Network Policy CNI Requirements

### CNI Support Matrix

**Supports Network Policies**:
- Calico ✅ (most complete implementation)
- Cilium ✅ (eBPF-based, high performance)
- Weave Net ✅
- Antrea ✅ (VMware)
- Azure CNI ✅ (Azure AKS)
- AWS VPC CNI ✅ (with additional controller)

**Does NOT Support Network Policies**:
- Flannel ❌ (overlay only)
- Basic Docker bridge ❌

### Cloud Provider Implementation

**AWS EKS**:
- Requires Calico or AWS Load Balancer Controller + VPC CNI
- Security Groups provide node-level control
- Network Policies provide pod-level control

**Azure AKS**:
- Built-in support with Azure CNI
- Azure Network Policy Manager

**Google GKE**:
- Native support with GKE Network Policy
- Based on Calico implementation

## Common Enterprise Patterns

### 1. Three-Tier Application Isolation
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Frontend   │───►│  Backend    │───►│  Database   │
│   Tier      │    │   Tier      │    │   Tier      │
└─────────────┘    └─────────────┘    └─────────────┘
     │                   │                   │
     └───────────────────┼───────────────────┘
                         │
                    Deny direct
                    frontend→database
```

### 2. Namespace Isolation
- Development teams can't access each other's namespaces
- Shared services accessible to all
- Monitoring can access everything (read-only)

### 3. Egress Control
- Block pods from accessing external internet
- Allow only specific external services (databases, APIs)
- Prevent data exfiltration

### 4. Zero Trust Networking
- Deny all traffic by default
- Explicitly allow only necessary communications
- Implement microsegmentation

## Learning Path

### 1. Basic Deny-All Policy
```bash
kubectl apply -f 01-deny-all-ingress.yaml
```

### 2. Allow Specific Pod Communication  
```bash
kubectl apply -f 02-allow-frontend-backend.yaml
```

### 3. Namespace-Based Rules
```bash
kubectl apply -f 03-namespace-isolation.yaml
```

### 4. Three-Tier Application
```bash
kubectl apply -f 04-three-tier-app.yaml
```

### 5. Egress Control
```bash
kubectl apply -f 05-egress-control.yaml
```

### 6. Production Multi-Tenancy
```bash
kubectl apply -f 06-production-isolation.yaml
```

## Security Best Practices

### 1. Start with Deny-All
Always begin with a policy that denies all traffic, then add specific allows

### 2. Use Descriptive Labels
```yaml
# Good: Clear intent
matchLabels:
  app: web-frontend
  tier: frontend
  version: v1.2.0

# Bad: Generic labels  
matchLabels:
  app: myapp
```

### 3. Test Thoroughly
Network policies can break applications - test in staging first

### 4. Monitor and Audit
```bash
# Check which policies apply to a pod
kubectl describe pod <pod-name> -n <namespace>

# View network policy details
kubectl describe networkpolicy <policy-name> -n <namespace>
```

### 5. Consider Default Policies
Apply baseline deny-all policies to new namespaces automatically

## Testing and Troubleshooting

### Test Network Connectivity
```bash
# Test from one pod to another
kubectl exec -it <source-pod> -n <namespace> -- nc -zv <target-ip> <port>

# Test DNS resolution
kubectl exec -it <pod> -n <namespace> -- nslookup <service-name>

# Test HTTP connectivity
kubectl exec -it <pod> -n <namespace> -- wget -qO- <service-url>
```

### Debug Network Policies
```bash
# List all network policies
kubectl get networkpolicies -A

# Check policy details
kubectl describe networkpolicy <policy-name> -n <namespace>

# View pod labels (for selector matching)
kubectl get pods --show-labels -n <namespace>

# Check namespace labels
kubectl get namespace --show-labels
```

### Common Issues

**1. CNI doesn't support Network Policies**
- Solution: Migrate to Calico, Cilium, or supported CNI

**2. Policy doesn't take effect**
- Check pod/namespace label selectors
- Verify CNI implementation
- Ensure no conflicting policies

**3. DNS resolution fails**
- Allow traffic to kube-dns/CoreDNS pods
- Include DNS egress rules

**4. Service discovery broken**
- Allow traffic to Kubernetes API server
- Include service endpoint access

## Performance Considerations

### Policy Evaluation
- Policies are evaluated at the CNI level
- More policies = more evaluation overhead
- Use efficient selectors (labels vs IP ranges)

### Network Latency
- eBPF-based CNIs (Cilium) have lower overhead
- iptables-based implementations add some latency
- Consider for high-throughput applications

## Real-World Impact

**Compliance**: SOC2/PCI requirements for network segmentation
**Security incidents**: Limit lateral movement during breaches  
**Multi-tenancy**: Safe isolation between teams/customers
**Zero trust**: Implementation of "never trust, always verify"

## The 90/10 Rule Applied

**90% of use cases**: Basic namespace and tier isolation
- Use: Simple ingress rules with pod/namespace selectors

**10% of use cases**: Complex egress control and external traffic
- Use: Combined selectors, IP blocks, and port-specific rules

## Key Questions

**1. What problem does this solve?**
- Eliminates the "flat network" security model
- Provides defense in depth for containerized applications
- Enables compliance with security frameworks

**2. What would happen without it?**
- Any compromised pod could access any other pod
- No network segmentation between applications
- Difficult to meet compliance requirements

**3. How does this connect to fundamentals?**
- Built on Linux iptables/netfilter (or eBPF)
- Follows Kubernetes label selector patterns
- Implements standard firewall concepts for containers

## Connection to Cloud Native Security

Network Policies are part of the **defense in depth** strategy:
1. **Container Security**: Secure images, runtime protection
2. **Pod Security**: Security contexts, admission controllers  
3. **Network Security**: Network policies (this document)
4. **Data Security**: Encryption, secrets management
5. **Identity Security**: RBAC, service accounts