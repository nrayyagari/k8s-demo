# AWS EKS: Production Kubernetes on AWS

## WHY EKS Matters for Production

**Problem**: Vanilla Kubernetes requires managing control plane, networking, security, and AWS service integration manually  
**Solution**: EKS provides managed Kubernetes with deep AWS integration, but requires understanding AWS-specific patterns and gotchas

**Business Reality**: EKS is not just Kubernetes + AWS. It's a different operational model with unique benefits, costs, and failure modes.

## EKS vs Vanilla Kubernetes: What Changes

### What AWS Manages for You
```yaml
✅ Control Plane:
  - API Server (multiple AZs, auto-scaling)
  - etcd (managed, backed up automatically)
  - Scheduler and Controllers
  - Automatic updates and patches
  - 99.95% SLA

✅ Networking:
  - VPC integration (pods get real VPC IPs)
  - Load balancer provisioning
  - DNS integration with Route53
  - Security group management

✅ Security:
  - IAM integration for authentication
  - Encryption at rest and in transit
  - Compliance certifications (SOC, PCI, HIPAA)
```

### What You Still Own
```yaml
❌ Worker Nodes:
  - EC2 instances or Fargate (your choice)
  - Node scaling and maintenance
  - OS updates and security patches
  - Instance type selection and costs

❌ Application Layer:
  - Pod security and policies
  - Application secrets management
  - Service mesh and observability
  - Backup and disaster recovery
```

## The EKS Control Plane: What's Different

### Authentication: IAM Instead of Certificates

**Vanilla Kubernetes**: Certificate-based authentication
```bash
kubectl config set-credentials user --client-certificate=user.crt --client-key=user.key
```

**EKS**: IAM-based authentication via AWS CLI
```bash
# Authentication happens through AWS CLI/SDK
aws eks update-kubeconfig --name my-cluster --region us-west-2

# Under the hood: AWS STS token exchange
aws sts get-caller-identity
# Returns: IAM user/role that kubectl will use
```

**Production Pattern**: IAM Roles for Service Accounts (IRSA)
```yaml
# Service account with IAM role annotation
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-reader
  namespace: production
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/S3ReadOnlyRole
---
# Pod automatically gets AWS credentials
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-s3-access
spec:
  template:
    spec:
      serviceAccountName: s3-reader  # Inherits IAM permissions
      containers:
      - name: app
        image: my-app:latest
        # No AWS credentials needed in container
        # AWS SDK automatically uses IRSA token
```

### Authorization: aws-auth ConfigMap

**The Critical ConfigMap**: Maps IAM identities to Kubernetes RBAC
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::123456789:role/NodeInstanceRole
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: arn:aws:iam::123456789:role/DeveloperRole
      username: developer
      groups:
        - developers
  mapUsers: |
    - userarn: arn:aws:iam::123456789:user/admin
      username: admin
      groups:
        - system:masters
```

**Production Crisis Pattern**: Lost access to cluster
```bash
# Common scenario: Someone deleted aws-auth configmap
# Recovery: Use EKS console or AWS CLI with cluster creator permissions

# Check who created the cluster (has permanent access)
aws eks describe-cluster --name my-cluster --query 'cluster.createdBy'

# Recreate aws-auth configmap
kubectl apply -f aws-auth-backup.yaml
```

## EKS Networking: VPC Native with Gotchas

### AWS VPC CNI: Pods Get Real IP Addresses

**How it works**:
```bash
1. Each worker node pre-allocates ENIs (Elastic Network Interfaces)
2. Each ENI gets multiple secondary IP addresses from VPC subnet
3. Pods get assigned real VPC IP addresses (not overlay network)
4. Pods can communicate directly with AWS services using VPC routing
```

**Benefits**:
- Direct VPC integration (security groups, NACLs work)
- No NAT overhead for pod-to-pod communication
- Native AWS service integration (RDS, ElastiCache, etc.)

**Gotchas**:
```yaml
IP Exhaustion:
  Problem: "Too many pods" error despite having CPU/memory
  Cause: VPC subnet out of available IPs
  Solution: Larger subnets or prefix delegation

ENI Limits:
  Problem: Pods stuck in Pending despite node capacity
  Cause: Instance type ENI limits (t3.micro = 2 ENIs, 6 IPs total)
  Solution: Larger instance types or IP prefix delegation

