# Kubernetes API: Enterprise Automation & Platform Engineering

## WHY the Kubernetes API Is Your Platform's Foundation

**Problem**: kubectl is convenient but limited; enterprise platforms need programmatic control, automation, and custom tooling  
**Solution**: Kubernetes API provides the foundation for platform engineering, GitOps, operators, and enterprise automation

## **The $10M Platform Investment: Why API Mastery Matters**

**Business Context**: Fortune 500 company building internal developer platform  
**Challenge**: 500+ engineering teams, 1000+ applications, manual kubectl operations  
**Investment**: $10M in platform engineering team over 3 years  
**Outcome**: 90% reduction in deployment time, 50% fewer production incidents  
**Key**: Deep Kubernetes API mastery enabling automation, self-service, and standardization

### **The API Evolution: From Manual to Automated**
- **kubectl Era (2014-2017)**: Manual operations, YAML files, imperative commands
- **GitOps Era (2018-2020)**: Infrastructure as Code, CI/CD integration, declarative workflows
- **Platform Era (2021+)**: Custom operators, developer platforms, policy-as-code
- **AI-Assisted Era (2024+)**: Intelligent automation, predictive scaling, self-healing systems

## The Strategic Questions

**Platform Engineering**: "How do I build self-service infrastructure for 500 development teams?"  
**Automation**: "How do I eliminate manual operations and human error?"  
**Compliance**: "How do I enforce security policies and governance at scale?"  
**Innovation**: "How do I enable rapid experimentation while maintaining stability?"

## **Production Crisis Scenario: API-Driven Incident Response**

**Situation**: Black Friday, payment service pods crashing, manual intervention too slow  
**Business Impact**: $25K/minute revenue loss, customer experience degradation  
**Traditional Response**: SSH to nodes, kubectl debugging, manual scaling - 45 minutes  
**API-Driven Response**: Automated detection → API calls → Auto-scaling → Resolution in 3 minutes  
**Result**: $1M+ revenue saved through API automation

## API Structure Fundamentals

### API Groups and Versions
```
/api/v1                          # Core API group (legacy)
/apis/apps/v1                    # apps API group
/apis/networking.k8s.io/v1       # networking API group
/apis/batch/v1                   # batch API group
/apis/apiextensions.k8s.io/v1    # CRD API group
```

### Basic API Object Structure
```yaml
apiVersion: apps/v1    # API group and version
kind: Deployment       # Resource type
metadata:             # Object metadata
  name: my-app
  namespace: default
spec:                 # Desired state
  replicas: 3
status:               # Current state (read-only)
  replicas: 3
  readyReplicas: 3
```

### Common API Endpoints
```bash
# Core resources (pods, services)
/api/v1/namespaces/{namespace}/pods
/api/v1/namespaces/{namespace}/services

# Apps resources (deployments)
/apis/apps/v1/namespaces/{namespace}/deployments

# Cluster-scoped resources
/api/v1/nodes
/api/v1/persistentvolumes
```

## Files in This Directory

1. **SIMPLE-KUBERNETES-API.yaml** - Basic API interaction examples and patterns
2. **01-api-discovery.yaml** - API exploration and discovery techniques
3. **02-direct-api-calls.yaml** - HTTP API calls with curl and authentication
4. **03-custom-resources.yaml** - CRDs and custom API resources

## Quick Start

```bash
# Start kubectl proxy for API access
kubectl proxy --port=8080 &

# Explore API endpoints
curl http://localhost:8080/api/v1
curl http://localhost:8080/apis/apps/v1

# List resources
curl http://localhost:8080/api/v1/namespaces/default/pods
curl http://localhost:8080/apis/apps/v1/namespaces/default/deployments

# Apply YAML examples
kubectl apply -f SIMPLE-KUBERNETES-API.yaml
```

## API Discovery and Exploration

### Find Available Resources
```bash
# List all API groups and resources
kubectl api-resources

# List API versions
kubectl api-versions

# Get resource details
kubectl explain deployment
kubectl explain deployment.spec

# Server capabilities
kubectl version
kubectl cluster-info
```

## Direct API Access Patterns

### Basic CRUD Operations
```bash
# CREATE - POST resource
curl -X POST \
  http://localhost:8080/api/v1/namespaces/default/pods \
  -H "Content-Type: application/yaml" \
  -d @pod.yaml

# READ - GET resource
curl http://localhost:8080/api/v1/namespaces/default/pods/my-pod

# UPDATE - PATCH resource
curl -X PATCH \
  http://localhost:8080/api/v1/namespaces/default/pods/my-pod \
  -H "Content-Type: application/merge-patch+json" \
  -d '{"metadata":{"labels":{"version":"2.0"}}}'

# DELETE - Remove resource
curl -X DELETE \
  http://localhost:8080/api/v1/namespaces/default/pods/my-pod
```

