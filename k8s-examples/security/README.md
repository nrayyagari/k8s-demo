# Kubernetes Security: Production-Ready Defense in Depth

## WHY Security Matters More Than Ever

**Problem**: Kubernetes adds attack surface—container escapes, privilege escalation, network exposure, and cloud service access  
**Solution**: Layered security approach with secure defaults, continuous monitoring, and zero-trust principles

**Business Reality**: A single security breach can cost millions in damage, compliance violations, and customer trust. Security isn't optional—it's survival.

## The Kubernetes Threat Landscape: Real Attacks

### Production Attack Patterns from Kubernetes Goat Analysis

**These are REAL vulnerabilities found in production environments:**

#### 1. Container Breakout to Host System
```bash
# ATTACK: Privileged container escape
# Real incident: Tesla Kubernetes cluster compromise (2018)
apiVersion: v1
kind: Pod
metadata:
  name: dangerous-pod
spec:
  containers:
  - name: escape-pod
    image: busybox
    securityContext:
      privileged: true  # ❌ NEVER do this
    volumeMounts:
    - name: host-root
      mountPath: /host
  volumes:
  - name: host-root
    hostPath:
      path: /  # ❌ Mounts entire host filesystem
```

**Business Impact**: Complete cluster compromise, data exfiltration, cryptocurrency mining  
**Fix**: Remove privileged: true, use specific volume mounts, Pod Security Standards

#### 2. Secrets Exposure in Code/Images
```bash
# ATTACK: Hardcoded credentials
# Real incident: Dozens of exposed AWS keys in public images
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: vulnerable-app
    image: myapp:latest
    env:
    - name: AWS_ACCESS_KEY_ID
      value: "AKIAIOSFODNN7EXAMPLE"  # ❌ Hardcoded secret
    - name: DB_PASSWORD
      value: "supersecret123"  # ❌ Plain text password
```

**Business Impact**: Cloud bill explosion, data breach, regulatory fines  
**Fix**: Use Kubernetes Secrets, external secret management (Vault, AWS Secrets Manager)

#### 3. RBAC Overprivilege (Confused Deputy)
```yaml
# ATTACK: Service account with cluster-admin
# Real incident: Mining attacks via overprivileged service accounts
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dangerous-binding
subjects:
- kind: ServiceAccount
  name: app-service-account
  namespace: default
roleRef:
  kind: ClusterRole
  name: cluster-admin  # ❌ Way too much privilege
  apiGroup: rbac.authorization.k8s.io
```

**Business Impact**: Lateral movement, data access, cluster takeover  
**Fix**: Principle of least privilege, regular RBAC audits

#### 4. Network Exposure via NodePort
```yaml
# ATTACK: Database exposed to internet
# Real incident: MongoDB instances exposed via NodePort
apiVersion: v1
kind: Service
metadata:
  name: database-service
spec:
  type: NodePort  # ❌ Exposes on all nodes
  ports:
  - port: 5432
    targetPort: 5432
    nodePort: 30432  # ❌ Accessible from internet
  selector:
    app: database
```

**Business Impact**: Direct database access, data exfiltration, ransomware  
**Fix**: Use ClusterIP, implement Network Policies, proper ingress

## The Security Layers: Defense in Depth

### Layer 1: Supply Chain Security

#### Container Image Security
```yaml
# SECURE: Minimal, non-root container
FROM gcr.io/distroless/java:11
COPY app.jar /app.jar
USER 1000  # Non-root user
ENTRYPOINT ["java", "-jar", "/app.jar"]

# Image security scanning in CI/CD
# Example: Trivy scanning
trivy image myapp:latest --severity HIGH,CRITICAL --exit-code 1
```

#### Secure Base Images
```bash
# ❌ AVOID: Full OS images with unnecessary tools
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y curl wget netcat

# ✅ PREFER: Distroless or minimal images
FROM gcr.io/distroless/static:nonroot
COPY myapp /
USER nonroot:nonroot
ENTRYPOINT ["/myapp"]
```

### Layer 2: Runtime Security

#### Pod Security Standards (Replacement for Pod Security Policies)
```yaml
# Namespace-level enforcement
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
# Secure pod specification
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: production
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
    sysctls: []  # No unsafe sysctls
  containers:
  - name: app
    image: myapp:latest
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE  # Only if needed
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
    volumeMounts:
    - name: tmp-volume
      mountPath: /tmp
      readOnly: false
  volumes:
  - name: tmp-volume
    emptyDir: {}
```

