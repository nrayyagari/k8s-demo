# OpenTelemetry: Unified Observability Standard

## WHY OpenTelemetry Is the Future of Observability

**Problem**: Vendor lock-in, incompatible formats, multiple agents, complex integrations  
**Solution**: Single, vendor-neutral standard for metrics, logs, and traces with universal compatibility

## **The Observability Vendor War: How OpenTelemetry Won**

**Historical Context**: Before OpenTelemetry, each vendor had proprietary agents and formats  
**The Problem**: Companies spent more on integration than observability value  
**Business Impact**: 6-month vendor migrations, $500K+ switching costs, feature limitations  
**Resolution**: OpenTelemetry emerged as Switzerland - neutral, comprehensive, vendor-agnostic

### **The Standards War Timeline**
- **OpenTracing Era (2016-2019)**: Distributed tracing standards, limited scope
- **OpenCensus Era (2017-2019)**: Google's metrics and tracing, competing standard  
- **OpenTelemetry Formation (2019)**: Merger of OpenTracing and OpenCensus
- **Industry Adoption (2020+)**: All major vendors adopt OTEL as primary ingestion format
- **Cloud Native Standard (2024)**: CNCF graduated project, default choice

## The Strategic Questions

**Vendor Strategy**: "How do I avoid observability vendor lock-in?"  
**Cost Control**: "How do I collect once, route to multiple backends?"  
**Future-Proofing**: "What happens when my observability vendor gets acquired?"  
**Standardization**: "How do I ensure consistent instrumentation across 50+ services?"

## **OpenTelemetry Architecture: The Universal Translator**

### **Core Components & Data Flow**
```
Application Code (Auto/Manual Instrumentation)
    ↓
OpenTelemetry SDK (Collect telemetry data)
    ↓  
OpenTelemetry Collector (Process, enrich, route)
    ↓
Multiple Backends (Prometheus, Jaeger, Elasticsearch, Datadog, etc.)
```

### **The Collector: Heart of the System**
**Why It's Revolutionary**: Decouples data collection from backend destinations  
**Business Value**: Vendor negotiating power, cost optimization, gradual migrations