### Query and Filtering
```bash
# Label selectors
curl "http://localhost:8080/api/v1/namespaces/default/pods?labelSelector=app=nginx"

# Field selectors  
curl "http://localhost:8080/api/v1/namespaces/default/pods?fieldSelector=status.phase=Running"

# Watch for changes
curl "http://localhost:8080/api/v1/namespaces/default/pods?watch=true"
```

## Authentication Methods

### Service Account (In-Cluster)
```bash
# Use service account token
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl -H "Authorization: Bearer $TOKEN" \
  https://kubernetes.default.svc/api/v1/namespaces/default/pods
```

### External Access
```bash
# Use kubeconfig credentials
kubectl config view --raw --minify

# Client certificates
curl --cert client.crt --key client.key --cacert ca.crt \
  https://kubernetes-api:6443/api/v1/namespaces
```

## **Enterprise API Programming Patterns**

### **Production Python Controller Example**
```python
import asyncio
import logging
from kubernetes import client, config, watch
from kubernetes.client.rest import ApiException
import time
import json

class ProductionPaymentController:
    """
    Enterprise-grade controller for payment service automation
    Handles auto-scaling, failover, and compliance requirements
    """
    
    def __init__(self):
        config.load_incluster_config()  # Production: in-cluster config
        self.v1 = client.CoreV1Api()
        self.apps_v1 = client.AppsV1Api()
        self.autoscaling_v1 = client.AutoscalingV1Api()
        self.custom_api = client.CustomObjectsApi()
        
        # Business configuration
        self.payment_namespace = "payments"
        self.critical_services = ["payment-processor", "fraud-detection"]
        self.max_replicas = 50  # Business limit for cost control
        self.revenue_per_minute = 25000  # $25K/minute during peak
        
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger(__name__)
    
    async def watch_payment_health(self):
        """
        Production monitoring loop for payment services
        Implements business-aware scaling and incident response
        """
        w = watch.Watch()
        
        try:
            # Watch pod events for payment services
            for event in w.stream(
                self.v1.list_namespaced_pod,
                namespace=self.payment_namespace,
                label_selector="app.kubernetes.io/name in (payment-processor,fraud-detection)",
                timeout_seconds=300
            ):
                pod = event['object']
                event_type = event['type']
                
                await self.handle_payment_event(event_type, pod)
                
        except ApiException as e:
            self.logger.error(f"API error watching pods: {e}")
            await asyncio.sleep(30)  # Exponential backoff in production
            await self.watch_payment_health()  # Restart watch
    
    async def handle_payment_event(self, event_type: str, pod):
        """
        Business-aware event handling for payment services
        """
        pod_name = pod.metadata.name
        pod_phase = pod.status.phase if pod.status else "Unknown"
        service_name = pod.metadata.labels.get("app.kubernetes.io/name", "unknown")
        
        # Business context logging
        self.logger.info(
            f"Payment Event: {event_type} | Pod: {pod_name} | "
            f"Service: {service_name} | Phase: {pod_phase}",
            extra={
                "business.service": service_name,
                "business.criticality": "high",
                "business.revenue_impact": "direct"
            }
        )
        
        if event_type == "DELETED" and service_name in self.critical_services:
            await self.handle_critical_pod_loss(service_name, pod_name)
        
        elif pod_phase == "Pending" and service_name in self.critical_services:
            await self.handle_pod_scheduling_delay(service_name, pod_name, pod)
    
    async def handle_critical_pod_loss(self, service_name: str, pod_name: str):
        """
        Immediate response to critical payment service pod loss
        Business requirement: <30 second response time
        """
        try:
            # Get current deployment state
            deployment = self.apps_v1.read_namespaced_deployment(
                name=service_name,
                namespace=self.payment_namespace
            )
            
            current_replicas = deployment.status.ready_replicas or 0
            desired_replicas = deployment.spec.replicas
            
            # Business logic: Critical service needs minimum viable capacity
            min_viable_replicas = 3 if service_name == "payment-processor" else 2
            
            if current_replicas < min_viable_replicas:
                # Emergency scaling
                emergency_replicas = min(min_viable_replicas * 2, self.max_replicas)
                
                self.logger.critical(
                    f"EMERGENCY SCALING: {service_name} below minimum capacity. "
                    f"Scaling from {desired_replicas} to {emergency_replicas}",
                    extra={
                        "business.action": "emergency_scaling",
                        "business.revenue_risk": f"${self.revenue_per_minute}/minute",
                        "business.sla_violation": True
                    }
                )
                
                # Scale deployment immediately
                deployment.spec.replicas = emergency_replicas
                self.apps_v1.patch_namespaced_deployment(
                    name=service_name,
                    namespace=self.payment_namespace,
                    body=deployment
                )
                
                # Alert business stakeholders
                await self.send_business_alert(
                    severity="critical",
                    message=f"Payment service {service_name} emergency scaling triggered",
                    revenue_impact=self.revenue_per_minute
                )
                
        except ApiException as e:
            self.logger.error(f"Failed to handle critical pod loss: {e}")
    
    async def handle_pod_scheduling_delay(self, service_name: str, pod_name: str, pod):
        """
        Handle pods stuck in Pending state - often resource constraints
        """
        # Check if pod has been pending too long (business SLA: 60 seconds)
        creation_time = pod.metadata.creation_timestamp
        current_time = time.time()
        pending_duration = current_time - creation_time.timestamp()
        
        if pending_duration > 60:  # 60 second SLA
            # Analyze scheduling failure
            pod_conditions = pod.status.conditions or []
            scheduling_issues = []
            
            for condition in pod_conditions:
                if condition.type == "PodScheduled" and condition.status == "False":
                    scheduling_issues.append(condition.reason)
            
            self.logger.warning(
                f"Pod {pod_name} pending for {pending_duration:.1f}s. "
                f"Issues: {scheduling_issues}",
                extra={
                    "business.sla_violation": True,
                    "business.scheduling_delay": pending_duration,
                    "scheduling.issues": scheduling_issues
                }
            )
            
            # Potential automated remediation
            if "Insufficient cpu" in str(scheduling_issues):
                await self.request_cluster_scaling()
            elif "Insufficient memory" in str(scheduling_issues):
                await self.optimize_memory_requests(service_name)
    
    async def implement_chaos_engineering(self):
        """
        Production chaos engineering through API
        Controlled failure injection for resilience testing
        """
        if not self.is_chaos_window():
            return
        
        try:
            # Find non-critical payment pods for chaos testing
            pods = self.v1.list_namespaced_pod(
                namespace=self.payment_namespace,
                label_selector="chaos.engineering=enabled,business.criticality!=high"
            )
            
            if pods.items:
                target_pod = pods.items[0]
                
                self.logger.info(
                    f"Chaos Engineering: Terminating pod {target_pod.metadata.name}",
                    extra={
                        "chaos.experiment": "pod_termination",
                        "chaos.target": target_pod.metadata.name,
                        "business.impact": "minimal"
                    }
                )
                
                # Graceful termination for chaos testing
                self.v1.delete_namespaced_pod(
                    name=target_pod.metadata.name,
                    namespace=self.payment_namespace,
                    grace_period_seconds=30
                )
                
        except ApiException as e:
            self.logger.error(f"Chaos engineering error: {e}")
    
    def is_chaos_window(self) -> bool:
        """Business logic: Only run chaos during safe hours"""
        import datetime
        now = datetime.datetime.now()
        # Safe hours: 2-4 AM UTC (low traffic)
        return 2 <= now.hour <= 4 and now.weekday() < 5  # Weekdays only
    
    async def send_business_alert(self, severity: str, message: str, revenue_impact: int):
        """
        Send alerts to business stakeholders with revenue context
        """
        alert_payload = {
            "severity": severity,
            "message": message,
            "revenue_impact_per_minute": revenue_impact,
            "service": "payment-platform",
            "cluster": "production-us-east-1",
            "timestamp": time.time()
        }
        
        # Implementation would integrate with PagerDuty, Slack, etc.
        self.logger.info(f"Business Alert: {alert_payload}")

# Production deployment
if __name__ == "__main__":
    controller = ProductionPaymentController()
    asyncio.run(controller.watch_payment_health())
```

