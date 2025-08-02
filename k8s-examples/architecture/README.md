# Kubernetes Architecture: Deep Technical Understanding

## WHY Architecture Knowledge Matters

**Problem**: Kubernetes seems magical—pods appear, services route traffic, but when things break, you have no idea why  
**Solution**: Deep understanding of how every component works together enables effective troubleshooting and optimal system design

**Business Reality**: Senior engineers who understand architecture make better decisions, debug faster, and design more reliable systems.

## The Big Picture: What Kubernetes Actually Is

**Kubernetes is not magic. It's a distributed system with clear responsibilities:**

1. **Desired State Management**: You declare what you want, Kubernetes makes it happen
2. **Resource Orchestration**: Efficiently place workloads across multiple machines  
3. **Service Discovery**: Connect components reliably in a dynamic environment
4. **Self-Healing**: Automatically detect and recover from failures

**First Principle**: Kubernetes is fundamentally a control loop system. Everything watches for changes and reacts.

## Control Plane vs Data Plane: The Foundation

### Control Plane (The Brain)
**Purpose**: Make decisions about the cluster  
**Location**: Usually separate nodes (master nodes)  
**Business Impact**: If control plane fails, no new changes possible but existing apps keep running

### Data Plane (The Muscle)  
**Purpose**: Run your actual workloads  
**Location**: Worker nodes  
**Business Impact**: If data plane fails, your applications stop serving traffic

**Critical Understanding**: Control plane and data plane are physically and logically separated for reliability.

## Control Plane Components: The Decision Makers

### API Server (kube-apiserver): The Gateway

**What it does**:
- Single entry point for all cluster operations
- Validates and persists API objects to etcd
- Serves the Kubernetes API over HTTPS
- Authenticates and authorizes all requests

**Why it matters**:
```bash
# Everything goes through API server
kubectl get pods → API Server → etcd → Response
Deployment Controller → API Server → Create Pods
Service Controller → API Server → Update Endpoints
```

**Production Reality**:
- API server is stateless—you can run multiple instances
- All kubectl commands talk to API server
- When API server is down, cluster management stops
- Apps keep running but no changes possible

**Interview Question**: "What happens when API server goes down?"  
**Answer**: Existing workloads continue running, but no new deployments, scaling, or changes are possible until API server recovers.

### etcd: The Single Source of Truth

**What it does**:
- Distributed key-value store
- Stores all cluster state (pods, services, configs, secrets)
- Provides atomic operations and consistency
- Source of truth for entire cluster

**Why it matters**:
```yaml
# Everything stored in etcd:
/registry/pods/default/my-pod
/registry/services/default/my-service  
/registry/secrets/default/my-secret
/registry/configmaps/default/my-config
```

**Production Reality**:
- etcd failure = complete cluster failure
- Always run etcd in clusters (3 or 5 nodes)
- Regular backups are critical—etcd backup = cluster backup
- Network latency to etcd affects entire cluster performance

**Interview Question**: "How does Kubernetes maintain state consistency?"  
**Answer**: etcd provides distributed consensus using Raft algorithm, ensuring all nodes have the same view of cluster state.

### Scheduler (kube-scheduler): The Placement Engine

**What it does**:
- Decides which node should run each pod
- Considers resource requirements, constraints, and policies
- Makes optimal placement decisions based on cluster state

**How it works**:
```bash
1. Watch API server for pods with no node assignment
2. Filter nodes that can't run the pod (resources, taints, affinity)
3. Score remaining nodes based on optimization criteria
4. Select highest-scoring node
5. Bind pod to node via API server
```

**Scheduling Factors**:
- **Resource Requirements**: CPU/memory requests and limits
- **Node Affinity**: Prefer or require specific nodes
- **Pod Affinity/Anti-affinity**: Co-locate or separate pods
- **Taints and Tolerations**: Node restrictions and overrides
- **Quality of Service**: Priority-based scheduling

**Production Reality**:
- Default scheduler is good for 90% of use cases
- Custom schedulers possible for special requirements
- Scheduler decisions are recorded in events
- Bad scheduling decisions cascade into operational problems

**Interview Question**: "How does Kubernetes decide where to place a pod?"  
**Answer**: Scheduler filters nodes by constraints (resources, affinity, taints), then scores them by optimization criteria (resource utilization, spreading), and selects the highest-scoring node.

### Controller Manager (kube-controller-manager): The Automation Engine

**What it does**:
- Runs control loops that watch cluster state and take corrective action
- Contains multiple controllers in a single binary
- Implements the "desired state" principle

**Key Controllers**:

#### Deployment Controller
```bash
Watches: Deployment objects
Actions: Creates/updates ReplicaSets
Goal: Maintain desired number of pods with rolling updates
```

#### ReplicaSet Controller  
```bash
Watches: ReplicaSet objects
Actions: Creates/deletes Pods
Goal: Maintain exact number of pod replicas
```