```yaml
# Production OpenTelemetry Collector Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-config
  namespace: observability
data:
  otel-collector-config.yaml: |
    # Receivers: How data enters the collector
    receivers:
      # OpenTelemetry Protocol (Primary)
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
      
      # Legacy format support
      jaeger:
        protocols:
          grpc:
            endpoint: 0.0.0.0:14250
          thrift_http:
            endpoint: 0.0.0.0:14268
      
      # Prometheus metrics scraping
      prometheus:
        config:
          global:
            scrape_interval: 30s
          scrape_configs:
          - job_name: 'kubernetes-pods'
            kubernetes_sd_configs:
            - role: pod
            relabel_configs:
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
              action: keep
              regex: true
      
      # Kubernetes cluster metrics
      k8s_cluster:
        collection_interval: 10s
        node_conditions_to_report: [Ready, MemoryPressure, DiskPressure, PIDPressure]
        allocatable_types_to_report: [cpu, memory, storage]
      
      # Host metrics from nodes
      hostmetrics:
        collection_interval: 30s
        scrapers:
          cpu:
            metrics:
              system.cpu.utilization:
                enabled: true
          memory:
            metrics:
              system.memory.utilization:
                enabled: true
          disk:
          filesystem:
            exclude_mount_points:
              mount_points: [/dev, /proc, /sys, /var/lib/docker/.+]
              match_type: regexp
          network:
          process:
            mute_process_name_error: true
    
    # Processors: Transform and enrich data
    processors:
      # Memory limiter (Essential for production)
      memory_limiter:
        limit_mib: 512
        spike_limit_mib: 128
        check_interval: 5s
      
      # Batch processor (Improves performance)
      batch:
        timeout: 1s
        send_batch_size: 1024
        send_batch_max_size: 2048
      
      # Resource processor (Add business context)
      resource:
        attributes:
        - key: environment
          value: production
          action: upsert
        - key: team
          from_attribute: k8s.namespace.name
          action: insert
        - key: cluster
          value: production-us-east-1
          action: upsert
        - key: cost_center
          value: engineering
          action: upsert
      
      # Attributes processor (Business enrichment)
      attributes:
        actions:
        - key: business.tier
          from_attribute: http.request.header.x-user-tier
          action: insert
        - key: business.experiment
          from_attribute: http.request.header.x-experiment
          action: insert
        - key: revenue.impact
          value: high
          action: insert
          include:
            match_type: regexp
            services: [payment-service, checkout-service]
      
      # Sampling processor (Cost control)
      probabilistic_sampler:
        hash_seed: 22
        sampling_percentage: 1.0  # 1% default sampling
      
      # Tail sampling (Intelligent sampling)
      tail_sampling:
        decision_wait: 10s
        num_traces: 100000
        expected_new_traces_per_sec: 1000
        policies:
        - name: sample_errors
          type: status_code
          status_code: {status_codes: [ERROR]}
        - name: sample_slow_traces
          type: latency
          latency: {threshold_ms: 1000}
        - name: sample_business_critical
          type: string_attribute
          string_attribute: {key: service.name, values: [payment-service, checkout-service]}
        - name: sample_high_value_users
          type: string_attribute
          string_attribute: {key: business.tier, values: [premium, enterprise]}
        - name: probabilistic_policy
          type: probabilistic
          probabilistic: {sampling_percentage: 0.1}
    
    # Exporters: Where data goes
    exporters:
      # Prometheus metrics
      prometheus:
        endpoint: "0.0.0.0:8889"
        namespace: "otel"
        const_labels:
          cluster: production
      
      # Long-term metrics storage (Cortex/Mimir)
      prometheusremotewrite:
        endpoint: "https://cortex-gateway.company.com/api/v1/push"
        headers:
          Authorization: "Bearer ${CORTEX_TOKEN}"
        resource_to_telemetry_conversion:
          enabled: true
      
      # Jaeger tracing
      jaeger:
        endpoint: jaeger-collector.tracing.svc.cluster.local:14250
        tls:
          insecure: true
      
      # Log aggregation (Loki)
      loki:
        endpoint: "http://loki.logging.svc.cluster.local:3100/loki/api/v1/push"
        headers:
          X-Scope-OrgID: "production"
      
      # Cloud providers (Multi-cloud strategy)
      awsxray:
        region: us-east-1
        no_verify_ssl: false
      
      # Commercial vendors (Hybrid approach)
      datadog:
        api:
          key: "${DD_API_KEY}"
          site: datadoghq.com
        metrics:
          endpoint: "https://api.datadoghq.com"
        traces:
          endpoint: "https://trace.agent.datadoghq.com"
      
      # Debug exporter (Development)
      debug:
        verbosity: normal
    
    # Extensions: Additional functionality
    extensions:
      # Health check endpoint
      health_check:
        endpoint: 0.0.0.0:13133
      
      # Performance profiling
      pprof:
        endpoint: 0.0.0.0:1777
      
      # Metrics about the collector
      zpages:
        endpoint: 0.0.0.0:55679
    
    # Service pipelines: Connect receivers to exporters via processors
    service:
      extensions: [health_check, pprof, zpages]
      
      pipelines:
        # Metrics pipeline
        metrics:
          receivers: [otlp, prometheus, k8s_cluster, hostmetrics]
          processors: [memory_limiter, resource, batch]
          exporters: [prometheus, prometheusremotewrite, datadog]
        
        # Traces pipeline  
        traces:
          receivers: [otlp, jaeger]
          processors: [memory_limiter, resource, tail_sampling, batch]
          exporters: [jaeger, datadog, awsxray]
        
        # Logs pipeline
        logs:
          receivers: [otlp]
          processors: [memory_limiter, resource, attributes, batch]
          exporters: [loki, datadog]
      
      # Telemetry about the collector itself
      telemetry:
        logs:
          level: "info"
        metrics:
          address: 0.0.0.0:8888
---
# Production Collector Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector
  namespace: observability
spec:
  replicas: 3  # HA deployment
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      serviceAccountName: otel-collector
      containers:
      - name: otel-collector
        image: otel/opentelemetry-collector-contrib:0.88.0
        command:
        - "/otelcol-contrib"
        - "--config=/conf/otel-collector-config.yaml"
        ports:
        - containerPort: 4317   # OTLP gRPC
        - containerPort: 4318   # OTLP HTTP
        - containerPort: 8889   # Prometheus metrics
        - containerPort: 13133  # Health check
        env:
        - name: GOGC
          value: "80"  # More frequent GC for memory efficiency
        - name: DD_API_KEY
          valueFrom:
            secretKeyRef:
              name: datadog-secret
              key: api-key
        - name: CORTEX_TOKEN
          valueFrom:
            secretKeyRef:
              name: cortex-secret
              key: token
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        volumeMounts:
        - name: config
          mountPath: /conf
        livenessProbe:
          httpGet:
            path: /
            port: 13133
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /
            port: 13133
          initialDelaySeconds: 5
          periodSeconds: 10
      volumes:
      - name: config
        configMap:
          name: otel-collector-config
      # Anti-affinity for HA
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values: ["otel-collector"]
              topologyKey: kubernetes.io/hostname
```

