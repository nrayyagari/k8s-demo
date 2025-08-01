# Sidecar and Init Containers: Extend and Prepare Your Applications

## WHY Do Sidecar and Init Containers Exist?

**Problem**: Applications need auxiliary services, setup tasks, and extensions without modifying main code  
**Solution**: Sidecar containers run alongside main app, init containers prepare environment before app starts

## The Core Questions

**Init Containers**: "What setup work must complete before my application can start?"  
**Sidecar Containers**: "What auxiliary services should run alongside my application?"

Without: Complex application startup, monolithic designs, tight coupling  
With: Clean separation of concerns, reusable components, modular architecture

## What Init and Sidecar Containers Provide

### Init Containers (Setup Phase)
- Database schema migrations and setup
- Configuration file generation and validation
- Dependency checks and service discovery
- File system preparation and permissions
- External service registration

### Sidecar Containers (Runtime Phase)
- Logging and monitoring agents
- Service mesh proxies (Istio, Linkerd)
- Security and authentication proxies
- Data synchronization and backup
- Protocol translation and adaptation

### Container Types Comparison

| Aspect | Init Containers | Sidecar Containers | Main Containers |
|--------|----------------|-------------------|-----------------|
| **Lifecycle** | Run to completion before main | Run alongside main | Primary application |
| **Purpose** | Setup and preparation | Auxiliary services | Core business logic |
| **Startup** | Sequential execution | Parallel with main | After init completion |
| **Failure Impact** | Blocks pod startup | May restart independently | Critical for pod function |
| **Resource Sharing** | Shared volumes/network | Shared volumes/network | Own resources |

## Init Container Patterns

### Sequential Execution
```yaml
spec:
  initContainers:
  - name: step-1-database-check     # Runs first
    image: postgres:15-alpine
    command: ["sh", "-c", "until pg_isready -h postgres; do sleep 1; done"]
  
  - name: step-2-schema-migration   # Runs after step-1 completes
    image: migrate/migrate
    command: ["migrate", "-path=/migrations", "-database=postgres://...", "up"]
  
  - name: step-3-config-setup       # Runs after step-2 completes
    image: busybox
    command: ["sh", "-c", "cp /config-template/* /shared-config/"]
    
  containers:
  - name: app                       # Runs after ALL init containers complete
    image: myapp:v1.0
```

### Dependency Validation Pattern
```yaml
initContainers:
- name: wait-for-database
  image: postgres:15-alpine
  command: ["sh", "-c"]
  args:
  - |
    echo "Waiting for database to be ready..."
    until pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USER; do
      echo "Database not ready, waiting..."
      sleep 2
    done
    echo "Database is ready!"
  env:
  - name: DB_HOST
    value: "postgres.database.svc.cluster.local"
  - name: DB_PORT
    value: "5432"
  - name: DB_USER
    value: "appuser"

- name: validate-config
  image: myapp-validator:v1.0
  command: ["sh", "-c"]
  args:
  - |
    echo "Validating configuration..."
    if ! /app/validate-config /etc/config/app.yaml; then
      echo "Configuration validation failed!"
      exit 1
    fi
    echo "Configuration is valid!"
  volumeMounts:
  - name: config-volume
    mountPath: /etc/config
```

## Sidecar Container Patterns

### Logging Sidecar
```yaml
spec:
  containers:
  - name: app
    image: myapp:v1.0
    ports:
    - containerPort: 8080
    volumeMounts:
    - name: app-logs
      mountPath: /var/log/app
  
  - name: log-shipper                # Sidecar container
    image: fluent/fluent-bit:2.1
    args:
    - /fluent-bit/bin/fluent-bit
    - --config=/fluent-bit/etc/fluent-bit.conf
    volumeMounts:
    - name: app-logs
      mountPath: /var/log/app
      readOnly: true
    - name: fluent-bit-config
      mountPath: /fluent-bit/etc
  
  volumes:
  - name: app-logs
    emptyDir: {}
  - name: fluent-bit-config
    configMap:
      name: fluent-bit-config
```

