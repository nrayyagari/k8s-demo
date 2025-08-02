# Monitoring: Metrics Collection, Alerting & Dashboards

## WHY Monitoring Is Your Production Lifeline

**Problem**: Systems fail silently - by the time users complain, you've lost revenue and trust  
**Solution**: Proactive monitoring with metrics, alerts, and dashboards to detect issues before they impact business

## **The $2M Monitoring Failure: A Cautionary Tale**

**What Happened**: E-commerce platform's payment API slowly degraded over 3 hours during Black Friday  
**Business Impact**: $2M lost sales, 15% customer churn, stock price drop  
**Root Cause**: Monitoring focused on infrastructure, ignored business metrics  
**Prevention**: Business-aware monitoring with proper SLIs/SLOs

### **The Monitoring Evolution: From Uptime to User Experience**
- **Nagios Era (2000s)**: Host up/down, basic service checks, email alerts
- **Cloud Era (2010s)**: Infrastructure metrics, CloudWatch, basic autoscaling
- **Microservices Era (2015+)**: Service mesh metrics, Prometheus explosion
- **SRE Era (2020+)**: SLI/SLO focus, error budgets, business metric correlation

## The Critical Questions

**Reliability**: "Is my system available and performing well?"  
**Capacity**: "When will I run out of resources?"  
**Business Impact**: "Are users having a good experience?"  
**Cost**: "Why is my monitoring bill $50K/month?"

## **Prometheus: Why It Won the Metrics War**

### **Technical Superiority**
- **Pull Model**: Self-discovering, resilient to network partitions
- **Time Series Database**: Optimized for metric workloads, efficient storage
- **Powerful Query Language (PromQL)**: Enables complex analysis and alerting
- **Kubernetes Native**: First-class integration, service discovery

### **Ecosystem Dominance**
- **Industry Adoption**: 90% of CNCF projects expose Prometheus metrics
- **Vendor Support**: Every major monitoring vendor supports Prometheus format
- **Open Source**: No vendor lock-in, community-driven development

## **Production Architecture Patterns**

### **Pattern 1: High-Availability Prometheus for Enterprise**
**Business Context**: 24/7 operations, compliance requirements, multiple regions  
**Challenge**: Zero monitoring downtime, long-term retention, federation across clusters

```yaml
# Production Prometheus Stack with HA
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
---
# Prometheus Operator CRDs and RBAC
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: prometheuses.monitoring.coreos.com
spec:
  group: monitoring.coreos.com
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
            properties:
              replicas:
                type: integer
              retention:
                type: string
              storage:
                type: object
                properties:
                  volumeClaimTemplate:
                    type: object
              serviceMonitorSelector:
                type: object
  scope: Namespaced
  names:
    plural: prometheuses
    singular: prometheus
    kind: Prometheus
---
# High-Availability Prometheus Deployment
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: prometheus-ha
  namespace: monitoring
spec:
  replicas: 2  # HA setup
  retention: 30d
  retentionSize: 500GB
  
  # Resource management
  resources:
    requests:
      memory: "4Gi"
      cpu: "2000m"
    limits:
      memory: "8Gi"
      cpu: "4000m"
  
  # Persistent storage
  storage:
    volumeClaimTemplate:
      spec:
        storageClassName: fast-ssd
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 1000Gi
  
  # Service discovery
  serviceMonitorSelector:
    matchLabels:
      team: platform
  
  # Pod monitoring
  podMonitorSelector:
    matchLabels:
      team: platform
  
  # Rule selection
  ruleSelector:
    matchLabels:
      team: platform
  
  # External labels for federation
  externalLabels:
    cluster: production-us-east-1
    region: us-east-1
  
  # Long-term storage integration
  remoteWrite:
  - url: "https://cortex.company.com/api/v1/push"
    headers:
      X-Scope-OrgID: production
    queueConfig:
      capacity: 10000
      maxShards: 200
      minShards: 1
      batchSendDeadline: 5s
    writeRelabelConfigs:
    - sourceLabels: [__name__]
      regex: 'prometheus_.*|go_.*'
      action: drop  # Don't send internal metrics
  
  # Security
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
    fsGroup: 65534
  
  # Anti-affinity for HA
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values: ["prometheus"]
        topologyKey: "kubernetes.io/hostname"
---
# Grafana for Visualization
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 2
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:10.2.0
        ports:
        - containerPort: 3000
          name: grafana
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana-credentials
              key: admin-password
        - name: GF_USERS_ALLOW_SIGN_UP
          value: "false"
        - name: GF_AUTH_LDAP_ENABLED
          value: "true"
        - name: GF_AUTH_LDAP_CONFIG_FILE
          value: "/etc/grafana/ldap.toml"
        - name: GF_INSTALL_PLUGINS
          value: "grafana-piechart-panel,grafana-worldmap-panel"
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
        - name: grafana-config
          mountPath: /etc/grafana/grafana.ini
          subPath: grafana.ini
        - name: grafana-dashboards
          mountPath: /var/lib/grafana/dashboards
        - name: grafana-datasources
          mountPath: /etc/grafana/provisioning/datasources
      volumes:
      - name: grafana-storage
        persistentVolumeClaim:
          claimName: grafana-pvc
      - name: grafana-config
        configMap:
          name: grafana-config
      - name: grafana-dashboards
        configMap:
          name: grafana-dashboards
      - name: grafana-datasources
        configMap:
          name: grafana-datasources
```