## **Auto-Instrumentation: Zero-Code Observability**

### **OpenTelemetry Operator for Kubernetes**
```yaml
# OpenTelemetry Operator Installation
apiVersion: v1
kind: Namespace
metadata:
  name: opentelemetry-operator-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: opentelemetry-operator-controller
  namespace: opentelemetry-operator-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: opentelemetry-operator
  template:
    metadata:
      labels:
        app: opentelemetry-operator
    spec:
      containers:
      - name: manager
        image: ghcr.io/open-telemetry/opentelemetry-operator/opentelemetry-operator:v0.88.0
        env:
        - name: ENABLE_WEBHOOKS
          value: "true"
        ports:
        - containerPort: 9443
          name: webhook-server
        - containerPort: 8080
          name: metrics
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
# Auto-Instrumentation Configuration
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: production-instrumentation
  namespace: default
spec:
  # Exporter configuration
  exporter:
    endpoint: http://otel-collector.observability.svc.cluster.local:4317
  
  # Propagation configuration  
  propagators:
    - tracecontext  # W3C standard
    - baggage      # W3C baggage
    - b3           # Zipkin B3 (legacy support)
  
  # Global sampling configuration
  sampler:
    type: parentbased_traceidratio
    argument: "0.1"  # 10% sampling
  
  # Resource attributes (Business context)
  resource:
    addK8sUIDAttributes: true
    resourceAttributes:
      business.service.tier: "{{ .metadata.labels.tier | default \"standard\" }}"
      business.cost.center: "{{ .metadata.labels.cost-center | default \"engineering\" }}"
      deployment.environment: "production"
  
  # Java auto-instrumentation
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:1.31.0
    env:
      - name: OTEL_JAVAAGENT_DEBUG
        value: "false"
      - name: OTEL_INSTRUMENTATION_JDBC_ENABLED
        value: "true"
      - name: OTEL_INSTRUMENTATION_KAFKA_ENABLED
        value: "true"
      - name: OTEL_INSTRUMENTATION_REDIS_ENABLED
        value: "true"
      - name: OTEL_INSTRUMENTATION_SPRING_WEB_ENABLED
        value: "true"
      # Business context injection
      - name: OTEL_RESOURCE_ATTRIBUTES
        value: "business.language=java,business.framework=spring"
  
  # Python auto-instrumentation
  python:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:0.41b0
    env:
      - name: OTEL_LOG_LEVEL
        value: "info"
      - name: OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED
        value: "true"
      - name: OTEL_RESOURCE_ATTRIBUTES
        value: "business.language=python,business.framework=django"
  
  # Node.js auto-instrumentation
  nodejs:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:0.44.0
    env:
      - name: OTEL_LOG_LEVEL
        value: "info"
      - name: OTEL_RESOURCE_ATTRIBUTES
        value: "business.language=nodejs,business.framework=express"
  
  # .NET auto-instrumentation
  dotnet:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-dotnet:1.0.0
    env:
      - name: OTEL_LOG_LEVEL
        value: "info"
      - name: OTEL_RESOURCE_ATTRIBUTES
        value: "business.language=dotnet,business.framework=aspnetcore"
```