### **Go Client for High-Performance Operations**
```go
package main

import (
    "context"
    "fmt"
    "log"
    "time"
    
    "k8s.io/client-go/kubernetes"
    "k8s.io/client-go/rest"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/fields"
    "k8s.io/apimachinery/pkg/watch"
)

// ProductionAPIClient handles high-performance Kubernetes operations
type ProductionAPIClient struct {
    clientset *kubernetes.Clientset
    namespace string
}

func NewProductionAPIClient() (*ProductionAPIClient, error) {
    // Production: Use in-cluster configuration
    config, err := rest.InClusterConfig()
    if err != nil {
        return nil, fmt.Errorf("failed to create in-cluster config: %v", err)
    }
    
    // Optimize for high-throughput operations
    config.QPS = 100    // Queries per second
    config.Burst = 200  // Burst capacity
    
    clientset, err := kubernetes.NewForConfig(config)
    if err != nil {
        return nil, fmt.Errorf("failed to create clientset: %v", err)
    }
    
    return &ProductionAPIClient{
        clientset: clientset,
        namespace: "production",
    }, nil
}

// WatchPaymentPods monitors payment service pods with business context
func (c *ProductionAPIClient) WatchPaymentPods(ctx context.Context) error {
    watchlist := cache.NewListWatchFromClient(
        c.clientset.CoreV1().RESTClient(),
        "pods",
        c.namespace,
        fields.SelectorFromSet(map[string]string{
            "app": "payment-service",
        }),
    )
    
    _, controller := cache.NewInformer(
        watchlist,
        &v1.Pod{},
        10*time.Second, // Resync period
        cache.ResourceEventHandlerFuncs{
            AddFunc: func(obj interface{}) {
                pod := obj.(*v1.Pod)
                log.Printf("Payment pod added: %s", pod.Name)
                c.handlePaymentPodEvent("ADDED", pod)
            },
            DeleteFunc: func(obj interface{}) {
                pod := obj.(*v1.Pod)
                log.Printf("Payment pod deleted: %s", pod.Name)
                c.handlePaymentPodEvent("DELETED", pod)
                c.triggerEmergencyScaling(pod)
            },
            UpdateFunc: func(oldObj, newObj interface{}) {
                pod := newObj.(*v1.Pod)
                if pod.Status.Phase == v1.PodFailed {
                    c.handleFailedPaymentPod(pod)
                }
            },
        },
    )
    
    controller.Run(ctx.Done())
    return nil
}

// handlePaymentPodEvent processes pod events with business logic
func (c *ProductionAPIClient) handlePaymentPodEvent(eventType string, pod *v1.Pod) {
    // Extract business context
    businessTier := pod.Labels["business.tier"]
    revenueImpact := pod.Labels["revenue.impact"]
    
    // Log with business context
    log.Printf("Payment Event: type=%s pod=%s tier=%s revenue_impact=%s",
        eventType, pod.Name, businessTier, revenueImpact)
    
    // Business-specific handling
    if revenueImpact == "critical" && eventType == "DELETED" {
        c.escalateToBusinessTeam(pod)
    }
}

// triggerEmergencyScaling handles critical payment service scaling
func (c *ProductionAPIClient) triggerEmergencyScaling(pod *v1.Pod) {
    deploymentName := pod.Labels["app"]
    if deploymentName != "payment-service" {
        return
    }
    
    deployment, err := c.clientset.AppsV1().Deployments(c.namespace).Get(
        context.TODO(), deploymentName, metav1.GetOptions{})
    if err != nil {
        log.Printf("Failed to get deployment %s: %v", deploymentName, err)
        return
    }
    
    currentReplicas := *deployment.Spec.Replicas
    emergencyReplicas := currentReplicas + 5 // Emergency scaling
    
    log.Printf("EMERGENCY SCALING: %s from %d to %d replicas",
        deploymentName, currentReplicas, emergencyReplicas)
    
    deployment.Spec.Replicas = &emergencyReplicas
    _, err = c.clientset.AppsV1().Deployments(c.namespace).Update(
        context.TODO(), deployment, metav1.UpdateOptions{})
    if err != nil {
        log.Printf("Failed to scale deployment %s: %v", deploymentName, err)
    }
}
```