### Monitoring Sidecar
```yaml
spec:
  containers:
  - name: app
    image: myapp:v1.0
    ports:
    - containerPort: 8080
    
  - name: metrics-exporter          # Sidecar for monitoring
    image: prom/node-exporter:v1.6.0
    ports:
    - name: metrics
      containerPort: 9100
    args:
    - --web.listen-address=0.0.0.0:9100
    - --path.procfs=/host/proc
    - --path.sysfs=/host/sys
    - --collector.filesystem.mount-points-exclude
    - ^/(sys|proc|dev|host|etc|rootfs/var/lib/docker/containers|rootfs/var/lib/docker/overlay2|rootfs/run/docker/netns|rootfs/var/lib/docker/aufs)($$|/)
    volumeMounts:
    - name: proc
      mountPath: /host/proc
      readOnly: true
    - name: sys
      mountPath: /host/sys
      readOnly: true
  
  volumes:
  - name: proc
    hostPath:
      path: /proc
  - name: sys
    hostPath:
      path: /sys
```

## Files in This Directory

1. **SIMPLE-SIDECAR-INIT.yaml** - Basic init and sidecar container examples
2. **01-init-container-patterns.yaml** - Database setup, config validation, dependency checks
3. **02-sidecar-patterns.yaml** - Logging, monitoring, proxy, and data sync sidecars
4. **03-service-mesh-sidecars.yaml** - Istio, Linkerd, and custom proxy patterns
5. **04-advanced-patterns.yaml** - Complex multi-container pod architectures

## Quick Start

```bash
# Apply basic examples
kubectl apply -f SIMPLE-SIDECAR-INIT.yaml

# Watch init container execution
kubectl get pods -w
kubectl describe pod <pod-name>

# Check init container logs
kubectl logs <pod-name> -c <init-container-name>

# Check sidecar container logs
kubectl logs <pod-name> -c <sidecar-container-name>

# Follow logs from specific container
kubectl logs -f <pod-name> -c <container-name>
```

## Production Examples

### Database Application with Init Setup
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-with-db-init
  annotations:
    team.company.com/owner: "backend-team"
    pattern.company.com/type: "init-container-setup"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
      pattern: init-setup
  template:
    metadata:
      labels:
        app: webapp
        pattern: init-setup
    spec:
      # Init containers run sequentially before main app
      initContainers:
      
      # 1. Wait for database to be available
      - name: wait-for-db
        image: postgres:16-alpine
        command: ["sh", "-c"]
        args:
        - |
          echo "Checking database connectivity..."
          until pg_isready -h $DB_HOST -p 5432 -U $DB_USER; do
            echo "Database not ready, waiting 5 seconds..."
            sleep 5
          done
          echo "Database is ready!"
        env:
        - name: DB_HOST
          value: "postgres.database.svc.cluster.local"
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: app-db-credentials
              key: username
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: app-db-credentials
              key: password
      
      # 2. Run database migrations
      - name: run-migrations
        image: migrate/migrate:v4.16.2
        command: ["migrate"]
        args:
        - "-path=/migrations"
        - "-database=postgres://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):5432/$(DB_NAME)?sslmode=require"
        - "up"
        env:
        - name: DB_HOST
          value: "postgres.database.svc.cluster.local"
        - name: DB_NAME
          value: "webapp"
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: app-db-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-db-credentials
              key: password
        volumeMounts:
        - name: migrations
          mountPath: /migrations

      # 3. Generate application configuration
      - name: config-generator
        image: webapp-config:v1.0
        command: ["sh", "-c"]
        args:
        - |
          echo "Generating application configuration..."
          
          # Create database connection config
          cat > /shared-config/database.yaml << EOF
          database:
            host: $DB_HOST
            port: 5432
            name: $DB_NAME
            user: $DB_USER
            ssl_mode: require
            max_connections: 20
            timeout: 30s
          EOF
          
          # Generate JWT signing keys
          openssl rand -base64 32 > /shared-config/jwt-secret
          
          # Create application config from template
          envsubst < /config-templates/app.yaml > /shared-config/app.yaml
          
          echo "Configuration generated successfully!"
        env:
        - name: DB_HOST
          value: "postgres.database.svc.cluster.local"
        - name: DB_NAME
          value: "webapp"
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: app-db-credentials
              key: username
        - name: APP_ENV
          value: "production"
        - name: LOG_LEVEL
          value: "info"
        volumeMounts:
        - name: config-templates
          mountPath: /config-templates
        - name: shared-config
          mountPath: /shared-config

      # Main application container
      containers:
      - name: webapp
        image: webapp:v2.3.1
        ports:
        - containerPort: 8080
          name: http
        - name: metrics
          containerPort: 9090
        env:
        - name: CONFIG_PATH
          value: "/etc/app-config"
        - name: PORT
          value: "8080"
        volumeMounts:
        - name: shared-config
          mountPath: /etc/app-config
          readOnly: true
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"

      # Logging sidecar container
      - name: log-forwarder
        image: fluent/fluent-bit:2.1
        args:
        - /fluent-bit/bin/fluent-bit
        - --config=/fluent-bit/etc/fluent-bit.conf
        env:
        - name: FLUENT_ELASTICSEARCH_HOST
          value: "elasticsearch.logging.svc.cluster.local"
        - name: FLUENT_ELASTICSEARCH_PORT
          value: "9200"
        volumeMounts:
        - name: fluent-bit-config
          mountPath: /fluent-bit/etc
        - name: app-logs
          mountPath: /var/log/app
          readOnly: true
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"

      volumes:
      - name: migrations
        configMap:
          name: webapp-migrations
      - name: config-templates
        configMap:
          name: webapp-config-templates
      - name: shared-config
        emptyDir: {}
      - name: fluent-bit-config
        configMap:
          name: fluent-bit-config
      - name: app-logs
        emptyDir: {}