### **Application Deployment with Auto-Instrumentation**
```yaml
# Annotate deployment for auto-instrumentation
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: payment-service
  template:
    metadata:
      labels:
        app: payment-service
        tier: critical
        cost-center: payments
      annotations:
        # Enable auto-instrumentation
        instrumentation.opentelemetry.io/inject-java: "production-instrumentation"
        # Business context annotations
        business.service.criticality: "high"
        business.service.revenue-impact: "direct"
    spec:
      containers:
      - name: payment-service
        image: company/payment-service:v1.2.3
        ports:
        - containerPort: 8080
        env:
        # Business context environment variables
        - name: SERVICE_TIER
          value: "premium"
        - name: BUSINESS_UNIT
          value: "payments"
        # OpenTelemetry specific configuration
        - name: OTEL_SERVICE_NAME
          value: "payment-service"
        - name: OTEL_SERVICE_VERSION
          value: "v1.2.3"
        - name: OTEL_RESOURCE_ATTRIBUTES
          value: "service.namespace=payments,business.criticality=high"
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "500m"
```

## **Manual Instrumentation: Fine-Grained Control**

### **Custom Business Metrics (Go)**
```go
package main

import (
    "context"
    "time"
    
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/attribute"
    "go.opentelemetry.io/otel/metric"
    "go.opentelemetry.io/otel/trace"
)

var (
    meter  = otel.Meter("payment-service")
    tracer = otel.Tracer("payment-service")
    
    // Business metrics
    paymentCounter, _        = meter.Int64Counter("payments_total")
    paymentAmountHistogram, _ = meter.Float64Histogram("payment_amount")
    processingTimeHistogram, _ = meter.Float64Histogram("payment_processing_seconds")
    
    // Technical metrics
    dbConnectionGauge, _     = meter.Int64UpDownCounter("db_connections_active")
    errorCounter, _          = meter.Int64Counter("errors_total")
)

func processPayment(ctx context.Context, req PaymentRequest) error {
    // Start business transaction span
    ctx, span := tracer.Start(ctx, "process-payment",
        trace.WithAttributes(
            // Business context
            attribute.String("business.operation", "payment_processing"),
            attribute.String("business.user_tier", req.UserTier),
            attribute.Float64("business.amount", req.Amount),
            attribute.String("business.currency", req.Currency),
            attribute.String("business.payment_method", req.Method),
            
            // Technical context
            attribute.String("service.version", "v1.2.3"),
            attribute.String("deployment.environment", "production"),
        ),
    )
    defer span.End()
    
    startTime := time.Now()
    
    // Business metric: Payment attempt
    paymentCounter.Add(ctx, 1,
        metric.WithAttributes(
            attribute.String("payment_method", req.Method),
            attribute.String("user_tier", req.UserTier),
            attribute.String("currency", req.Currency),
        ),
    )
    
    // Business metric: Payment amount
    paymentAmountHistogram.Record(ctx, req.Amount,
        metric.WithAttributes(
            attribute.String("currency", req.Currency),
            attribute.String("user_tier", req.UserTier),
        ),
    )
    
    // Validate payment
    if err := validatePayment(ctx, req); err != nil {
        // Error tracking
        errorCounter.Add(ctx, 1,
            metric.WithAttributes(
                attribute.String("error_type", "validation_failed"),
                attribute.String("operation", "payment_processing"),
            ),
        )
        
        span.RecordError(err)
        span.SetStatus(codes.Error, "Payment validation failed")
        return err
    }
    
    // Process payment with external service
    if err := chargeCard(ctx, req); err != nil {
        errorCounter.Add(ctx, 1,
            metric.WithAttributes(
                attribute.String("error_type", "external_service_failed"),
                attribute.String("operation", "card_charging"),
            ),
        )
        return err
    }
    
    // Record processing time
    processingTime := time.Since(startTime)
    processingTimeHistogram.Record(ctx, processingTime.Seconds(),
        metric.WithAttributes(
            attribute.String("payment_method", req.Method),
            attribute.String("user_tier", req.UserTier),
        ),
    )
    
    // Business success event
    span.AddEvent("payment-completed",
        trace.WithAttributes(
            attribute.Float64("revenue.generated", req.Amount),
            attribute.String("business.conversion_step", "payment"),
            attribute.Float64("processing.duration_seconds", processingTime.Seconds()),
        ),
    )
    
    // Update business metrics
    span.SetAttributes(
        attribute.Bool("business.success", true),
        attribute.String("business.transaction_id", generateTxnID()),
    )
    
    return nil
}

// Database instrumentation example
func getUserPaymentHistory(ctx context.Context, userID string) ([]Payment, error) {
    // Child span for database operation
    ctx, span := tracer.Start(ctx, "db-query-user-payments",
        trace.WithAttributes(
            attribute.String("db.system", "postgresql"),
            attribute.String("db.name", "payments"),
            attribute.String("db.operation", "select"),
            attribute.String("db.table", "payments"),
            attribute.String("business.query_type", "user_history"),
        ),
    )
    defer span.End()
    
    // Record active connection
    dbConnectionGauge.Add(ctx, 1)
    defer dbConnectionGauge.Add(ctx, -1)
    
    start := time.Now()
    
    // Execute query (with actual implementation)
    payments, err := executePaymentQuery(ctx, userID)
    
    queryTime := time.Since(start)
    
    // Add timing and result metadata
    span.SetAttributes(
        attribute.Int64("db.query_duration_ms", queryTime.Milliseconds()),
        attribute.Int("db.rows_returned", len(payments)),
        attribute.String("db.user_id", userID),
    )
    
    if err != nil {
        span.RecordError(err)
        return nil, err
    }
    
    return payments, nil
}
```