### **Pattern 2: Cost-Optimized Monitoring for Startups**
**Business Context**: Limited budget, rapid scaling, basic operational needs  
**Challenge**: Essential monitoring without breaking the bank

```yaml
# Lightweight Prometheus Stack
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 30s  # Longer interval = lower costs
      evaluation_interval: 30s
      external_labels:
        cluster: 'startup-cluster'
    
    rule_files:
    - "/etc/prometheus/rules/*.yml"
    
    scrape_configs:
    # Essential Kubernetes metrics only
    - job_name: 'kubernetes-nodes'
      kubernetes_sd_configs:
      - role: node
      relabel_configs:
      - source_labels: [__address__]
        regex: '(.*):10250'
        replacement: '${1}:9100'
        target_label: __address__
      metric_relabel_configs:
      # Keep only essential node metrics
      - source_labels: [__name__]
        regex: 'node_(cpu_seconds_total|memory_MemTotal_bytes|memory_MemAvailable_bytes|filesystem_avail_bytes|load1)'
        action: keep
    
    # Application metrics with sampling
    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      # Sample high-cardinality metrics
      metric_relabel_configs:
      - source_labels: [__name__]
        regex: 'http_request_duration_seconds_bucket'
        action: drop  # Use histogram_quantile on summary instead
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1  # Single replica for cost savings
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:v2.45.0
        args:
        - '--config.file=/etc/prometheus/prometheus.yml'
        - '--storage.tsdb.path=/prometheus/'
        - '--web.console.libraries=/etc/prometheus/console_libraries'
        - '--web.console.templates=/etc/prometheus/consoles'
        - '--web.enable-lifecycle'
        - '--storage.tsdb.retention.time=7d'  # Short retention
        - '--storage.tsdb.retention.size=10GB'
        ports:
        - containerPort: 9090
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus/
        - name: prometheus-storage
          mountPath: /prometheus/
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config
      - name: prometheus-storage
        emptyDir:
          sizeLimit: 15Gi  # Ephemeral storage for cost savings
```

## **Business-Critical Alerting Rules**