```

### Service Mesh with Sidecar Proxy
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: microservice-with-proxy
  annotations:
    team.company.com/owner: "platform-team"
    mesh.company.com/enabled: "true"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: microservice
      version: v1
  template:
    metadata:
      labels:
        app: microservice
        version: v1
      annotations:
        # Istio sidecar injection
        sidecar.istio.io/inject: "true"
        # Custom sidecar configuration
        sidecar.istio.io/proxyCPU: "100m"
        sidecar.istio.io/proxyMemory: "128Mi"
    spec:
      # Main application container
      containers:
      - name: microservice
        image: microservice:v1.2.0
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: SERVICE_PORT
          value: "8080"
        - name: UPSTREAM_SERVICE
          value: "http://backend-service:8080"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 20
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10

      # Custom authentication proxy sidecar
      - name: auth-proxy
        image: auth-proxy:v1.1.0
        ports:
        - containerPort: 8090
          name: auth-port
        env:
        - name: UPSTREAM_URL
          value: "http://localhost:8080"
        - name: AUTH_SERVICE_URL
          value: "http://auth-service.auth.svc.cluster.local:8080"
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: jwt-secret
              key: secret
        args:
        - "--upstream=http://localhost:8080"
        - "--auth-service=http://auth-service.auth.svc.cluster.local:8080"
        - "--listen=:8090"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"

      # Monitoring sidecar
      - name: metrics-collector
        image: prom/node-exporter:v1.6.0
        ports:
        - containerPort: 9100
          name: metrics
        args:
        - "--web.listen-address=0.0.0.0:9100"
        - "--path.procfs=/host/proc"
        - "--path.sysfs=/host/sys"
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "50m"

      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys

---
# Service for the main application
apiVersion: v1
kind: Service
metadata:
  name: microservice-service
  labels:
    app: microservice
spec:
  selector:
    app: microservice
  ports:
  - name: http
    port: 80
    targetPort: 8090  # Route through auth proxy
  - name: metrics
    port: 9100
    targetPort: 9100
  type: ClusterIP
```

### Data Processing with Multiple Init Containers
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-processing-job
  annotations:
    team.company.com/owner: "data-team"
    job.company.com/type: "etl-pipeline"