#### Node Controller
```bash
Watches: Node health and status
Actions: Marks nodes NotReady, evicts pods
Goal: Handle node failures gracefully
```

#### Service Controller
```bash  
Watches: Service objects
Actions: Creates cloud load balancers, updates endpoints
Goal: Provide stable network access to pods
```

#### Endpoint Controller
```bash
Watches: Services and Pods
Actions: Updates endpoint objects with pod IPs
Goal: Keep service routing tables current
```

**Control Loop Pattern**:
```bash
1. Watch current state (via API server)
2. Compare with desired state  
3. Take action to reconcile differences
4. Repeat continuously
```

**Production Reality**:
- Controllers run independently—if one fails, others continue
- All controllers go through API server (never direct etcd access)
- Controller reconciliation explains most Kubernetes "magic"
- Understanding controllers essential for troubleshooting

**Interview Question**: "How does a Deployment create Pods?"  
**Answer**: Deployment Controller creates ReplicaSet → ReplicaSet Controller creates Pods → Scheduler assigns nodes → Kubelet starts containers.

### Cloud Controller Manager: The Cloud Integration

**What it does**:
- Interfaces with cloud provider APIs
- Manages cloud-specific resources (load balancers, storage, networking)
- Enables cloud-native features

**Key Responsibilities**:
- **Node Controller**: Determine if nodes are deleted in cloud
- **Route Controller**: Set up network routes in cloud infrastructure  
- **Service Controller**: Create/delete cloud load balancers
- **Volume Controller**: Attach/detach cloud storage volumes

**Production Reality**:
- Only relevant when running on cloud providers (AWS, GCP, Azure)
- Enables native cloud integration (ELB, ALB, GCS, EBS)
- Failure can cause service and storage issues
- Different implementation per cloud provider

## Data Plane Components: The Workhorses

### Kubelet: The Node Agent

**What it does**:
- Primary node agent running on every worker node
- Communicates with API server to get pod specifications
- Manages container lifecycle via container runtime
- Reports node and pod status back to control plane

**Key Responsibilities**:

#### Pod Lifecycle Management
```bash
1. Receives pod spec from API server
2. Pulls container images  
3. Creates pod sandbox (network, storage)
4. Starts containers via container runtime
5. Monitors container health
6. Reports status to API server
```

#### Health Monitoring
```bash
- Liveness probes: Restart unhealthy containers
- Readiness probes: Remove pods from service endpoints
- Startup probes: Handle slow-starting containers
```

#### Resource Management
```bash
- Enforces resource requests and limits
- Manages local storage (emptyDir, hostPath)
- Implements Quality of Service (QoS) classes
```

**Production Reality**:
- Kubelet failure = node becomes unusable
- Kubelet talks to API server every few seconds
- Contains built-in cAdvisor for resource monitoring
- Logs are critical for node-level troubleshooting

**Interview Question**: "What happens when kubelet stops working?"  
**Answer**: Node marked NotReady, new pods won't be scheduled there, existing pods may be evicted to other nodes after timeout period.

### Container Runtime: The Execution Engine

**What it does**:
- Actually runs containers on nodes
- Implements Container Runtime Interface (CRI)
- Manages container images and execution

**Common Runtimes**:

#### containerd (Most Common)
```bash
- Docker's core runtime, now standalone
- Lightweight and fast
- Direct integration with Kubernetes
- Default for most cloud providers
```

#### CRI-O
```bash  
- Designed specifically for Kubernetes
- OCI-compliant runtime
- Minimal and secure
- Popular in enterprise environments
```

#### Docker Engine (Legacy)
```bash
- Original Kubernetes runtime
- Deprecated since Kubernetes 1.20
- Still works via dockershim compatibility
```

**Runtime Responsibilities**:
- Image pulling and management
- Container creation and deletion
- Container networking setup  
- Volume mounting
- Resource enforcement

**Production Reality**:
- Runtime choice affects cluster performance and features
- Runtime issues manifest as pod startup problems
- containerd is becoming the standard
- Runtime logs essential for container-level debugging

### Kube-proxy: The Network Traffic Director

**What it does**:
- Implements Kubernetes service networking
- Routes traffic from services to pods
- Runs on every node in the cluster

**How Service Networking Works**:
```bash
1. Service created with ClusterIP
2. kube-proxy watches Service and Endpoint objects
3. kube-proxy configures local networking rules
4. Traffic to service IP gets routed to pod IPs
```

**Proxy Modes**:

#### iptables Mode (Default)
```bash
- Uses iptables rules for traffic routing
- Random pod selection for load balancing
- Good performance for moderate traffic
- Complex iptables chains for debugging
```

#### IPVS Mode (High Performance)
```bash
- Uses IPVS kernel module for load balancing
- Better performance for large clusters  
- More load balancing algorithms
- Better scaling characteristics
```

#### userspace Mode (Legacy)
```bash
- Original implementation
- All traffic goes through kube-proxy process
- Slower performance, rarely used
```