### Watch API for Real-time Events
```bash
# Watch pods (HTTP streaming)
curl -N "http://localhost:8080/api/v1/namespaces/default/pods?watch=true"

# Watch with kubectl
kubectl get pods --watch
kubectl get events --watch
```

## **Enterprise Custom Resources & Operators**

### **Why Custom Resources Transform Platform Engineering**
**Business Problem**: Teams need self-service infrastructure without learning Kubernetes complexity  
**Technical Problem**: 50+ YAML files per application, inconsistent configurations, policy violations  
**Solution**: Custom Resources provide business-domain APIs with built-in validation and governance

### **Production Payment Platform CRD**
```yaml
# Enterprise-grade Custom Resource Definition
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: paymentservices.platform.company.com
  annotations:
    # Business context for governance
    owner: "platform-team@company.com"
    cost-center: "engineering"
    compliance: "pci-dss,sox"
spec:
  group: platform.company.com
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required: ["businessUnit", "environment", "revenueImpact"]
            properties:
              # Business context (required)
              businessUnit:
                type: string
                enum: ["payments", "fraud", "compliance", "analytics"]
                description: "Business unit for cost allocation and alerting"
              
              environment:
                type: string
                enum: ["development", "staging", "production"]
                description: "Deployment environment with different compliance requirements"
              
              revenueImpact:
                type: string
                enum: ["critical", "high", "medium", "low"]
                description: "Business criticality for SLA and alerting"
              
              # Application configuration
              application:
                type: object
                required: ["name", "version", "image"]
                properties:
                  name:
                    type: string
                    pattern: '^[a-z]([a-z0-9-]*[a-z0-9])?$'
                  version:
                    type: string
                    pattern: '^v[0-9]+\.[0-9]+\.[0-9]+$'
                  image:
                    type: string
                    description: "Container image from approved registry"
                  port:
                    type: integer
                    minimum: 1024
                    maximum: 65535
                    default: 8080
              
              # Resource requirements (business-aware)
              resources:
                type: object
                properties:
                  cpu:
                    type: string
                    pattern: '^[0-9]+m?$'
                    default: "500m"
                  memory:
                    type: string
                    pattern: '^[0-9]+[MGT]i$'
                    default: "512Mi"
                  storage:
                    type: string
                    pattern: '^[0-9]+[MGT]i$'
                    default: "10Gi"
              
              # Scaling configuration
              scaling:
                type: object
                properties:
                  minReplicas:
                    type: integer
                    minimum: 1
                    default: 2
                  maxReplicas:
                    type: integer
                    maximum: 100
                    default: 10
                  targetCPU:
                    type: integer
                    minimum: 50
                    maximum: 80
                    default: 70
              
              # Security and compliance
              security:
                type: object
                properties:
                  encryptionRequired:
                    type: boolean
                    default: true
                  pciCompliance:
                    type: boolean
                    default: false
                    description: "Enable PCI DSS compliance controls"
                  dataClassification:
                    type: string
                    enum: ["public", "internal", "confidential", "restricted"]
                    default: "confidential"
              
              # Network configuration
              networking:
                type: object
                properties:
                  exposedToInternet:
                    type: boolean
                    default: false
                  allowedSources:
                    type: array
                    items:
                      type: string
                    description: "CIDR blocks or service names allowed to access"
          
          status:
            type: object
            properties:
              phase:
                type: string
                enum: ["Pending", "Deploying", "Ready", "Failed", "Updating"]
              deploymentStatus:
                type: object
                properties:
                  replicas:
                    type: integer
                  readyReplicas:
                    type: integer
                  updatedReplicas:
                    type: integer
              lastUpdated:
                type: string
                format: date-time
              conditions:
                type: array
                items:
                  type: object
                  properties:
                    type:
                      type: string
                    status:
                      type: string
                    reason:
                      type: string
                    message:
                      type: string
  scope: Namespaced
  names:
    plural: paymentservices
    singular: paymentservice
    kind: PaymentService
    shortNames: ["ps"]
  
  # Additional printer columns for kubectl
  additionalPrinterColumns:
  - name: Business Unit
    type: string
    jsonPath: .spec.businessUnit
  - name: Environment
    type: string
    jsonPath: .spec.environment
  - name: Revenue Impact
    type: string
    jsonPath: .spec.revenueImpact
  - name: Replicas
    type: integer
    jsonPath: .status.deploymentStatus.readyReplicas
  - name: Phase
    type: string
    jsonPath: .status.phase
  - name: Age
    type: date
    jsonPath: .metadata.creationTimestamp
```