spec:
  template:
    metadata:
      labels:
        job: data-processing
        component: etl
    spec:
      restartPolicy: Never
      
      # Multiple init containers for complex setup  
      initContainers:
      
      # 1. Download and validate input data
      - name: data-downloader
        image: alpine:3.18
        command: ["sh", "-c"]
        args:
        - |
          echo "Downloading input data..."
          apk add --no-cache curl
          
          # Download data files
          curl -o /data/input/customers.csv "$DATA_SOURCE_URL/customers.csv"
          curl -o /data/input/orders.csv "$DATA_SOURCE_URL/orders.csv"
          
          # Validate file integrity
          if [ ! -s /data/input/customers.csv ]; then
            echo "ERROR: customers.csv is empty or missing"
            exit 1
          fi
          
          if [ ! -s /data/input/orders.csv ]; then
            echo "ERROR: orders.csv is empty or missing" 
            exit 1
          fi
          
          echo "Data files downloaded and validated successfully"
        env:
        - name: DATA_SOURCE_URL
          value: "https://data-lake.company.com/raw-data"
        volumeMounts:
        - name: data-volume
          mountPath: /data

      # 2. Set up database connections and schemas
      - name: database-setup
        image: postgres:16-alpine
        command: ["sh", "-c"]
        args:
        - |
          echo "Setting up database connections..."
          
          # Test source database connectivity
          echo "Testing source database..."
          pg_isready -h $SOURCE_DB_HOST -p 5432 -U $SOURCE_DB_USER
          
          # Test target database connectivity  
          echo "Testing target database..."
          pg_isready -h $TARGET_DB_HOST -p 5432 -U $TARGET_DB_USER
          
          # Create staging tables if they don't exist
          psql -h $TARGET_DB_HOST -U $TARGET_DB_USER -d $TARGET_DB_NAME << 'EOF'
          CREATE TABLE IF NOT EXISTS staging_customers (
            id SERIAL PRIMARY KEY,
            customer_id VARCHAR(50),
            name VARCHAR(255),
            email VARCHAR(255),
            created_at TIMESTAMP,
            processed_at TIMESTAMP DEFAULT NOW()
          );
          
          CREATE TABLE IF NOT EXISTS staging_orders (
            id SERIAL PRIMARY KEY,
            order_id VARCHAR(50),
            customer_id VARCHAR(50), 
            amount DECIMAL(10,2),
            created_at TIMESTAMP,
            processed_at TIMESTAMP DEFAULT NOW()
          );
          EOF
          
          echo "Database setup completed successfully"
        env:
        - name: SOURCE_DB_HOST
          value: "source-db.data.svc.cluster.local"
        - name: SOURCE_DB_USER
          valueFrom:
            secretKeyRef:
              name: source-db-credentials
              key: username
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: source-db-credentials
              key: password
        - name: TARGET_DB_HOST
          value: "target-db.data.svc.cluster.local"
        - name: TARGET_DB_USER
          valueFrom:
            secretKeyRef:
              name: target-db-credentials
              key: username
        - name: TARGET_DB_NAME
          value: "analytics"

      # 3. Generate processing configuration
      - name: config-generator
        image: python:3.11-slim
        command: ["python", "-c"]
        args:
        - |
          import json
          import os
          from datetime import datetime
          
          print("Generating processing configuration...")
          
          # Get file statistics
          import csv
          
          customers_count = 0
          with open('/data/input/customers.csv', 'r') as f:
            customers_count = sum(1 for row in csv.reader(f)) - 1  # Exclude header
          
          orders_count = 0
          with open('/data/input/orders.csv', 'r') as f:
            orders_count = sum(1 for row in csv.reader(f)) - 1  # Exclude header
          
          # Generate processing config
          config = {
            "processing_id": f"job_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            "input_files": {
              "customers": "/data/input/customers.csv",
              "orders": "/data/input/orders.csv"
            },
            "record_counts": {
              "customers": customers_count,
              "orders": orders_count
            },
            "batch_size": min(1000, max(100, customers_count // 10)),
            "parallel_workers": 4,
            "error_threshold": 0.05,
            "output_format": "parquet",
            "timestamp": datetime.now().isoformat()
          }
          
          # Save configuration
          with open('/data/config/processing.json', 'w') as f:
            json.dump(config, f, indent=2)
          
          print(f"Configuration generated: {config['processing_id']}")
          print(f"Customers: {customers_count}, Orders: {orders_count}")
        volumeMounts:
        - name: data-volume
          mountPath: /data

      # Main processing container
      containers:
      - name: data-processor
        image: data-processor:v2.1.0
        command: ["python", "/app/process_data.py"]
        args: ["--config", "/data/config/processing.json"]
        env:
        - name: SOURCE_DB_CONNECTION
          value: "postgresql://$(SOURCE_DB_USER):$(SOURCE_DB_PASSWORD)@$(SOURCE_DB_HOST):5432/$(SOURCE_DB_NAME)"
        - name: TARGET_DB_CONNECTION
          value: "postgresql://$(TARGET_DB_USER):$(TARGET_DB_PASSWORD)@$(TARGET_DB_HOST):5432/$(TARGET_DB_NAME)"
        - name: PYTHONUNBUFFERED
          value: "1"
        volumeMounts:
        - name: data-volume
          mountPath: /data
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "4Gi"
            cpu: "2"

      # Sidecar container for monitoring processing progress
      - name: progress-monitor
        image: progress-monitor:v1.0
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting progress monitoring..."
          while true; do
            if [ -f /data/progress/status.json ]; then
              echo "Progress update: $(cat /data/progress/status.json)"
            fi
            sleep 30
          done
        volumeMounts:
        - name: data-volume
          mountPath: /data
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "50m"

      volumes:
      - name: data-volume
        emptyDir:
          sizeLimit: 10Gi
```

## Common Patterns and Use Cases

### 1. Configuration and Secrets Management
```yaml
initContainers:
- name: config-fetcher
  image: vault:1.14
  command: ["sh", "-c"]
  args:
  - |
    # Fetch secrets from Vault
    vault auth -method=kubernetes role=myapp
    vault kv get -field=api_key secret/myapp > /shared/api-key
    vault kv get -field=db_password secret/myapp > /shared/db-password
  volumeMounts:
  - name: shared-secrets
    mountPath: /shared
```

### 2. Service Registration
```yaml
initContainers:
- name: service-registrar
  image: consul:1.16
  command: ["sh", "-c"]
  args:
  - |
    # Register service with Consul
    consul services register \
      -name=myapp \
      -port=8080 \
      -address=$POD_IP \
      -check-http=http://$POD_IP:8080/health
  env:
  - name: POD_IP
    valueFrom:
      fieldRef:
        fieldPath: status.podIP
```

### 3. Data Synchronization Sidecar
```yaml
containers:
- name: data-sync
  image: rclone:latest
  command: ["sh", "-c"]
  args:
  - |
    while true; do
      echo "Syncing data with remote storage..."
      rclone sync /app/data remote:backup/$(hostname)
      sleep 3600  # Sync every hour
    done
  volumeMounts:
  - name: app-data
    mountPath: /app/data
  - name: rclone-config
    mountPath: /config/rclone
```

### 4. Security and Compliance Sidecar
```yaml
containers:
- name: security-scanner
  image: security-scanner:v1.0
  command: ["sh", "-c"]
  args:
  - |
    while true; do
      echo "Running security scan..."
      /app/scan-filesystem /app/files
      /app/scan-network-traffic
      /app/check-compliance
      sleep 1800  # Scan every 30 minutes
    done
  volumeMounts:
  - name: app-files
    mountPath: /app/files
    readOnly: true
  securityContext:
    privileged: true  # Required for network monitoring
```

## Advanced Multi-Container Patterns

### Ambassador Pattern
```yaml
# Ambassador proxy handles external service communication
spec:
  containers:
  - name: app
    image: myapp:v1.0
    env:
    - name: EXTERNAL_SERVICE_URL
      value: "http://localhost:8090"  # Talk to ambassador
    
  - name: ambassador
    image: nginx:alpine
    ports:
    - containerPort: 8090
    volumeMounts:
    - name: nginx-config
      mountPath: /etc/nginx/conf.d
    # nginx.conf routes to actual external service with load balancing
```

### Adapter Pattern
```yaml
# Adapter transforms app output for monitoring system
spec:
  containers:
  - name: app
    image: legacy-app:v1.0
    volumeMounts:
    - name: app-logs
      mountPath: /var/log/app
    
  - name: log-adapter
    image: log-adapter:v1.0
    command: ["sh", "-c"]
    args:
    - |
      # Convert legacy log format to JSON for modern monitoring
      tail -f /var/log/app/app.log | \
      while read line; do
        echo "$line" | /app/convert-to-json
      done
    volumeMounts:
    - name: app-logs
      mountPath: /var/log/app
      readOnly: true
```

## Container Communication

### Shared Volume Communication
```yaml
spec:
  containers:
  - name: producer
    image: data-producer:v1.0
    volumeMounts:
    - name: shared-data
      mountPath: /output
    
  - name: consumer
    image: data-consumer:v1.0
    volumeMounts:
    - name: shared-data
      mountPath: /input
      readOnly: true
  
  volumes:
  - name: shared-data
    emptyDir: {}
```

### Network Communication (Localhost)
```yaml
spec:
  containers:
  - name: server
    image: http-server:v1.0
    ports:
    - containerPort: 8080
    
  - name: client
    image: http-client:v1.0
    env:
    - name: SERVER_URL
      value: "http://localhost:8080"  # Same pod network
```

### Named Pipes (Unix Domain Sockets)
```yaml
spec:
  containers:
  - name: server
    image: socket-server:v1.0
    volumeMounts:
    - name: socket-volume
      mountPath: /var/run/sockets
    
  - name: client
    image: socket-client:v1.0
    volumeMounts:
    - name: socket-volume
      mountPath: /var/run/sockets
  
  volumes:
  - name: socket-volume
    emptyDir: {}
```

## Debugging and Troubleshooting

### Container Status and Logs
```bash
# Check pod status and container states
kubectl describe pod <pod-name>
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[*].state}'