### **SLI/SLO-Based Alerting Framework**
```yaml
# Production Alerting Rules
apiVersion: v1
kind: ConfigMap
metadata:
  name: alert-rules
  namespace: monitoring
data:
  business-critical.yml: |
    groups:
    - name: business.critical
      rules:
      # Error Budget Burn Rate (Multi-window approach)
      - alert: ErrorBudgetBurnRateHigh
        expr: |
          (
            # 1-hour burn rate > 14.4x (exhausts budget in 2 hours)
            (
              sum(rate(http_requests_total{code=~"5.."}[1h])) /
              sum(rate(http_requests_total[1h]))
            ) > (14.4 * 0.001)
            and
            # 5-minute burn rate confirms
            (
              sum(rate(http_requests_total{code=~"5.."}[5m])) /
              sum(rate(http_requests_total[5m]))
            ) > (14.4 * 0.001)
          )
          or
          (
            # 6-hour burn rate > 6x (exhausts budget in 24 hours)
            (
              sum(rate(http_requests_total{code=~"5.."}[6h])) /
              sum(rate(http_requests_total[6h]))
            ) > (6 * 0.001)
            and
            # 30-minute burn rate confirms
            (
              sum(rate(http_requests_total{code=~"5.."}[30m])) /
              sum(rate(http_requests_total[30m]))
            ) > (6 * 0.001)
          )
        for: 1m
        labels:
          severity: critical
          team: platform
          escalation: immediate
        annotations:
          summary: "Error budget burn rate too high"
          description: "Service {{ $labels.service }} is burning through error budget too quickly"
          runbook_url: "https://runbooks.company.com/error-budget-burn"
          business_impact: "User experience degradation, potential SLA violations"
      
      # Revenue Impact Alert
      - alert: RevenueProcessingDown
        expr: |
          (
            sum(rate(payment_transactions_total{status="success"}[5m])) /
            sum(rate(payment_transactions_total[5m]))
          ) < 0.95
        for: 2m
        labels:
          severity: critical
          team: payments
          escalation: immediate
          pager: "true"
        annotations:
          summary: "Payment success rate below 95%"
          description: "Payment processing success rate is {{ $value | humanizePercentage }}"
          business_impact: "Estimated revenue loss: ${{ $value | multiply 1000 }}/minute"
          runbook_url: "https://runbooks.company.com/payment-failures"
      
      # Database Connection Pool Exhaustion
      - alert: DatabaseConnectionPoolExhaustion
        expr: |
          (
            sum by (service) (mysql_connections_used) /
            sum by (service) (mysql_max_connections)
          ) > 0.9
        for: 5m
        labels:
          severity: warning
          team: database
        annotations:
          summary: "Database connection pool nearly exhausted"
          description: "{{ $labels.service }} using {{ $value | humanizePercentage }} of connection pool"
          runbook_url: "https://runbooks.company.com/db-connection-pool"
      
      # Memory Pressure Leading Indicator
      - alert: ApplicationMemoryPressure
        expr: |
          (
            container_memory_working_set_bytes{container!="POD",container!=""} /
            container_spec_memory_limit_bytes{container!="POD",container!=""} * 100
          ) > 85
        for: 10m
        labels:
          severity: warning
          team: "{{ $labels.namespace }}"
        annotations:
          summary: "High memory usage in {{ $labels.namespace }}/{{ $labels.pod }}"
          description: "Container {{ $labels.container }} is using {{ $value | humanizePercentage }} of memory limit"
          runbook_url: "https://runbooks.company.com/memory-pressure"
  
  infrastructure.yml: |
    groups:
    - name: infrastructure
      rules:
      # Node Resource Alerts
      - alert: NodeHighCPU
        expr: (100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 80
        for: 15m
        labels:
          severity: warning
          team: infrastructure
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is {{ $value | humanizePercentage }}"
      
      - alert: NodeHighMemory
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 10m
        labels:
          severity: warning
          team: infrastructure
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is {{ $value | humanizePercentage }}"
      
      # Disk Space Alerts
      - alert: NodeDiskSpaceLow
        expr: ((node_filesystem_avail_bytes * 100) / node_filesystem_size_bytes) < 10
        for: 5m
        labels:
          severity: critical
          team: infrastructure
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
          description: "Disk {{ $labels.mountpoint }} has {{ $value | humanizePercentage }} space remaining"
```

## **Enterprise Grafana Dashboard Strategy**