### **Business-Domain Custom Resource Usage**
```yaml
# Developer-friendly payment service definition
apiVersion: platform.company.com/v1
kind: PaymentService
metadata:
  name: checkout-processor
  namespace: payments
  labels:
    team: checkout
    cost-center: payments
  annotations:
    platform.company.com/owner: "checkout-team@company.com"
    platform.company.com/runbook: "https://wiki.company.com/payments/checkout"
spec:
  # Business context (required by governance)
  businessUnit: payments
  environment: production
  revenueImpact: critical
  
  # Application configuration
  application:
    name: checkout-processor
    version: v2.1.3
    image: company-registry.com/payments/checkout-processor:v2.1.3
    port: 8080
  
  # Resource requirements
  resources:
    cpu: "2000m"      # 2 CPU cores for high-throughput
    memory: "4Gi"     # 4GB for in-memory caching
    storage: "50Gi"   # Local storage for temporary files
  
  # Auto-scaling configuration
  scaling:
    minReplicas: 5    # Always maintain 5 replicas for availability
    maxReplicas: 50   # Scale up to 50 during peak traffic
    targetCPU: 70     # Scale when CPU hits 70%
  
  # Security requirements
  security:
    encryptionRequired: true
    pciCompliance: true      # Enable PCI DSS controls
    dataClassification: restricted
  
  # Network access control
  networking:
    exposedToInternet: false
    allowedSources:
    - "10.0.0.0/8"          # Internal network
    - "api-gateway.default.svc.cluster.local"  # API Gateway service
```