**Production Reality**:
- kube-proxy failure = service networking breaks on that node
- Different proxy modes have different performance characteristics
- Network policies require additional CNI support
- Service mesh can replace some kube-proxy functionality

**Interview Question**: "How does service discovery work in Kubernetes?"  
**Answer**: Services get stable ClusterIPs, kube-proxy watches services/endpoints and configures local routing rules (iptables/IPVS) to forward traffic to healthy pod IPs.

## Networking Architecture: How Pods Communicate

### Container Network Interface (CNI): The Networking Foundation

**What it does**:
- Defines how container networking should work
- Provides pluggable network architecture
- Enables different networking solutions

**Network Requirements**:
```bash
1. Every pod gets unique IP address
2. Pods can communicate with each other without NAT
3. Nodes can communicate with pods directly
4. Services provide stable endpoints for pod groups
```

**Popular CNI Plugins**:

#### Flannel (Simple)
```bash
- Layer 3 network fabric for Kubernetes
- Simple overlay network using VXLAN
- Easy to setup and understand
- Limited advanced features
```

#### Calico (Feature-Rich)
```bash
- Layer 3 networking with policy enforcement
- BGP-based routing (no overlay needed)
- Built-in network policies
- Enterprise security features  
```

#### Cilium (Modern)
```bash
- eBPF-based networking and security
- Advanced load balancing and observability
- Service mesh capabilities
- High performance
```

#### AWS VPC CNI (Cloud-Native)
```bash
- Uses native AWS networking
- Pods get real VPC IP addresses
- Direct integration with AWS services
- Limited to AWS only
```

### Service Networking: Stable Endpoints

**Service Types and Use Cases**:

#### ClusterIP (Internal Communication)
```yaml
# Default service type for internal communication
apiVersion: v1
kind: Service
metadata:
  name: internal-api
spec:
  type: ClusterIP  # Only accessible within cluster
  selector:
    app: api-server
  ports:
  - port: 80
    targetPort: 8080
```

#### NodePort (External Access via Node IPs)
```yaml
# Exposes service on all node IPs at specific port
apiVersion: v1
kind: Service  
metadata:
  name: web-app
spec:
  type: NodePort
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080  # Accessible on any-node-ip:30080
```

#### LoadBalancer (Cloud Provider Integration)
```yaml
# Creates cloud load balancer automatically
apiVersion: v1
kind: Service
metadata:
  name: public-web
spec:
  type: LoadBalancer  # Gets external IP from cloud
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 8080
```

#### ExternalName (DNS Alias)
```yaml
# Maps service name to external DNS name
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: db.example.com  # DNS CNAME
```

**Service Discovery Mechanisms**:

#### DNS-Based Discovery (Primary)
```bash
# Automatic DNS records for all services
my-service.my-namespace.svc.cluster.local
my-service.my-namespace  # Short form within namespace
my-service  # Within same namespace
```

#### Environment Variables (Legacy)
```bash
# Automatic environment variables in pods
MY_SERVICE_SERVICE_HOST=10.96.0.1
MY_SERVICE_SERVICE_PORT=80
```

### Ingress: HTTP/HTTPS Traffic Management

**What Ingress Provides**:
- HTTP/HTTPS routing based on host/path
- SSL/TLS termination  
- Load balancing across services
- Single external entry point

**Ingress Controller Options**:

#### NGINX Ingress Controller (Most Popular)
```bash
- Feature-rich HTTP proxy
- Extensive configuration options
- Good performance for most use cases
- Large community support
```

#### Traefik (Cloud-Native)
```bash
- Automatic service discovery
- Built-in Let's Encrypt integration
- Dynamic configuration
- Great for microservices
```

#### AWS Load Balancer Controller
```bash
- Native AWS integration
- Creates ALB/NLB automatically
- Advanced AWS features (WAF, cognito)
- Cost-effective for AWS workloads
```

#### Istio Gateway (Service Mesh)
```bash
- Part of Istio service mesh
- Advanced traffic management
- Security and observability features
- Enterprise complexity
```

## Storage Architecture: Data Persistence

### Storage Concepts: From Volumes to CSI

#### Volume Types
```bash
# Pod-level storage (ephemeral)
emptyDir: Shared between containers in pod
hostPath: Mount host directory (dangerous)
projected: Combine multiple volume sources

# Persistent storage
persistentVolumeClaim: Request for persistent storage
configMap: Configuration data as files
secret: Sensitive data as files
```

#### Persistent Volume Subsystem
```yaml
# PersistentVolume (cluster resource)
apiVersion: v1
kind: PersistentVolume
metadata:
  name: database-pv
spec:
  capacity:
    storage: 100Gi
  accessModes:
  - ReadWriteOnce
  storageClassName: fast-ssd
  csi:
    driver: ebs.csi.aws.com
    volumeHandle: vol-12345

---
# PersistentVolumeClaim (namespace resource)  
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  storageClassName: fast-ssd
```