### **Business KPI Dashboard**
```json
{
  "dashboard": {
    "title": "Business KPIs - Executive View",
    "panels": [
      {
        "title": "Revenue Per Minute",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate(payment_amount_total[1m]) * 60)",
            "legendFormat": "Revenue/min"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "currencyUSD",
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 1000},
                {"color": "green", "value": 5000}
              ]
            }
          }
        }
      },
      {
        "title": "User Experience Score",
        "type": "gauge",
        "targets": [
          {
            "expr": "(\n  sum(rate(http_request_duration_seconds_bucket{le=\"0.5\"}[5m])) /\n  sum(rate(http_request_duration_seconds_count[5m]))\n) * 100",
            "legendFormat": "Apdex Score"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "min": 0,
            "max": 100,
            "unit": "percent",
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 70},
                {"color": "green", "value": 90}
              ]
            }
          }
        }
      }
    ]
  }
}
```

### **SRE Operations Dashboard**
```json
{
  "dashboard": {
    "title": "SRE Golden Signals",
    "panels": [
      {
        "title": "Request Rate (QPS)",
        "type": "graph",
        "targets": [
          {
            "expr": "sum by (service) (rate(http_requests_total[5m]))",
            "legendFormat": "{{ service }}"
          }
        ]
      },
      {
        "title": "Error Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "sum by (service) (rate(http_requests_total{code=~\"5..\"}[5m])) / sum by (service) (rate(http_requests_total[5m])) * 100",
            "legendFormat": "{{ service }} errors"
          }
        ],
        "yAxes": [
          {
            "unit": "percent",
            "max": 5
          }
        ]
      },
      {
        "title": "Response Time (P95)",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, sum by (service, le) (rate(http_request_duration_seconds_bucket[5m])))",
            "legendFormat": "{{ service }} P95"
          }
        ],
        "yAxes": [
          {
            "unit": "s",
            "logBase": 2
          }
        ]
      },
      {
        "title": "Saturation (Resource Usage)",
        "type": "graph",
        "targets": [
          {
            "expr": "sum by (service) (rate(container_cpu_usage_seconds_total[5m])) / sum by (service) (container_spec_cpu_quota/container_spec_cpu_period) * 100",
            "legendFormat": "{{ service }} CPU"
          },
          {
            "expr": "sum by (service) (container_memory_working_set_bytes) / sum by (service) (container_spec_memory_limit_bytes) * 100",
            "legendFormat": "{{ service }} Memory"
          }
        ],
        "yAxes": [
          {
            "unit": "percent",
            "max": 100
          }
        ]
      }
    ]
  }
}
```

## **Cost Optimization & Scaling Strategies**

### **Metric Lifecycle Management**
```yaml
# Prometheus Configuration for Cost Optimization
global:
  # Longer scrape intervals for non-critical metrics
  scrape_interval: 60s
  evaluation_interval: 60s
  
  # External labels for multi-cluster federation
  external_labels:
    cluster: 'production'
    region: 'us-east-1'

# Remote write configuration for long-term storage
remote_write:
- url: "https://cortex-gateway.company.com/api/v1/push"
  remote_timeout: 30s
  queue_config:
    capacity: 2500
    max_shards: 200
    min_shards: 1
    max_samples_per_send: 1000
    batch_send_deadline: 5s
  # Only send business-critical metrics to long-term storage
  write_relabel_configs:
  - source_labels: [__name__]
    regex: 'business_.*|sli_.*|error_budget_.*'
    action: keep

# Metric retention strategy
storage:
  tsdb:
    retention.time: 15d  # Local retention
    retention.size: 100GB
    # Compaction settings for efficiency
    min-block-duration: 2h
    max-block-duration: 25h
```

### **Horizontal Scaling Pattern**
```yaml
# Prometheus Federation for Large Clusters
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-federation-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 5m  # Longer interval for federated metrics
    
    scrape_configs:
    # Federation from cluster Prometheus instances
    - job_name: 'prometheus-federation'
      scrape_interval: 15s
      honor_labels: true
      metrics_path: '/federate'
      params:
        'match[]':
        # Only federate aggregated and business metrics
        - '{__name__=~"^(up|prometheus_notifications_.*|business_.*|sli_.*)$"}'
        - '{__name__=~"^(node_cpu|node_memory|node_filesystem).*"}'
      static_configs:
      - targets:
        - 'prometheus-us-east-1a:9090'
        - 'prometheus-us-east-1b:9090'
        - 'prometheus-us-west-2a:9090'
      relabel_configs:
      - source_labels: [__address__]
        regex: 'prometheus-(.+):9090'
        target_label: cluster
        replacement: '${1}'
```