# View init container logs
kubectl logs <pod-name> -c <init-container-name>
kubectl logs <pod-name> -c <init-container-name> --previous

# View sidecar container logs
kubectl logs <pod-name> -c <sidecar-container-name> -f

# Get logs from all containers
kubectl logs <pod-name> --all-containers=true
```

### Init Container Failures
```bash
# Check why init container failed
kubectl describe pod <pod-name>
kubectl logs <pod-name> -c <failed-init-container>

# Common issues:
# - External dependency not ready
# - Configuration errors
# - Resource constraints
# - Permission issues
```

### Sidecar Container Issues
```bash
# Check if sidecar is running
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[?(@.name=="<sidecar-name>")].ready}'

# Debug sidecar communication
kubectl exec <pod-name> -c <main-container> -- netstat -tulpn
kubectl exec <pod-name> -c <sidecar-container> -- ps aux

# Check shared volumes
kubectl exec <pod-name> -c <container-name> -- ls -la /shared/path
```

## Best Practices

### Init Container Design
```yaml
# Good practices for init containers
initContainers:
- name: dependency-check
  image: appropriate-tool:version
  command: ["sh", "-c"]
  args:
  - |
    # Always provide clear error messages
    echo "Checking dependency: $SERVICE_NAME"
    
    # Implement proper retry logic
    for i in $(seq 1 30); do
      if check_dependency; then
        echo "Dependency ready!"
        exit 0
      fi
      echo "Attempt $i/30: dependency not ready, waiting..."
      sleep 10
    done
    
    echo "ERROR: Dependency $SERVICE_NAME failed to become ready"
    exit 1
  
  # Set resource limits for init containers
  resources:
    requests:
      memory: "64Mi"
      cpu: "50m"
    limits:
      memory: "128Mi"
      cpu: "100m"
  
  # Use appropriate timeout
  # (Pod-level activeDeadlineSeconds applies to all containers)