#### Security Context Deep Dive
```yaml
# Complete security context configuration
spec:
  securityContext:
    # Pod-level security
    runAsNonRoot: true          # Containers must run as non-root
    runAsUser: 1000            # Specific UID
    runAsGroup: 3000           # Specific GID
    fsGroup: 2000              # Volume ownership group
    seLinuxOptions:            # SELinux labels
      level: "s0:c123,c456"
    seccompProfile:            # Seccomp profile
      type: RuntimeDefault
    supplementalGroups: [1000] # Additional groups
    sysctls:                   # Kernel parameters (be careful)
    - name: net.core.somaxconn
      value: "1024"
  containers:
  - name: app
    securityContext:
      # Container-level security (overrides pod-level)
      allowPrivilegeEscalation: false  # Prevent privilege escalation
      readOnlyRootFilesystem: true     # Immutable root filesystem
      runAsNonRoot: true               # Force non-root
      runAsUser: 1001                  # Override pod user
      capabilities:
        drop: ["ALL"]                  # Drop all Linux capabilities
        add: ["NET_BIND_SERVICE"]      # Add only what's needed
```

### Layer 3: Network Security

#### Network Policies - Zero Trust Networking
```yaml
# Default deny all ingress traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: production
spec:
  podSelector: {}  # Apply to all pods
  policyTypes:
  - Ingress
---
# Allow specific frontend to backend communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    - namespaceSelector:
        matchLabels:
          name: api-gateway
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: database
    ports:
    - protocol: TCP
      port: 5432
  # Allow DNS resolution
  - to: []
    ports:
    - protocol: UDP
      port: 53
---
# Database isolation policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-isolation
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 5432
  egress:
  # Deny all outbound except DNS
  - to: []
    ports:
    - protocol: UDP
      port: 53
```

#### Service Mesh Security (Istio Example)
```yaml
# Automatic mTLS for all services
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default-mtls
  namespace: production
spec:
  mtls:
    mode: STRICT
---
# Authorization policy - zero trust
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: payment-service-authz
  namespace: production
spec:
  selector:
    matchLabels:
      app: payment-service
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/production/sa/order-service"]
  - to:
    - operation:
        methods: ["POST"]
        paths: ["/api/v1/process-payment"]
  - when:
    - key: request.headers[user-role]
      values: ["authenticated"]
```

### Layer 4: RBAC and Access Control

#### Least Privilege RBAC Pattern
```yaml
# Principle of least privilege - specific role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: production
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]
---
# Service account for application
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-service-account
  namespace: production
automountServiceAccountToken: false  # Disable if not needed
---
# Binding with minimal permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-pod-reader
  namespace: production
subjects:
- kind: ServiceAccount
  name: app-service-account
  namespace: production
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
---
# Pod using the service account
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: production
spec:
  template:
    spec:
      serviceAccountName: app-service-account
      automountServiceAccountToken: true  # Only if needed
      containers:
      - name: app
        image: myapp:latest
```

#### RBAC Anti-Patterns to Avoid
```yaml
# ❌ NEVER: Blanket cluster-admin access
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dangerous-admin
subjects:
- kind: ServiceAccount
  name: default  # Default service account
  namespace: default
roleRef:
  kind: ClusterRole
  name: cluster-admin  # Full cluster access
  apiGroup: rbac.authorization.k8s.io

# ❌ NEVER: Wildcard permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: overprivileged-role
rules:
- apiGroups: ["*"]  # All API groups
  resources: ["*"]  # All resources
  verbs: ["*"]      # All verbs
```

### Layer 5: Secrets Management

#### External Secrets Pattern (AWS Secrets Manager)
```yaml
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace

# SecretStore for AWS Secrets Manager
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-store
  namespace: production
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
      auth:
        secretRef:
          accessKeyID:
            name: aws-creds
            key: access-key-id
          secretAccessKey:
            name: aws-creds
            key: secret-access-key
---
# External Secret definition
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-secret
  namespace: production
spec:
  refreshInterval: 300s  # Refresh every 5 minutes
  secretStoreRef:
    name: aws-secrets-store
    kind: SecretStore
  target:
    name: database-credentials
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: production/database
      property: username
  - secretKey: password
    remoteRef:
      key: production/database
      property: password
```