## **Production Troubleshooting Scenarios**

### **Scenario 1: Alert Fatigue Investigation**
**Business Context**: Team receiving 500+ alerts/day, response time degrading  
**Root Cause Analysis**: Poor alerting signal-to-noise ratio

```bash
# Analyze alert patterns
# Query Prometheus for alert frequency
sum by (alertname) (prometheus_notifications_total) 

# Find most frequent alerts
topk(10, 
  sum by (alertname) (
    increase(prometheus_notifications_total[24h])
  )
)

# Analyze alert duration patterns
histogram_quantile(0.95,
  sum by (alertname, le) (
    prometheus_rule_evaluation_duration_seconds_bucket
  )
)
```

### **Scenario 2: Metrics Explosion Cost Control**
**Business Context**: Monitoring costs increased 10x after new service deployment  
**Investigation**: High-cardinality metrics causing storage explosion

```bash
# Find high-cardinality metrics
topk(20, 
  count by (__name__) (
    {__name__=~".+"}
  )
)

# Analyze metric growth rate
rate(prometheus_tsdb_symbol_table_size_bytes[1h])

# Identify problematic labels
topk(10,
  count by (__name__, job) (
    {__name__=~".+"}
  )
)
```

## **Integration with External Systems**

### **PagerDuty Integration**
```yaml
# AlertManager Configuration for PagerDuty
route:
  group_by: ['alertname', 'service']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'web.hook'
  routes:
  - match:
      severity: critical
    receiver: 'pagerduty-critical'
  - match:
      severity: warning
    receiver: 'slack-warnings'

receivers:
- name: 'pagerduty-critical'
  pagerduty_configs:
  - service_key: 'YOUR_SERVICE_KEY'
    description: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
    details:
      Business Impact: '{{ .Annotations.business_impact }}'
      Runbook: '{{ .Annotations.runbook_url }}'
      Firing: '{{ .Alerts.Firing | len }}'
      Resolved: '{{ .Alerts.Resolved | len }}'
```

### **Slack Integration**
```yaml
- name: 'slack-warnings'
  slack_configs:
  - api_url: 'YOUR_SLACK_WEBHOOK_URL'
    channel: '#alerts'
    title: 'Alert: {{ .GroupLabels.alertname }}'
    text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
    color: '{{ if eq .Status "firing" }}danger{{ else }}good{{ end }}'
```

## **Best Practices for Production Monitoring**

### **Golden Rules**
1. **Monitor Business Metrics First**: Revenue, user experience, conversion rates
2. **Use SLI/SLO Framework**: Error budgets over arbitrary thresholds  
3. **Implement Proper Alert Routing**: Right alert to right person at right time
4. **Practice Alert Response**: Regular fire drills and runbook testing
5. **Monitor Your Monitoring**: Alert on monitoring system failures

### **Common Anti-Patterns to Avoid**
❌ **Alerting on metrics without business context**  
❌ **Setting alerts without clear response procedures**  
❌ **Monitoring everything instead of what matters**  
❌ **Using monitoring as debugging tool**  
❌ **Ignoring alert fatigue and response times**

## **Next Steps: Implementation Roadmap**

1. **Week 1**: Deploy basic Prometheus + Grafana stack
2. **Week 2**: Implement Four Golden Signals monitoring
3. **Week 3**: Create business KPI dashboards
4. **Week 4**: Implement SLI/SLO-based alerting
5. **Month 2**: Add long-term storage and federation
6. **Month 3**: Integrate with incident management and automation

**Remember**: Start with business-critical metrics, then expand to infrastructure. Good monitoring tells you about user impact, not just system state.