```

### Sidecar Container Design
```yaml
# Good practices for sidecar containers
containers:
- name: sidecar
  image: sidecar-tool:version
  
  # Graceful shutdown handling
  lifecycle:
    preStop:
      exec:
        command: ["sh", "-c", "sleep 10"]  # Allow graceful cleanup
  
  # Health checks for sidecars
  livenessProbe:
    httpGet:
      path: /health
      port: 9090
    initialDelaySeconds: 30
    periodSeconds: 10
  
  # Resource limits appropriate for auxiliary function
  resources:
    requests:
      memory: "32Mi"
      cpu: "25m"
    limits:
      memory: "128Mi"
      cpu: "100m"
  
  # Security context for least privilege
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
```

### Container Ordering and Dependencies
```yaml
spec:
  # Init containers run sequentially in defined order
  initContainers:
  - name: first-init      # Runs first
  - name: second-init     # Runs after first-init completes
  - name: third-init      # Runs after second-init completes
  
  # Main containers start in parallel after ALL init containers complete
  containers:
  - name: main-app        # Starts after all init containers
  - name: sidecar-1       # Starts in parallel with main-app
  - name: sidecar-2       # Starts in parallel with main-app
```

## Performance Considerations

### Resource Planning
- Init containers use resources temporarily (setup time only)
- Sidecar containers use resources throughout pod lifetime
- Consider cumulative resource usage for scheduling
- Set appropriate limits to prevent resource starvation

### Startup Time Impact
- Each init container adds to overall pod startup time
- Design init containers to be fast and efficient
- Consider parallel setup where possible using shared volumes
- Monitor init container execution time in production

### Network and Storage
- All containers share pod network namespace (localhost communication)
- Shared volumes provide inter-container communication
- Consider I/O impact of multiple containers on shared storage
- Plan for log volume growth with multiple containers

## Key Insights

**Init containers enable clean separation of setup concerns** - database migrations, config generation, and dependency checks don't clutter main application code

**Sidecar containers implement cross-cutting concerns** - logging, monitoring, security, and networking can be handled by specialized containers

**Container lifecycle management is critical** - understand when init containers run, how sidecars start/stop, and failure propagation

**Resource sharing enables powerful patterns** - shared volumes, network namespace, and process namespace allow sophisticated inter-container communication

**Debugging multi-container pods requires container-specific techniques** - use container names with kubectl commands and understand container states

**Design for observability** - ensure each container provides adequate logging and health checks for operational visibility

**Security boundaries still apply** - containers in same pod share resources but can have different security contexts and permissions