#### Secret Encryption at Rest
```yaml
# KMS encryption for etcd (EKS example)
apiVersion: v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - kms:
      name: arn:aws:kms:us-west-2:123456789:key/12345678-1234-1234-1234-123456789012
      cachesize: 1000
  - identity: {}
```

### Layer 6: Monitoring and Detection

#### Falco - Runtime Security Monitoring
```yaml
# Falco DaemonSet for runtime security
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: falco
  namespace: falco-system
spec:
  selector:
    matchLabels:
      app: falco
  template:
    spec:
      serviceAccountName: falco
      hostNetwork: true
      hostPID: true
      containers:
      - name: falco
        image: falcosecurity/falco:0.35.1
        securityContext:
          privileged: true  # Required for kernel access
        volumeMounts:
        - mountPath: /host/var/run/docker.sock
          name: docker-socket
        - mountPath: /host/dev
          name: dev-fs
        - mountPath: /host/proc
          name: proc-fs
          readOnly: true
        - mountPath: /host/boot
          name: boot-fs
          readOnly: true
        - mountPath: /host/lib/modules
          name: lib-modules
          readOnly: true
        - mountPath: /host/usr
          name: usr-fs
          readOnly: true
      volumes:
      - name: docker-socket
        hostPath:
          path: /var/run/docker.sock
      - name: dev-fs
        hostPath:
          path: /dev
      - name: proc-fs
        hostPath:
          path: /proc
      - name: boot-fs
        hostPath:
          path: /boot
      - name: lib-modules
        hostPath:
          path: /lib/modules
      - name: usr-fs
        hostPath:
          path: /usr
```

#### Custom Falco Rules for Kubernetes
```yaml
# Custom Falco rules for Kubernetes security
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-rules
  namespace: falco-system
data:
  custom-rules.yaml: |
    - rule: Suspicious Container Behavior
      desc: Detect suspicious container activities
      condition: >
        spawned_process and
        container and
        (proc.name in (nc, ncat, netcat, wget, curl) or
         proc.name contains "python" or
         proc.name contains "perl")
      output: >
        Suspicious process in container 
        (user=%user.name container=%container.name 
         image=%container.image.repository proc=%proc.name)
      priority: WARNING
      
    - rule: Pod Created with Privileged
      desc: Detect privileged pod creation
      condition: >
        ka and kcreate and pod and ka.target.resource=pods and
        ka.req.pod.privileged=true
      output: >
        Privileged pod created 
        (user=%ka.user.name pod=%ka.target.name 
         namespace=%ka.target.namespace)
      priority: ERROR
      
    - rule: Sensitive File Access
      desc: Detect access to sensitive files
      condition: >
        open_read and container and
        (fd.name startswith /etc/passwd or
         fd.name startswith /etc/shadow or
         fd.name startswith /root/.ssh/)
      output: >
        Sensitive file accessed in container
        (user=%user.name container=%container.name file=%fd.name)
      priority: ERROR
```

## Production Security Hardening Checklist

### Cluster Level Security
- [ ] **API Server Security**
  - [ ] Enable audit logging
  - [ ] Restrict API server access (private endpoint)
  - [ ] Use OIDC for authentication
  - [ ] Enable encryption at rest (etcd)
  - [ ] Configure admission controllers

- [ ] **etcd Security**
  - [ ] Enable client certificate authentication
  - [ ] Encrypt etcd data at rest
  - [ ] Regular etcd backups
  - [ ] Network isolation for etcd
  - [ ] Monitor etcd access

- [ ] **Node Security**
  - [ ] Regular OS security updates
  - [ ] Minimal node image (hardened)
  - [ ] Disable SSH access to nodes
  - [ ] Use private node pools
  - [ ] Enable node logging

### Workload Security
- [ ] **Pod Security**
  - [ ] Enforce Pod Security Standards (restricted)
  - [ ] Remove default service account privileges
  - [ ] Use read-only root filesystems
  - [ ] Drop all capabilities by default
  - [ ] Run as non-root user

- [ ] **Container Security**
  - [ ] Use distroless or minimal base images
  - [ ] Scan images for vulnerabilities
  - [ ] Sign container images
  - [ ] Use private container registries
  - [ ] Regular image updates