### **Production Operator Implementation**
```python
import kopf
import kubernetes.client as k8s_client
from kubernetes.client.rest import ApiException
import logging
import asyncio

# Production-grade operator for PaymentService CRD
@kopf.on.create('platform.company.com', 'v1', 'paymentservices')
async def create_payment_service(spec, meta, status, **kwargs):
    """
    Handle creation of PaymentService custom resources
    Implements enterprise governance and compliance
    """
    name = meta['name']
    namespace = meta['namespace']
    
    # Extract business context
    business_unit = spec['businessUnit']
    environment = spec['environment']
    revenue_impact = spec['revenueImpact']
    
    logging.info(f"Creating PaymentService {name} for {business_unit} ({revenue_impact} impact)")
    
    try:
        # 1. Create Deployment with business-aware configuration
        deployment = create_deployment_manifest(name, namespace, spec)
        apps_v1 = k8s_client.AppsV1Api()
        deployment_result = apps_v1.create_namespaced_deployment(
            namespace=namespace,
            body=deployment
        )
        
        # 2. Create Service with appropriate exposure
        service = create_service_manifest(name, namespace, spec)
        v1 = k8s_client.CoreV1Api()
        service_result = v1.create_namespaced_service(
            namespace=namespace,
            body=service
        )
        
        # 3. Create HPA for auto-scaling
        if 'scaling' in spec:
            hpa = create_hpa_manifest(name, namespace, spec)
            autoscaling_v2 = k8s_client.AutoscalingV2Api()
            hpa_result = autoscaling_v2.create_namespaced_horizontal_pod_autoscaler(
                namespace=namespace,
                body=hpa
            )
        
        # 4. Apply security policies based on compliance requirements
        if spec.get('security', {}).get('pciCompliance', False):
            await apply_pci_compliance_policies(name, namespace)
        
        # 5. Create network policies for access control
        if 'networking' in spec:
            network_policy = create_network_policy_manifest(name, namespace, spec)
            networking_v1 = k8s_client.NetworkingV1Api()
            networking_v1.create_namespaced_network_policy(
                namespace=namespace,
                body=network_policy
            )
        
        # 6. Set up monitoring and alerting based on business impact
        await configure_business_monitoring(name, namespace, spec)
        
        # 7. Update status to reflect successful creation
        return {'status': {
            'phase': 'Deploying',
            'deploymentStatus': {
                'replicas': deployment.spec.replicas,
                'readyReplicas': 0,
                'updatedReplicas': 0
            },
            'conditions': [{
                'type': 'Created',
                'status': 'True',
                'reason': 'DeploymentCreated',
                'message': f'PaymentService {name} resources created successfully'
            }]
        }}
        
    except ApiException as e:
        logging.error(f"Failed to create PaymentService {name}: {e}")
        return {'status': {
            'phase': 'Failed',
            'conditions': [{
                'type': 'Created',
                'status': 'False',
                'reason': 'CreationFailed',
                'message': f'Failed to create resources: {str(e)}'
            }]
        }}

def create_deployment_manifest(name: str, namespace: str, spec: dict) -> k8s_client.V1Deployment:
    """
    Create enterprise-grade deployment with business context
    """
    app_spec = spec['application']
    resources_spec = spec.get('resources', {})
    security_spec = spec.get('security', {})
    
    # Business labels for cost allocation and governance
    labels = {
        'app.kubernetes.io/name': name,
        'app.kubernetes.io/version': app_spec['version'],
        'app.kubernetes.io/part-of': 'payment-platform',
        'business.unit': spec['businessUnit'],
        'environment': spec['environment'],
        'revenue.impact': spec['revenueImpact'],
        'compliance.pci': str(security_spec.get('pciCompliance', False)),
        'data.classification': security_spec.get('dataClassification', 'confidential')
    }
    
    # Resource configuration with business-appropriate defaults
    resources = k8s_client.V1ResourceRequirements(
        requests={
            'cpu': resources_spec.get('cpu', '500m'),
            'memory': resources_spec.get('memory', '512Mi')
        },
        limits={
            'cpu': resources_spec.get('cpu', '500m'),
            'memory': resources_spec.get('memory', '512Mi')
        }
    )
    
    # Security context based on compliance requirements
    security_context = k8s_client.V1SecurityContext(
        run_as_non_root=True,
        run_as_user=1000,
        read_only_root_filesystem=True,
        allow_privilege_escalation=False,
        capabilities=k8s_client.V1Capabilities(drop=['ALL'])
    )
    
    container = k8s_client.V1Container(
        name=name,
        image=app_spec['image'],
        ports=[k8s_client.V1ContainerPort(container_port=app_spec.get('port', 8080))],
        resources=resources,
        security_context=security_context,
        env=[
            # Business context environment variables
            k8s_client.V1EnvVar(name='BUSINESS_UNIT', value=spec['businessUnit']),
            k8s_client.V1EnvVar(name='ENVIRONMENT', value=spec['environment']),
            k8s_client.V1EnvVar(name='REVENUE_IMPACT', value=spec['revenueImpact']),
            k8s_client.V1EnvVar(name='PCI_COMPLIANCE', value=str(security_spec.get('pciCompliance', False)))
        ],
        # Health checks are critical for payment services
        liveness_probe=k8s_client.V1Probe(
            http_get=k8s_client.V1HTTPGetAction(
                path='/health',
                port=app_spec.get('port', 8080)
            ),
            initial_delay_seconds=30,
            period_seconds=10
        ),
        readiness_probe=k8s_client.V1Probe(
            http_get=k8s_client.V1HTTPGetAction(
                path='/ready',
                port=app_spec.get('port', 8080)
            ),
            initial_delay_seconds=5,
            period_seconds=5
        )
    )
    
    # Pod template with business-aware configuration
    pod_template = k8s_client.V1PodTemplateSpec(
        metadata=k8s_client.V1ObjectMeta(
            labels=labels,
            annotations={
                'prometheus.io/scrape': 'true',
                'prometheus.io/port': str(app_spec.get('port', 8080)),
                'prometheus.io/path': '/metrics',
                # Business context for monitoring
                'business.unit': spec['businessUnit'],
                'revenue.impact': spec['revenueImpact']
            }
        ),
        spec=k8s_client.V1PodSpec(
            containers=[container],
            security_context=k8s_client.V1PodSecurityContext(
                run_as_non_root=True,
                run_as_user=1000,
                fs_group=1000
            )
        )
    )
    
    # Deployment specification
    deployment_spec = k8s_client.V1DeploymentSpec(
        replicas=spec.get('scaling', {}).get('minReplicas', 2),
        selector=k8s_client.V1LabelSelector(match_labels={'app.kubernetes.io/name': name}),
        template=pod_template,
        strategy=k8s_client.V1DeploymentStrategy(
            type='RollingUpdate',
            rolling_update=k8s_client.V1RollingUpdateDeployment(
                max_unavailable='25%',
                max_surge='25%'
            )
        )
    )
    
    return k8s_client.V1Deployment(
        api_version='apps/v1',
        kind='Deployment',
        metadata=k8s_client.V1ObjectMeta(
            name=name,
            namespace=namespace,
            labels=labels,
            annotations={
                'platform.company.com/managed-by': 'payment-operator',
                'platform.company.com/created-at': str(time.time())
            }
        ),
        spec=deployment_spec
    )

async def configure_business_monitoring(name: str, namespace: str, spec: dict):
    """
    Configure monitoring and alerting based on business impact
    """
    revenue_impact = spec['revenueImpact']
    business_unit = spec['businessUnit']
    
    # Create ServiceMonitor for Prometheus
    service_monitor = {
        'apiVersion': 'monitoring.coreos.com/v1',
        'kind': 'ServiceMonitor',
        'metadata': {
            'name': f'{name}-monitor',
            'namespace': namespace,
            'labels': {
                'app.kubernetes.io/name': name,
                'business.unit': business_unit
            }
        },
        'spec': {
            'selector': {
                'matchLabels': {
                    'app.kubernetes.io/name': name
                }
            },
            'endpoints': [{
                'port': 'http',
                'path': '/metrics',
                'interval': '30s' if revenue_impact == 'critical' else '60s'
            }]
        }
    }
    
    # Create PrometheusRule for business-aware alerting
    alert_rules = create_business_alert_rules(name, revenue_impact, business_unit)
    
    # Apply monitoring configuration
    custom_objects_api = k8s_client.CustomObjectsApi()
    try:
        custom_objects_api.create_namespaced_custom_object(
            group='monitoring.coreos.com',
            version='v1',
            namespace=namespace,
            plural='servicemonitors',
            body=service_monitor
        )
        
        custom_objects_api.create_namespaced_custom_object(
            group='monitoring.coreos.com', 
            version='v1',
            namespace=namespace,
            plural='prometheusrules',
            body=alert_rules
        )
        
    except ApiException as e:
        logging.error(f"Failed to configure monitoring for {name}: {e}")

def create_business_alert_rules(name: str, revenue_impact: str, business_unit: str) -> dict:
    """
    Create business-aware alerting rules based on revenue impact
    """
    # Alerting thresholds based on business criticality
    if revenue_impact == 'critical':
        error_threshold = 0.01  # 1% error rate
        latency_threshold = 0.5  # 500ms
        availability_threshold = 0.999  # 99.9% uptime
    elif revenue_impact == 'high':
        error_threshold = 0.05  # 5% error rate
        latency_threshold = 1.0  # 1 second
        availability_threshold = 0.99   # 99% uptime
    else:
        error_threshold = 0.1   # 10% error rate
        latency_threshold = 2.0  # 2 seconds
        availability_threshold = 0.95  # 95% uptime
    
    return {
        'apiVersion': 'monitoring.coreos.com/v1',
        'kind': 'PrometheusRule',
        'metadata': {
            'name': f'{name}-alerts',
            'labels': {
                'app.kubernetes.io/name': name,
                'business.unit': business_unit,
                'revenue.impact': revenue_impact
            }
        },
        'spec': {
            'groups': [{
                'name': f'{name}.business.rules',
                'rules': [
                    {
                        'alert': f'{name}HighErrorRate',
                        'expr': f'rate(http_requests_total{{job="{name}",code=~"5.."}}[5m]) / rate(http_requests_total{{job="{name}"}}[5m]) > {error_threshold}',
                        'for': '1m' if revenue_impact == 'critical' else '5m',
                        'labels': {
                            'severity': 'critical' if revenue_impact == 'critical' else 'warning',
                            'business_unit': business_unit,
                            'revenue_impact': revenue_impact
                        },
                        'annotations': {
                            'summary': f'{name} high error rate',
                            'description': f'{name} error rate is above {error_threshold*100}%',
                            'runbook_url': f'https://wiki.company.com/{business_unit}/{name}/runbook'
                        }
                    },
                    {
                        'alert': f'{name}HighLatency',
                        'expr': f'histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{{job="{name}"}}[5m])) > {latency_threshold}',
                        'for': '2m',
                        'labels': {
                            'severity': 'warning',
                            'business_unit': business_unit,
                            'revenue_impact': revenue_impact
                        },
                        'annotations': {
                            'summary': f'{name} high latency',
                            'description': f'{name} 95th percentile latency is above {latency_threshold}s'
                        }
                    }
                ]
            }]
        }
    }
```