## **Enterprise Integration Patterns**

### **Multi-Cloud Strategy**
```yaml
# Multi-cloud collector configuration
exporters:
  # AWS X-Ray
  awsxray:
    region: us-east-1
    
  # Azure Monitor
  azuremonitor:
    instrumentation_key: "${AZURE_INSTRUMENTATION_KEY}"
    
  # GCP Cloud Trace
  googlecloud:
    project: "company-production"
    
  # Commercial vendors
  datadog:
    api:
      key: "${DD_API_KEY}"
      site: datadoghq.com
  
  newrelic:
    apikey: "${NR_API_KEY}"
    
  dynatrace:
    endpoint: "https://company.live.dynatrace.com/api/v2/otlp"
    headers:
      Authorization: "Api-Token ${DYNATRACE_TOKEN}"
```

### **Cost-Aware Routing**
```yaml
# Route expensive data to cost-effective storage
processors:
  routing:
    from_attribute: "business.tier"
    table:
      - value: "premium"
        exporters: [datadog, newrelic]  # Full vendor features
      - value: "standard" 
        exporters: [prometheus, jaeger]  # Open source
      - value: "basic"
        exporters: [prometheus]  # Metrics only
    default_exporters: [prometheus]
```

## **Business Intelligence with OpenTelemetry**

### **Revenue Attribution**
```go
// Track revenue attribution across services
func trackRevenue(ctx context.Context, amount float64, source string) {
    span := trace.SpanFromContext(ctx)
    
    // Business intelligence attributes
    span.SetAttributes(
        attribute.Float64("revenue.amount", amount),
        attribute.String("revenue.source", source),
        attribute.String("revenue.attribution.channel", getChannel(ctx)),
        attribute.String("revenue.attribution.campaign", getCampaign(ctx)),
        attribute.String("revenue.attribution.experiment", getExperiment(ctx)),
    )
    
    // Custom metric for business analytics
    revenueCounter.Add(ctx, amount,
        metric.WithAttributes(
            attribute.String("source", source),
            attribute.String("channel", getChannel(ctx)),
            attribute.String("user_tier", getUserTier(ctx)),
        ),
    )
}
```

### **A/B Test Correlation**
```yaml
# Processor to add experiment context
processors:
  attributes/experiments:
    actions:
    - key: experiment.checkout_flow
      from_attribute: http.request.header.x-experiment-checkout
      action: insert
    - key: experiment.pricing_tier
      from_attribute: http.request.header.x-experiment-pricing
      action: insert
    - key: business.conversion_funnel
      value: "checkout"
      action: insert
      include:
        match_type: strict
        span_names: ["/api/checkout", "/api/payment"]
```