Cross-AZ Traffic Costs:
  Problem: High data transfer costs
  Cause: Pods scheduled across AZs communicate frequently
  Solution: Pod anti-affinity and topology spread constraints
```

### Load Balancer Integration

#### Application Load Balancer (ALB) - Most Common
```yaml
# AWS Load Balancer Controller creates ALB automatically
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-app-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip  # Direct to pod IPs
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/ssl-cert: arn:aws:acm:us-west-2:123:certificate/abc
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS-1-2-2017-01
spec:
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-app-service
            port:
              number: 80
```

#### Network Load Balancer (NLB) - High Performance
```yaml
# For high-performance, low-latency requirements
apiVersion: v1
kind: Service
metadata:
  name: high-perf-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: tcp
spec:
  type: LoadBalancer
  selector:
    app: high-perf-app
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
```

## IAM for Pods: Service Accounts and IRSA

### The IRSA Pattern: Secure AWS Service Access

**Problem**: How do pods access AWS services without embedding credentials?
**Solution**: IAM Roles for Service Accounts (IRSA)

#### Step 1: Create OIDC Identity Provider
```bash
# One-time cluster setup
eksctl utils associate-iam-oidc-provider --cluster my-cluster --approve

# Or via AWS CLI
aws eks describe-cluster --name my-cluster --query "cluster.identity.oidc.issuer"
# Use output to create OIDC identity provider in IAM
```

#### Step 2: Create IAM Role with Trust Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/EXAMPLE"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-west-2.amazonaws.com/id/EXAMPLE:sub": "system:serviceaccount:production:s3-access-sa",
          "oidc.eks.us-west-2.amazonaws.com/id/EXAMPLE:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

#### Step 3: Annotate Service Account
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-access-sa
  namespace: production
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/S3AccessRole
```

#### Step 4: Use in Pods
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: s3-reader-app
spec:
  template:
    spec:
      serviceAccountName: s3-access-sa
      containers:
      - name: app
        image: my-app:latest
        env:
        - name: AWS_ROLE_ARN
          value: arn:aws:iam::123456789:role/S3AccessRole
        - name: AWS_WEB_IDENTITY_TOKEN_FILE
          value: /var/run/secrets/eks.amazonaws.com/serviceaccount/token
        # AWS SDK automatically uses these environment variables