## Common Operations

### Testing API Access
```bash
# Check permissions
kubectl auth can-i create pods
kubectl auth can-i list nodes

# Test with service account
kubectl auth can-i get pods --as=system:serviceaccount:default:my-sa
```

### Debugging API Issues
```bash
# Check API server health
kubectl get --raw='/healthz'

# View API server logs
kubectl logs -n kube-system kube-apiserver-master-1

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

## Best Practices

### Efficient API Usage
```python
# Good: Use selectors to filter server-side
pods = v1.list_namespaced_pod(
    namespace="default",
    label_selector="app=nginx"
)

# Bad: Get all pods then filter client-side
all_pods = v1.list_namespaced_pod(namespace="default")
nginx_pods = [pod for pod in all_pods.items 
             if pod.metadata.labels.get("app") == "nginx"]
```

### Security
```yaml
# Use least privilege service accounts
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: api-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]  # Only what's needed
```

### Error Handling
```python
try:
    result = v1.create_namespaced_pod(namespace="default", body=pod)
except client.rest.ApiException as e:
    if e.status == 409:
        print("Pod already exists")
    elif e.status == 403:
        print("Insufficient permissions")
    else:
        print(f"API error: {e}")
```

## API Usage Patterns

### ✅ Use API For:
- **Automation scripts** - CI/CD pipelines, deployment tools
- **Custom controllers** - Operators and custom logic
- **Monitoring systems** - Cluster metrics and health checks
- **Multi-cluster management** - Tools managing multiple clusters

### ❌ Don't Use API For:
- **Simple operations** → Use kubectl instead
- **One-off tasks** → kubectl is easier
- **Learning Kubernetes** → Start with kubectl first

## Key Insights

**The Kubernetes API is the foundation of everything** - kubectl, operators, and all tooling use the REST API

**Watch API enables real-time automation** - essential for controllers and monitoring systems

**Efficient API usage prevents cluster overload** - use selectors and pagination instead of polling

**Custom resources extend Kubernetes** - CRDs allow domain-specific APIs

**Security is built-in** - RBAC, admission controllers, and audit logging protect the cluster

**Authentication matters** - service accounts, tokens, and certificates control access