### Network Security
- [ ] **Network Policies**
  - [ ] Default deny all traffic
  - [ ] Explicit allow rules only
  - [ ] Namespace isolation
  - [ ] Egress traffic control
  - [ ] DNS policy restrictions

- [ ] **Service Mesh Security**
  - [ ] Enable automatic mTLS
  - [ ] Authorization policies
  - [ ] Traffic encryption
  - [ ] Service-to-service authentication
  - [ ] Ingress gateway security

### Access Control
- [ ] **RBAC Implementation**
  - [ ] Principle of least privilege
  - [ ] Regular RBAC audits
  - [ ] Remove unused roles and bindings
  - [ ] Service account automation
  - [ ] User access reviews

- [ ] **Authentication & Authorization**
  - [ ] Multi-factor authentication
  - [ ] OIDC integration
  - [ ] Regular credential rotation
  - [ ] Audit user access
  - [ ] Emergency break-glass procedures

### Secrets Management
- [ ] **External Secret Management**
  - [ ] Use external secret stores (Vault, AWS SM)
  - [ ] Automatic secret rotation
  - [ ] Encrypt secrets at rest
  - [ ] Audit secret access
  - [ ] No secrets in code/images

### Monitoring and Incident Response
- [ ] **Security Monitoring**
  - [ ] Runtime security monitoring (Falco)
  - [ ] Audit log analysis
  - [ ] Anomaly detection
  - [ ] Security metrics and alerting
  - [ ] Incident response plan

## Security Tools Integration

### Image Scanning with Trivy
```bash
# CI/CD integration for image scanning
name: Container Security Scan
on: [push, pull_request]
jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Build image
      run: docker build -t myapp:${{ github.sha }} .
    - name: Scan image
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: myapp:${{ github.sha }}
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: 'CRITICAL,HIGH'
        exit-code: '1'  # Fail build on vulnerabilities
```

### Policy Enforcement with Kyverno
```yaml
# Block privileged containers
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged-containers
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: check-privileged
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Privileged containers are not allowed"
      pattern:
        spec:
          =(securityContext):
            =(privileged): "false"
          containers:
          - name: "*"
            =(securityContext):
              =(privileged): "false"
---
# Require resource limits
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: enforce
  rules:
  - name: check-resources
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Resource requests and limits are required"
      pattern:
        spec:
          containers:
          - name: "*"
            resources:
              requests:
                memory: "?*"
                cpu: "?*"
              limits:
                memory: "?*"
                cpu: "?*"
```

### Network Security Scanning
```bash
# Use Kube-hunter for cluster security assessment
docker run --rm --network host aquasec/kube-hunter:latest --remote some.node.com

# Use Kube-bench for CIS Kubernetes benchmark
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
kubectl logs job/kube-bench
```

## Security Incident Response

### Detection and Response Framework

#### 1. Immediate Containment
```bash
# Isolate compromised pod
kubectl patch deployment suspicious-app -p '{"spec":{"replicas":0}}'

# Block network access
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: quarantine-policy
spec:
  podSelector:
    matchLabels:
      app: suspicious-app
  policyTypes:
  - Ingress
  - Egress
EOF

# Capture evidence
kubectl get pod suspicious-pod -o yaml > evidence-pod.yaml
kubectl logs suspicious-pod --all-containers --previous > evidence-logs.txt
kubectl describe pod suspicious-pod > evidence-events.txt
```

#### 2. Investigation Commands
```bash
# Check for privilege escalation
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.securityContext.privileged}{"\n"}{end}'

# Identify overprivileged service accounts
kubectl get clusterrolebindings -o custom-columns=NAME:.metadata.name,ROLE:.roleRef.name,SUBJECT:.subjects[*].name

# Find suspicious processes
kubectl exec -it <pod> -- ps aux
kubectl exec -it <pod> -- netstat -tulpn

# Check for crypto mining indicators
kubectl top pods --all-namespaces --sort-by=cpu
kubectl logs <suspicious-pod> | grep -i "mining\|pool\|hashrate\|cryptocurrency"
```

#### 3. Recovery and Lessons Learned
```bash
# Rebuild from clean images
kubectl set image deployment/app container=myapp:clean-version

# Rotate all potentially compromised secrets
kubectl delete secret suspicious-secret
kubectl create secret generic new-secret --from-literal=key=newvalue

# Review and tighten security policies
kubectl apply -f updated-network-policies.yaml
kubectl apply -f restrictive-rbac.yaml
```