#### Container Storage Interface (CSI)
**What it provides**:
- Standardized storage plugin interface
- Support for cloud provider storage (EBS, GCE PD, Azure Disk)
- Advanced features (snapshots, cloning, expansion)
- Third-party storage integration

**Popular CSI Drivers**:
- **AWS EBS CSI**: Elastic Block Store volumes
- **GCE PD CSI**: Google Compute Engine Persistent Disks
- **Azure Disk CSI**: Azure managed disks
- **Longhorn**: Distributed cloud-native storage
- **Ceph CSI**: Distributed storage cluster

### Storage Classes: Dynamic Provisioning
```yaml
# StorageClass defines storage types
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
```

**Key Concepts**:
- **Dynamic Provisioning**: Automatically create storage when requested
- **Volume Binding Mode**: When to create and bind volumes
- **Reclaim Policy**: What happens when PVC is deleted
- **Volume Expansion**: Ability to resize volumes

## Security Architecture: Defense in Depth

### Authentication: Who Are You?

#### Service Accounts (Pod Identity)
```yaml
# Every pod has a service account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-service-account
  namespace: production
automountServiceAccountToken: true  # Default: true
```

#### User Authentication Methods
```bash
# X.509 Client Certificates
kubectl config set-credentials user --client-certificate=user.crt --client-key=user.key

# Bearer Tokens (Service Account tokens)
kubectl config set-credentials user --token=eyJhbGciOiJSUzI1NiIs...

# OIDC (OpenID Connect) - Enterprise
kubectl config set-credentials user --auth-provider=oidc --auth-provider-arg=idp-issuer-url=https://...
```

### Authorization: What Can You Do?

#### Role-Based Access Control (RBAC)
```yaml
# Role (namespace-scoped permissions)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]

---
# RoleBinding (grant role to user/group/service account)
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: production
subjects:
- kind: User
  name: jane
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

#### ClusterRole (cluster-wide permissions)
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
```

### Pod Security: Runtime Protection

#### Security Contexts
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
```

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
```

**Security Levels**:
- **Privileged**: Unrestricted (development only)
- **Baseline**: Minimal restrictions (prevent known privilege escalations)
- **Restricted**: Heavily restricted (production workloads)

### Network Security: Traffic Control

#### Network Policies
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
# Allow specific traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

## Resource Management: Controlling Consumption

### Quality of Service (QoS) Classes

#### Guaranteed (Highest Priority)
```yaml
# Requests = Limits for all containers
resources:
  requests:
    memory: "256Mi"
    cpu: "500m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

#### Burstable (Medium Priority)  
```yaml
# Has requests, limits higher than requests
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "1000m"
```

#### BestEffort (Lowest Priority)
```yaml
# No requests or limits specified
resources: {}
```

**QoS Impact**:
- **Eviction Order**: BestEffort → Burstable → Guaranteed
- **CPU Scheduling**: Guaranteed gets priority during contention
- **Memory Protection**: Guaranteed less likely to be OOMKilled

### Resource Quotas: Namespace Limits
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    persistentvolumeclaims: "10"
    pods: "100"
    services: "20"
    secrets: "50"
    configmaps: "50"
```

### Limit Ranges: Default Resource Constraints
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: production
spec:
  limits:
  - default:  # Default limits
      memory: "512Mi"
      cpu: "500m"
    defaultRequest:  # Default requests
      memory: "256Mi"
      cpu: "100m"
    type: Container
  - max:  # Maximum allowed
      memory: "2Gi"
      cpu: "2000m"
    min:  # Minimum required
      memory: "64Mi"
      cpu: "50m"
    type: Container
```

## How It All Works Together: Complete Flow

### Pod Creation: From kubectl to Running Container

```bash
1. kubectl apply pod.yaml
   ↓
2. kubectl → API Server (authentication/authorization)
   ↓
3. API Server validates pod spec → stores in etcd
   ↓
4. Scheduler watches API Server → sees unscheduled pod
   ↓
5. Scheduler evaluates nodes → selects best node → updates pod spec
   ↓
6. Kubelet (on selected node) watches API Server → sees pod assigned
   ↓
7. Kubelet → Container Runtime → downloads image → starts container
   ↓
8. Kubelet monitors container → reports status to API Server
   ↓
9. API Server updates pod status in etcd
```

### Service Discovery: From Service to Pod Traffic

```bash
1. Service created → API Server → etcd
   ↓
2. Endpoint Controller watches Services/Pods → creates Endpoints
   ↓
3. kube-proxy (all nodes) watches Services/Endpoints → updates routing rules
   ↓
4. CoreDNS watches Services → creates DNS records
   ↓
5. Client resolves service name → gets ClusterIP
   ↓
6. Traffic to ClusterIP → kube-proxy routes to pod IP
   ↓
7. Pod receives traffic directly
```

### Failure Recovery: Self-Healing in Action

```bash
# Node Failure Scenario:
1. Node stops sending heartbeats to API Server
   ↓
2. Node Controller marks node NotReady after grace period
   ↓