```

## Common AWS Service Integrations

### S3 Access Pattern
```yaml
# IAM Policy for S3 access
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::my-app-bucket/*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::my-app-bucket"
    }
  ]
}

# Application code (no hardcoded credentials)
import boto3
s3 = boto3.client('s3')  # Automatically uses IRSA
s3.download_file('my-app-bucket', 'config.json', '/tmp/config.json')
```

### RDS Access with Security Groups
```yaml
# Database security group allows EKS worker nodes
resource "aws_security_group_rule" "rds_from_eks" {
  type                     = "ingress"
  from_port               = 5432
  to_port                 = 5432
  protocol                = "tcp"
  source_security_group_id = module.eks.worker_security_group_id
  security_group_id       = aws_security_group.rds.id
}

# Pod connects using RDS endpoint
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
data:
  username: cG9zdGdyZXM=  # postgres
  password: base64-encoded-password
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  template:
    spec:
      containers:
      - name: app
        image: web-app:latest
        env:
        - name: DB_HOST
          value: myapp.cluster-xyz.us-west-2.rds.amazonaws.com
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
```

### ElastiCache (Redis) Integration
```yaml
# Redis cluster accessible from EKS
resource "aws_elasticache_subnet_group" "redis" {
  name       = "redis-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

resource "aws_elasticache_replication_group" "redis" {
  description          = "Redis for EKS applications"
  replication_group_id = "myapp-redis"
  port                 = 6379
  parameter_group_name = "default.redis7"
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]
}

# Application configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
data:
  redis-url: myapp-redis.xyz.cache.amazonaws.com:6379
```

### AWS Secrets Manager Integration
```yaml
# Install AWS Secrets Manager CSI Driver
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver --namespace kube-system

# SecretProviderClass for AWS Secrets Manager
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: app-secrets
  namespace: production
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "production/app/database"
        objectType: "secretsmanager"
        jmesPath:
          - path: "username"
            objectAlias: "db-username"
          - path: "password"
            objectAlias: "db-password"
---
# Pod using secrets from AWS Secrets Manager
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-secrets
spec:
  template:
    spec:
      serviceAccountName: secrets-reader-sa  # Needs SecretsManager IAM permissions
      containers:
      - name: app
        image: my-app:latest
        volumeMounts:
        - name: secrets-store
          mountPath: "/mnt/secrets-store"
          readOnly: true
        env:
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: db-username
      volumes:
      - name: secrets-store
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: "app-secrets"
```

## Storage: EBS, EFS, and FSx Integration

### EBS (Block Storage) - Most Common
```yaml
# StorageClass for gp3 EBS volumes
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
---
# PVC using EBS
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-storage
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: ebs-gp3
  resources:
    requests:
      storage: 100Gi
```

### EFS (Shared File Storage)
```yaml
# StorageClass for EFS
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap  # Creates access points
  fileSystemId: fs-123456789
  directoryPerms: "700"
---
# PVC for shared storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-storage
spec:
  accessModes:
  - ReadWriteMany  # Multiple pods can read/write
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi
```

### FSx for Lustre (High Performance)
```yaml
# For HPC workloads requiring high IOPS
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fsx-lustre
provisioner: fsx.csi.aws.com
parameters:
  subnetId: subnet-12345
  securityGroupIds: sg-12345
  deploymentType: PERSISTENT_1
  perUnitStorageThroughput: "200"
```

## Security: EKS-Specific Patterns

### Pod Security Groups (Advanced Networking)
```yaml
# Assign specific security groups to pods
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database-app
spec:
  template:
    metadata:
      annotations:
        # Pod gets this security group instead of node security group
        vpc.amazonaws.com/pod-eni: '[{"securityGroups":["sg-database"]}]'
    spec:
      containers:
      - name: db
        image: postgres:13
```

### Network Policies with AWS Security Groups
```yaml
# Calico NetworkPolicy working with AWS Security Groups
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-access
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: web-app
    ports:
    - protocol: TCP
      port: 5432
```

### KMS Encryption Integration
```yaml
# Encrypt EKS secrets with AWS KMS
# Configured at cluster creation time
eksctl create cluster \
  --name my-cluster \
  --encryption-config encryption-config.yaml

# encryption-config.yaml
kind: EncryptionConfig
apiVersion: v1
resources:
- resources:
  - secrets
  providers:
  - kms:
      name: arn:aws:kms:us-west-2:123456789:key/12345678-1234-1234-1234-123456789012
      cachesize: 1000
  - identity: {}
```

## Monitoring and Logging: AWS Native Integration

### CloudWatch Container Insights
```yaml
# Deploy CloudWatch agent as DaemonSet
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cloudwatch-agent
  namespace: amazon-cloudwatch
spec:
  selector:
    matchLabels:
      name: cloudwatch-agent
  template:
    spec:
      serviceAccountName: cloudwatch-agent
      containers:
      - name: cloudwatch-agent
        image: amazon/cloudwatch-agent:1.247350.0b251814
        env:
        - name: CW_CONFIG_CONTENT
          value: |
            {
              "metrics": {
                "namespace": "CWAgent",
                "metrics_collected": {
                  "cpu": {"measurement": ["cpu_usage_idle", "cpu_usage_iowait"]},
                  "disk": {"measurement": ["used_percent"]},
                  "diskio": {"measurement": ["io_time"]},
                  "mem": {"measurement": ["mem_used_percent"]},
                  "swap": {"measurement": ["swap_used_percent"]}
                }
              }
            }
```

### Fluent Bit for Log Shipping
```yaml
# Ship logs to CloudWatch Logs
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: amazon-cloudwatch
spec:
  selector:
    matchLabels:
      name: fluent-bit
  template:
    spec:
      serviceAccountName: fluent-bit
      containers:
      - name: fluent-bit
        image: amazon/aws-for-fluent-bit:2.28.4
        env:
        - name: AWS_REGION
          value: us-west-2
        - name: CLUSTER_NAME
          value: my-cluster
        - name: HTTP_SERVER
          value: "On"
        - name: HTTP_PORT
          value: "2020"
        - name: READ_FROM_HEAD
          value: "Off"
        - name: READ_FROM_TAIL
          value: "On"
```

## Cost Optimization: EKS-Specific Strategies

### Spot Instances with Managed Node Groups
```yaml
# Terraform configuration for mixed instance types
resource "aws_eks_node_group" "spot_nodes" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "spot-nodes"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id

  capacity_type = "SPOT"
  
  scaling_config {
    desired_size = 3
    max_size     = 10
    min_size     = 1
  }

  instance_types = ["t3.medium", "t3.large", "t3a.medium", "t3a.large"]

  update_config {
    max_unavailable = 1
  }

  # Handle spot interruptions gracefully
  tags = {
    "k8s.io/cluster-autoscaler/enabled" = "true"
    "k8s.io/cluster-autoscaler/my-cluster" = "owned"
  }
}
```

### Fargate for Serverless Workloads
```yaml
# Fargate profile for specific namespace
resource "aws_eks_fargate_profile" "batch_jobs" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "batch-jobs"
  pod_execution_role_arn = aws_iam_role.fargate_pod.arn
  subnet_ids            = aws_subnet.private[*].id

  selector {
    namespace = "batch-processing"
    labels = {
      workload-type = "batch"
    }
  }
}

# Pods in this namespace run on Fargate
apiVersion: v1
kind: Namespace
metadata:
  name: batch-processing
  labels:
    workload-type: batch
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch-processor
  namespace: batch-processing
spec:
  template:
    metadata:
      labels:
        workload-type: batch
    spec:
      containers:
      - name: processor
        image: batch-processor:latest
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
```

### Cluster Autoscaler Configuration
```yaml
# Cluster Autoscaler for cost optimization
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  template:
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
      - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.21.0
        name: cluster-autoscaler
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/my-cluster
        - --balance-similar-node-groups
        - --skip-nodes-with-system-pods=false
        env:
        - name: AWS_REGION
          value: us-west-2
```

## Disaster Recovery and Backup

### EBS Volume Snapshots
```yaml
# VolumeSnapshotClass for EBS snapshots
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: ebs-vsc
driver: ebs.csi.aws.com
deletionPolicy: Delete
parameters:
  tagSpecification_1: "Name=EKS-Backup"
  tagSpecification_2: "Environment=Production"
---
# Create snapshot of PVC
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: database-snapshot
spec:
  volumeSnapshotClassName: ebs-vsc
  source:
    persistentVolumeClaimName: database-pvc
```

### Cross-Region Cluster Backup
```bash
# Velero with S3 backend for cluster backup
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts/
helm install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace \
  --set configuration.provider=aws \
  --set configuration.backupStorageLocation.bucket=my-cluster-backups \
  --set configuration.backupStorageLocation.config.region=us-west-2 \
  --set serviceAccount.server.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::123456789:role/VeleroRole

# Schedule regular backups
velero schedule create daily-backup --schedule="@daily" --ttl 720h0m0s
```

## EKS Production Troubleshooting

### Common EKS-Specific Issues

#### Issue 1: Pods Can't Pull Images from ECR
```bash
# Symptoms: ImagePullBackOff errors
kubectl describe pod failing-pod | grep -A 5 "Failed to pull image"

# Root Cause: Node IAM role missing ECR permissions
# Solution: Add ECR policy to node role
aws iam attach-role-policy \
  --role-name NodeInstanceRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
```

#### Issue 2: Load Balancer Not Creating
```bash
# Symptoms: LoadBalancer service stuck in Pending
kubectl get svc my-service
# Shows: EXTERNAL-IP <pending>

# Debug: Check AWS Load Balancer Controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Common fixes:
# 1. Install AWS Load Balancer Controller
# 2. Verify IAM permissions for controller
# 3. Check subnet tags for load balancer discovery
```

#### Issue 3: Pods Can't Access AWS Services
```bash
# Symptoms: AWS API calls return 403 Forbidden
kubectl logs my-pod | grep -i forbidden

# Debug IRSA configuration:
# 1. Check service account annotation
kubectl describe sa my-service-account | grep role-arn

# 2. Verify IAM role trust policy
aws iam get-role --role-name MyPodRole

# 3. Check OIDC provider exists
aws iam list-open-id-connect-providers
```

#### Issue 4: Cross-AZ Data Transfer Costs
```bash
# Symptoms: High AWS bill for data transfer
# Root cause: Pods in different AZs communicating frequently

# Solution: Pod topology spread constraints
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cost-optimized-app
spec:
  template:
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: cost-optimized-app
```

## EKS Best Practices Checklist

### Security
- [ ] Enable EKS cluster endpoint private access
- [ ] Use IRSA instead of storing AWS credentials in pods
- [ ] Enable EKS audit logging to CloudWatch
- [ ] Encrypt secrets with AWS KMS
- [ ] Use Pod Security Standards
- [ ] Implement network policies with Calico or AWS VPC CNI

### Networking
- [ ] Use private subnets for worker nodes
- [ ] Configure NAT Gateway for outbound internet access
- [ ] Tag subnets appropriately for load balancer discovery
- [ ] Use AWS Load Balancer Controller for ingress
- [ ] Monitor cross-AZ traffic costs

### Storage
- [ ] Use gp3 EBS volumes for better price/performance
- [ ] Enable EBS volume encryption
- [ ] Implement backup strategy with snapshots
- [ ] Use EFS for shared storage requirements
- [ ] Monitor storage costs and usage

### Cost Optimization
- [ ] Use Spot instances for non-critical workloads
- [ ] Implement cluster autoscaler
- [ ] Use Fargate for sporadic batch workloads
- [ ] Monitor and right-size instance types
- [ ] Set resource requests and limits appropriately

### Monitoring
- [ ] Enable CloudWatch Container Insights
- [ ] Set up log aggregation with Fluent Bit
- [ ] Monitor EKS control plane metrics
- [ ] Set up alerts for node and pod failures
- [ ] Track AWS service quotas and limits

### Disaster Recovery
- [ ] Implement multi-AZ worker node deployment
- [ ] Regular EBS volume snapshots
- [ ] Cross-region backup strategy with Velero
- [ ] Document and test recovery procedures
- [ ] Maintain infrastructure as code (Terraform/CloudFormation)

## EKS vs Other Kubernetes Platforms

### EKS vs Self-Managed K8s on EC2
```yaml
EKS Advantages:
  ✅ Managed control plane (99.95% SLA)
  ✅ Automatic updates and security patches
  ✅ Deep AWS service integration
  ✅ Native IAM authentication
  ✅ Compliance certifications

Self-Managed Advantages:
  ✅ Full control over Kubernetes version
  ✅ Custom control plane configuration
  ✅ Lower costs (no EKS service fee)
  ✅ Custom networking plugins

Cost Comparison:
  EKS: $0.10/hour control plane + EC2 costs
  Self-managed: Only EC2 costs + operational overhead
```

### EKS vs GKE vs AKS
```yaml
EKS (AWS):
  - Best AWS service integration
  - IAM-based authentication
  - Strong enterprise features
  - Higher operational complexity

GKE (Google):
  - Most Kubernetes-native features
  - Autopilot for serverless experience
  - Best multi-cloud portability
  - Strong ML/AI integration

AKS (Azure):
  - Best Windows container support
  - Strong hybrid cloud features
  - Azure Active Directory integration
  - Good developer tooling
```

## Quick Reference Commands

### EKS Cluster Management
```bash
# Create kubeconfig
aws eks update-kubeconfig --name my-cluster --region us-west-2

# Get cluster info
aws eks describe-cluster --name my-cluster

# List node groups
aws eks list-nodegroups --cluster-name my-cluster

# Update node group
aws eks update-nodegroup-config --cluster-name my-cluster --nodegroup-name my-nodes
```

### IAM and IRSA Debugging
```bash
# Check current AWS identity
aws sts get-caller-identity

# Get OIDC issuer URL
aws eks describe-cluster --name my-cluster --query "cluster.identity.oidc.issuer"

# Test service account token
kubectl exec -it my-pod -- env | grep AWS
```

### Load Balancer Troubleshooting
```bash
# Check AWS Load Balancer Controller
kubectl get deployment -n kube-system aws-load-balancer-controller

# View controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check ingress status
kubectl describe ingress my-ingress
```

### Cost and Resource Monitoring
```bash
# Node resource usage
kubectl top nodes

# Pod resource usage by namespace
kubectl top pods --all-namespaces --sort-by=memory

# Get AWS costs (requires AWS CLI with billing access)
aws ce get-cost-and-usage --time-period Start=2023-01-01,End=2023-01-31 --granularity MONTHLY --metrics BlendedCost
```

**Remember**: EKS is Kubernetes + AWS, not just Kubernetes on AWS. Understanding the integration points, IAM patterns, and AWS-specific networking is crucial for production success.