## Security Anti-Patterns: What NOT to Do

### ❌ Dangerous Configurations from Real Incidents

#### 1. The "Privileged Pod" Anti-Pattern
```yaml
# NEVER do this - from Tesla incident
spec:
  containers:
  - name: app
    securityContext:
      privileged: true
      allowPrivilegeEscalation: true
    volumeMounts:
    - name: host-root
      mountPath: /host
  volumes:
  - name: host-root
    hostPath:
      path: /
```

#### 2. The "Default Everything" Anti-Pattern
```yaml
# NEVER leave defaults - leads to compromise
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: default  # ❌ Default SA has unnecessary permissions
  containers:
  - name: app
    image: myapp:latest
    # ❌ No security context = running as root
    # ❌ No resource limits = potential DoS
    # ❌ No network policies = open communication
```

#### 3. The "Secrets in Plain Sight" Anti-Pattern
```yaml
# NEVER embed secrets in manifests
env:
- name: DATABASE_PASSWORD
  value: "supersecret123"  # ❌ Visible in Git, kubectl describe
- name: API_KEY
  value: "sk-1234567890abcdef"  # ❌ Logged, audited, cached
```

## Security Compliance and Frameworks

### CIS Kubernetes Benchmark Compliance
```bash
# Use kube-bench to check CIS compliance
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml

# Key CIS controls:
# 1.2.1 Ensure that the --anonymous-auth argument is set to false
# 1.2.2 Ensure that the --basic-auth-file argument is not set
# 1.2.3 Ensure that the --token-auth-file parameter is not set
# 4.2.1 Minimize the admission of privileged containers
# 4.2.2 Minimize the admission of containers wishing to share the host process ID namespace
# 5.1.1 Ensure that the cluster-admin role is only used where required
```

### NIST Cybersecurity Framework Mapping
```yaml
Identify (ID):
  - Asset inventory (container images, secrets, services)
  - Risk assessment (threat modeling)
  - Governance (security policies)

Protect (PR):
  - Access control (RBAC, network policies)
  - Data security (encryption, secrets management)
  - Protective technology (Pod Security Standards)

Detect (DE):
  - Continuous monitoring (Falco, audit logs)
  - Anomaly detection (unusual resource usage)
  - Security events (failed authentication, privilege escalation)

Respond (RS):
  - Incident response plan
  - Communication procedures
  - Analysis and mitigation

Recover (RC):
  - Recovery planning
  - Improvements based on lessons learned
  - Communication during recovery
```

## Security Training and Awareness

### Hands-On Security Labs
```bash
# Safe environments for security training
1. Kubernetes Goat (intentionally vulnerable)
   - git clone https://github.com/madhuakula/kubernetes-goat
   - Deploy in isolated environment only

2. Kube Security Lab
   - Practice common attack scenarios
   - Learn defense techniques
   - Understand incident response

3. CTF-style challenges
   - Container breakout challenges
   - RBAC bypass scenarios
   - Network policy evasion
```

### Security Mindset Development
- **Think Like an Attacker**: What would you target first?
- **Assume Breach**: Plan for when (not if) compromise happens
- **Defense in Depth**: Multiple layers of security
- **Continuous Learning**: Security threats evolve constantly
- **Automation**: Humans make mistakes, automate security

## Quick Security Assessment

### 5-Minute Security Health Check
```bash
# Check for common security issues
echo "=== SECURITY HEALTH CHECK ==="

echo "1. Privileged containers:"
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.securityContext.privileged}{"\n"}{end}' | grep true

echo "2. Pods running as root:"
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.securityContext.runAsUser}{"\n"}{end}' | grep -E "^[^0-9]|^0$"

echo "3. Cluster admin bindings:"
kubectl get clusterrolebindings -o custom-columns=NAME:.metadata.name,ROLE:.roleRef.name | grep cluster-admin

echo "4. Default service accounts with tokens:"
kubectl get serviceaccounts --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,AUTOMOUNT:.automountServiceAccountToken | grep -v false

echo "5. Network policies count:"
kubectl get networkpolicies --all-namespaces --no-headers | wc -l

echo "6. Pods without resource limits:"
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources.limits}{"\n"}{end}' | grep -v "map"
```

**Remember**: Security is not a destination, it's a continuous journey. Stay paranoid, automate everything, and always assume someone is trying to break your system—because they probably are.