3. Deployment Controller sees pods on failed node
   ↓
4. Deployment Controller creates replacement pods
   ↓
5. Scheduler places new pods on healthy nodes
   ↓
6. Kubelet starts containers on new nodes
   ↓
7. Endpoint Controller updates service endpoints
   ↓
8. kube-proxy updates routing rules → traffic flows to new pods
```

## Comprehensive Architecture Interview Questions

### Core Concepts: Fundamental Understanding

#### Pods - The Atomic Unit

**Q: "What exactly is a pod and why not just containers?"**  
**A**: A pod is the smallest deployable unit - one or more containers sharing network, storage, and lifecycle. Containers in a pod communicate via localhost and share volumes. Pods enable patterns like sidecar containers for logging, monitoring, or proxies. Design principle: "One concern per pod" - web server + log collector, not web server + database.

**Q: "How do containers in a pod communicate?"**  
**A**: Containers share localhost network (127.0.0.1), can communicate via any port without conflicts. They share volumes for file-based communication. Process namespace sharing is optional (spec.shareProcessNamespace: true) for process signals between containers.

**Q: "What happens when a pod crashes?"**  
**A**: The pod's containers are restarted by kubelet based on restartPolicy (Always, OnFailure, Never). Pod gets new container IDs but keeps same pod IP and name. If entire pod fails repeatedly, controller (Deployment/ReplicaSet) creates replacement pod with new IP.

**Q: "Explain pod lifecycle phases"**  
**A**: Pending (accepted but not scheduled/images pulling), Running (bound to node, at least one container running), Succeeded (all containers terminated successfully), Failed (at least one container failed), Unknown (communication lost with node).

#### Workload Resources - Managing Pods

**Q: "When would you use Deployment vs ReplicaSet vs Pod directly?"**  
**A**: 
- **Pod directly**: Never in production (no restart, scaling, or updates)
- **ReplicaSet**: Rarely directly (no update strategy)  
- **Deployment**: 99% of stateless workloads (rolling updates, rollback, scaling)
- **StatefulSet**: Stateful apps requiring persistent identity
- **DaemonSet**: One pod per node (logging, monitoring agents)
- **Job**: Run to completion (batch processing)
- **CronJob**: Scheduled batch jobs

**Q: "How does a rolling update work internally?"**  
**A**: Deployment creates new ReplicaSet with updated spec, gradually scales up new ReplicaSet while scaling down old one. Process: Create new RS with 0 replicas → Scale new RS up by surge amount → Scale old RS down by maxUnavailable → Repeat until complete. Old RS kept for rollback.

**Q: "What's the difference between recreation and rolling update strategies?"**  
**A**: 
- **Recreate**: Terminate all pods then create new ones (brief downtime, good for apps that can't run multiple versions)
- **RollingUpdate**: Gradual replacement (zero downtime, controlled by maxSurge and maxUnavailable)

**Q: "How do you ensure exactly N pods are always running?"**  
**A**: ReplicaSet controller continuously reconciles: if fewer than N pods exist, create new ones; if more than N exist, delete excess. Uses label selector to find pods and spec.replicas for desired count. Handles node failures by rescheduling pods to healthy nodes.

#### Services - Networking and Discovery

**Q: "Explain the complete flow from 'curl service-name' to pod response"**  
**A**: 
1. DNS lookup: service-name → CoreDNS → ClusterIP
2. Client sends request to ClusterIP:port  
3. kube-proxy iptables/IPVS rules intercept traffic
4. DNAT to random healthy pod IP:targetPort
5. Pod processes request and responds directly to client
6. Response bypasses kube-proxy (only outbound traffic goes through proxy)

**Q: "How does service load balancing work?"**  
**A**: kube-proxy configures load balancing:
- **iptables mode**: Random selection via iptables probability rules
- **IPVS mode**: Multiple algorithms (round-robin, least connections, weighted)
- **Session affinity**: ClientIP-based sticky sessions (sessionAffinity: ClientIP)

**Q: "What happens when service selector matches no pods?"**  
**A**: Service exists but Endpoints object is empty. Traffic to service results in connection refused/timeout. Service remains valid, endpoints automatically update when matching pods appear.

**Q: "Why do we need both Services and Ingress?"**  
**A**: 
- **Services**: L4 load balancing, cluster-internal routing, any protocol
- **Ingress**: L7 HTTP/HTTPS routing, path/host-based routing, SSL termination, external access
- **Pattern**: Internet → Ingress → Service → Pods

#### ConfigMaps and Secrets - Configuration Management

**Q: "What are the different ways to consume ConfigMaps and when to use each?"**  
**A**:
1. **Environment variables**: Simple key-value config (env.valueFrom.configMapKeyRef)
2. **Volume mounts**: File-based config, automatically updated (spec.volumes.configMap)
3. **Command arguments**: Dynamic command line args (spec.containers.args with valueFrom)

**Q: "How do Secrets differ from ConfigMaps besides base64 encoding?"**  
**A**: 
- **Storage**: Secrets stored in tmpfs (memory), not disk on nodes
- **Access control**: Separate RBAC permissions for secrets
- **Audit**: Secret access separately audited
- **Encryption**: Can be encrypted at rest in etcd with KMS
- **API**: Different API group (v1 vs v1/ConfigMap)

**Q: "What happens when you update a ConfigMap mounted as volume?"**  
**A**: kubelet automatically updates files in volume mount (eventually consistent, ~65s max). Application must watch files and reload config. Environment variables are NOT updated - require pod restart.

#### Volumes and Storage - Data Persistence

**Q: "Explain the relationship between PV, PVC, and StorageClass"**  
**A**:
- **StorageClass**: Template defining storage type and provisioner
- **PVC**: Request for storage with specific requirements  
- **PV**: Actual storage resource (dynamically created by StorageClass or pre-provisioned)
- **Flow**: PVC created → StorageClass provisions PV → PV bound to PVC → Pod uses PVC

**Q: "What are volume access modes and what do they mean in practice?"**  
**A**:
- **ReadWriteOnce (RWO)**: Single node read/write (most common, EBS volumes)
- **ReadOnlyMany (ROX)**: Multiple nodes read-only (shared data distribution)  
- **ReadWriteMany (RWX)**: Multiple nodes read/write (rare, requires distributed storage like EFS)
- **ReadWriteOncePod (RWOP)**: Single pod read/write (Kubernetes 1.22+)

**Q: "How does dynamic volume provisioning work?"**  
**A**: PVC references StorageClass → StorageClass provisioner (CSI driver) creates storage → PV object created representing storage → PV bound to PVC → Pod can use volume. Provisioner handles cloud provider API calls to create actual storage.

### Control Plane Deep Dive

#### API Server - The Gateway

**Q: "What happens during a 'kubectl apply' request?"**  
**A**:
1. Authentication (certificates, tokens, OIDC)
2. Authorization (RBAC, ABAC, Webhook)  
3. Admission controllers (mutating then validating)
4. Schema validation and defaulting
5. Object stored in etcd
6. Watch notifications sent to relevant controllers

**Q: "How does kubectl know what changed in server-side apply?"**  
**A**: Server-side apply uses field management. Each field has an owner (manager). kubectl sends managedFields with ownership info. API server computes diff and resolves conflicts based on field ownership, not entire object comparison.

**Q: "What are admission controllers and why do they matter?"**  
**A**: Plugins that intercept requests after authentication/authorization but before persistence. Mutating controllers modify objects (inject sidecars, set defaults). Validating controllers enforce policies (security, quotas). Examples: PodSecurityPolicy, ResourceQuota, MutatingAdmissionWebhook.

#### etcd - The Database

**Q: "How does etcd ensure consistency in a distributed cluster?"**  
**A**: etcd uses Raft consensus algorithm. Writes go to leader, replicated to majority of nodes before committing. If leader fails, remaining nodes elect new leader. Requires odd number of nodes (3, 5) to maintain quorum. Split-brain prevented by requiring majority for operations.

**Q: "What happens if etcd becomes unavailable?"**  
**A**: API Server returns errors for write operations. Existing workloads continue running (kubelet caches pod specs). Controllers can't react to changes. Recovery requires etcd restoration from backup or rebuilding cluster from scratch.

**Q: "How is Kubernetes data organized in etcd?"**  
**A**: Hierarchical key structure: /registry/pods/namespace/name, /registry/services/namespace/name. Each Kubernetes object type has its own path. Watch operations use etcd's watch API for real-time notifications.

#### Scheduler - Placement Engine

**Q: "Walk through the complete scheduling process"**  
**A**:
1. **Queue**: New pods added to scheduling queue
2. **Filter**: Remove nodes that can't run pod (resources, taints, affinity)
3. **Score**: Rank remaining nodes (resource utilization, affinity preferences)  
4. **Bind**: Update pod spec with chosen node
5. **Assume**: Cache the decision before API server confirms

**Q: "How does the scheduler handle resource requests vs limits?"**  
**A**: Scheduler only considers requests for placement decisions (ensures node has enough capacity). Limits are enforced by kubelet/container runtime on the node. A pod with no requests can be scheduled anywhere but may be evicted under pressure.

**Q: "What happens when scheduler can't place a pod?"**  
**A**: Pod remains in Pending state. Scheduler adds SchedulingFailure event with reason (insufficient resources, node affinity not met, etc.). Pod will be reconsidered when cluster state changes (new nodes, other pods deleted).

#### Controllers - The Automation

**Q: "How does the controller pattern work?"**  
**A**: Watch current state → Compare with desired state → Take action → Repeat. Controllers never directly manipulate resources - they go through API Server. This ensures consistency, audit logging, and authorization. Each controller has a single responsibility.

**Q: "What happens when multiple controllers manage the same resource?"**  
**A**: Controllers use owner references to establish hierarchy. Child objects have ownerReferences pointing to parent. Garbage collection automatically deletes children when parent deleted. Conflicts resolved through field management and strategic merge patches.

**Q: "How does the Deployment controller create pods?"**  
**A**: Deployment controller manages ReplicaSets, not pods directly. Creates new ReplicaSet when deployment updated. ReplicaSet controller creates/deletes pods to match desired replica count. Separation enables rolling updates and rollback functionality.

### Data Plane Deep Dive

#### kubelet - The Node Agent

**Q: "How does kubelet know what pods to run?"**  
**A**: kubelet watches API Server for pods assigned to its node (nodeName field). Also supports static pods from filesystem (/etc/kubernetes/manifests). Maintains desired state by starting/stopping containers via container runtime.

**Q: "What's the relationship between kubelet and container runtime?"**  
**A**: kubelet talks to container runtime via Container Runtime Interface (CRI). kubelet handles pod lifecycle, networking, volumes. Container runtime handles image management and container execution. Separation allows different runtimes (containerd, CRI-O) with same kubelet.

**Q: "How does kubelet handle pod health checks?"**  
**A**: 
- **Liveness**: Restart container if failing
- **Readiness**: Remove from service endpoints if failing  
- **Startup**: Wait for app startup before liveness checks
- **Probes**: HTTP GET, TCP socket, exec command
- **Configuration**: initialDelaySeconds, periodSeconds, timeoutSeconds, failureThreshold

#### kube-proxy - Network Traffic Director

**Q: "How does kube-proxy implement service load balancing?"**  
**A**: 
- **iptables mode**: Creates iptables rules for DNAT from service IP to pod IPs
- **IPVS mode**: Uses IPVS kernel module for better performance and more algorithms
- **userspace mode**: Deprecated, all traffic proxied through kube-proxy process

**Q: "What happens when kube-proxy is down on a node?"**  
**A**: Service networking breaks on that node. Pods on that node can't reach services (no iptables rules). Pods on other nodes can still reach services. Node becomes partially isolated from cluster networking.

### Advanced Architecture Concepts

#### Custom Resources and Operators

**Q: "How do Custom Resources extend Kubernetes?"**  
**A**: Custom Resource Definitions (CRDs) define new resource types stored in etcd. Custom controllers watch these resources and implement domain-specific logic. Pattern: CRD + Controller = Operator. Enables platform-as-a-service functionality.

**Q: "What's the difference between admission controllers and operators?"**  
**A**: 
- **Admission controllers**: Intercept requests during creation, enforce policies
- **Operators**: Watch resources continuously, implement ongoing lifecycle management
- **Timing**: Admission (request time) vs Operator (runtime reconciliation)

#### Multi-tenancy and Security

**Q: "How would you implement hard multi-tenancy in Kubernetes?"**  
**A**: 
- **Separate clusters**: Strongest isolation but highest operational overhead
- **Node isolation**: Dedicated nodes per tenant with taints/tolerations
- **Pod Security**: Pod Security Standards, security contexts, admission controllers
- **Network isolation**: NetworkPolicies, service mesh policies
- **Resource isolation**: ResourceQuotas, LimitRanges per namespace

**Q: "How does RBAC authorization work in detail?"**  
**A**: Subject (User/Group/ServiceAccount) → RoleBinding/ClusterRoleBinding → Role/ClusterRole → Resources/Verbs. API Server checks if subject has permission for specific resource and verb. Roles are additive (union of all applicable roles).

#### Performance and Scaling

**Q: "What are the scaling limits of Kubernetes components?"**  
**A**:
- **Cluster**: 5000 nodes, 150K pods, 300K containers
- **Node**: 110 pods per node (default)
- **Pod**: No inherent limit on containers
- **etcd**: 8GB limit, latency sensitive
- **API Server**: CPU/memory scales with API request rate

**Q: "How does Kubernetes handle node failures?"**  
**A**: 
1. Node Controller detects missing heartbeats (40s default)
2. Marks node NotReady after grace period
3. Pod eviction after 5 minutes (configurable)
4. Controllers create replacement pods on healthy nodes
5. PersistentVolumes detached and reattached to new nodes

### Storage Deep Dive

**Q: "How do CSI drivers work?"**  
**A**: Container Storage Interface provides standard API between Kubernetes and storage systems. CSI driver runs as DaemonSet (node plugin) and Deployment (controller plugin). Handles volume lifecycle: provision, attach, mount, unmount, detach, delete.

**Q: "What's the difference between static and dynamic provisioning?"**  
**A**:
- **Static**: Admin pre-creates PVs, PVCs bind to existing PVs
- **Dynamic**: StorageClass automatically provisions PVs when PVCs created
- **Use cases**: Static for specific hardware, dynamic for cloud environments

**Q: "How does volume expansion work?"**  
**A**: PVC requests larger size → CSI driver expands underlying storage → kubelet expands filesystem. Requires StorageClass with allowVolumeExpansion: true. Some storage types support online expansion, others require pod restart.

### Networking Architecture Deep Dive

**Q: "How does DNS work in Kubernetes?"**  
**A**: CoreDNS runs as pods in kube-system namespace. Creates DNS records:
- Services: service.namespace.svc.cluster.local
- Pods: pod-ip.namespace.pod.cluster.local  
- Headless services: Individual pod records
- Search domains: Auto-completion within namespace

**Q: "What happens during pod startup from networking perspective?"**  
**A**:
1. kubelet calls CNI plugin to set up networking
2. CNI creates network namespace for pod
3. Assigns IP address from node's CIDR range
4. Sets up routing rules for pod communication
5. Configures DNS settings in pod

**Q: "How do NetworkPolicies work?"**  
**A**: Network plugin (Calico, Cilium) watches NetworkPolicy objects and implements firewall rules. Policies are allow-lists - traffic blocked unless explicitly allowed. Can control ingress, egress, or both based on pod/namespace selectors.

### Production Architecture Patterns

**Q: "How would you design a highly available Kubernetes cluster?"**  
**A**:
- **Control plane**: Multiple API servers behind load balancer, etcd cluster across AZs
- **Data plane**: Nodes across multiple AZs, pod anti-affinity rules
- **Applications**: Multiple replicas, PodDisruptionBudgets, health checks
- **Storage**: Replicated storage, regular backups
- **Network**: Multiple ingress controllers, DNS redundancy

**Q: "What are the key considerations for cluster upgrades?"**  
**A**:
- **API version compatibility**: Ensure workloads compatible with new Kubernetes version
- **Control plane first**: Upgrade API server, controller manager, scheduler before nodes  
- **Node pools**: Rolling upgrade of worker nodes
- **Testing**: Validate in staging environment first
- **Rollback plan**: Ability to revert if issues discovered

**Q: "How do you handle secrets at scale?"**  
**A**:
- **External secret management**: HashiCorp Vault, AWS Secrets Manager
- **Encryption at rest**: KMS integration for etcd encryption
- **Rotation**: Automated secret rotation and pod restart
- **Least privilege**: RBAC for secret access
- **Audit**: Monitor secret access patterns

### Troubleshooting with Architecture Knowledge

**Q: "A pod can't reach a service. How do you debug using architecture knowledge?"**  
**A**:
1. **DNS**: Can pod resolve service name? (nslookup from pod)
2. **Endpoints**: Does service have healthy endpoints? (kubectl get endpoints)
3. **Network**: Can pod reach endpoint IPs directly? (ping/telnet from pod)
4. **Proxy**: Are kube-proxy rules correct? (iptables-save | grep service)
5. **Labels**: Do service selectors match pod labels?

**Q: "Pods are stuck in Pending. What's your systematic approach?"**  
**A**:
1. **Describe pod**: Check events for scheduling failures
2. **Node resources**: kubectl top nodes for capacity
3. **Node conditions**: kubectl describe nodes for pressure conditions
4. **Scheduler**: Check kube-scheduler logs for errors
5. **Taints/affinity**: Verify scheduling constraints
6. **Resource quotas**: Check namespace quotas

**Q: "Cluster is slow. How do you diagnose performance issues?"**  
**A**:
1. **API Server**: Check API request latency and rate
2. **etcd**: Monitor etcd latency and storage performance
3. **Network**: Check inter-node connectivity and CNI performance
4. **Nodes**: Monitor node resource utilization
5. **Applications**: Profile application performance and resource usage

## Architecture Best Practices Summary

### Design Principles
1. **Embrace Declarative Configuration**: Describe desired state, let Kubernetes converge
2. **Design for Failure**: Assume components will fail, build resilience
3. **Separate Concerns**: Use appropriate abstractions (Deployments, Services, ConfigMaps)
4. **Security by Default**: Apply principle of least privilege everywhere
5. **Resource Awareness**: Always specify requests/limits, understand QoS implications

### Production Architecture Checklist
- [ ] **High Availability**: Multiple replicas for all components
- [ ] **Security**: RBAC, Pod Security Standards, Network Policies implemented
- [ ] **Resource Management**: Quotas, LimitRanges, proper requests/limits
- [ ] **Monitoring**: Comprehensive observability for all layers
- [ ] **Backup Strategy**: etcd backups, persistent volume snapshots
- [ ] **Disaster Recovery**: Multi-region strategy, documented procedures

### Troubleshooting Architecture Issues
1. **Start with Control Plane**: Check API Server, etcd, controllers
2. **Verify Data Plane**: Check kubelet, container runtime, networking
3. **Follow the Data Path**: Trace request flow through all components
4. **Check Resource Constraints**: Verify adequate CPU/memory/storage
5. **Validate Configuration**: Ensure RBAC, quotas, policies are correct

**Remember**: Kubernetes architecture is complex but logical. Every component has a specific purpose and well-defined interfaces. Understanding these relationships enables effective troubleshooting and optimal system design.