## **Production Troubleshooting Scenarios**

### **Scenario 1: Multi-Backend Correlation**
**Business Context**: Payment issues detected in Datadog, need to correlate with logs in ELK  
**Solution**: Use trace ID correlation across backends

```bash
# Find trace in Datadog
curl -X GET "https://api.datadoghq.com/api/v1/traces" \
  -H "DD-API-KEY: ${DD_API_KEY}" \
  -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
  -G -d "trace_id=abc123def456"

# Correlate with logs in Elasticsearch
curl -X GET "elasticsearch:9200/logs-*/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "term": {
        "trace_id": "abc123def456"
      }
    }
  }'

# Find related spans in Jaeger
curl -G "http://jaeger:16686/api/traces/abc123def456"
```

### **Scenario 2: Cost Attribution Analysis**
**Business Context**: Observability costs spiked 300%, need to identify source  
**Investigation**: Use OpenTelemetry collector metrics

```promql
# Top services by span volume
topk(10,
  sum by (service_name) (
    rate(otelcol_processor_spans_received_total[1h])
  )
)

# Cost attribution by team
sum by (team) (
  rate(otelcol_exporter_sent_spans_total{exporter="datadog"}[1h])
) * 0.001  # Assume $0.001 per span
```

## **Performance Optimization Strategies**

### **Collector Scaling Pattern**
```yaml
# Horizontal scaling for collectors
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: otel-collector-hpa
  namespace: observability
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: otel-collector
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  # Custom metrics for business load
  - type: Pods
    pods:
      metric:
        name: otelcol_processor_spans_received_per_second
      target:
        type: AverageValue
        averageValue: "1000"  # Scale when >1K spans/sec per pod
```

### **Memory Management**
```yaml
# Collector memory optimization
processors:
  memory_limiter:
    limit_mib: 512
    spike_limit_mib: 128
    check_interval: 5s
  
  batch:
    timeout: 200ms
    send_batch_size: 512
    send_batch_max_size: 1024
```

## **Security & Compliance**

### **Data Privacy & Scrubbing**
```yaml
# Sensitive data filtering
processors:
  attributes/privacy:
    actions:
    # Remove PII from traces
    - key: http.request.header.authorization
      action: delete
    - key: http.request.header.cookie
      action: delete
    # Redact sensitive business data
    - key: user.email
      action: hash  # Hash instead of delete for correlation
    - key: payment.card_number
      action: delete
    # Mask sensitive URLs
    - key: http.url
      regex: "credit_card=([^&]*)"
      replacement: "credit_card=***REDACTED***"
      action: update
```

### **RBAC Integration**
```yaml
# Service account for collector
apiVersion: v1
kind: ServiceAccount
metadata:
  name: otel-collector
  namespace: observability
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: otel-collector
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
```

## **Best Practices for Production OpenTelemetry**

### **Golden Rules**
1. **Start with Auto-Instrumentation**: Get 80% value with 20% effort
2. **Implement Intelligent Sampling**: Cost control without losing critical data
3. **Add Business Context**: Make telemetry data meaningful for business
4. **Use Collector for Decoupling**: Avoid vendor lock-in and enable flexibility
5. **Monitor Your Monitoring**: Alert on collector health and data loss

### **Common Anti-Patterns**
❌ **Direct vendor integration**: Bypassing the collector  
❌ **No sampling strategy**: 100% sampling in production  
❌ **Missing business context**: Pure technical telemetry  
❌ **Single backend**: No redundancy or migration path  
❌ **Ignoring costs**: No span volume monitoring

## **Implementation Roadmap**

1. **Week 1**: Deploy OpenTelemetry Operator and basic collector
2. **Week 2**: Enable auto-instrumentation for one service
3. **Week 3**: Add custom business metrics and attributes
4. **Week 4**: Implement sampling strategy and cost controls
5. **Month 2**: Production collector with HA and monitoring
6. **Month 3**: Multi-backend strategy and vendor evaluation

**Remember**: OpenTelemetry is an investment in observability independence. Start small, but think strategically about vendor relationships and data ownership.