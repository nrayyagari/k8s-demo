# Jobs: Run Tasks to Completion

## WHY Do Jobs Exist?

**Problem**: Need to run tasks that complete and exit, not run forever like web servers  
**Solution**: Jobs run Pods to completion for batch processing, data migration, and one-time tasks

## The Core Question

**"How do I run a task that finishes and exits successfully?"**

Deployment: Keeps app running forever → Restarts if it exits  
Job: Runs task to completion → Marks as successful when done

## What Jobs Do

### Run to Completion
- Starts pods to execute specific tasks
- Monitors completion and success
- Retries on failure with backoff
- Cleans up when finished

### Batch Processing
- Single task execution
- Parallel task processing  
- Work queue pattern processing
- Indexed job processing (new in K8s 1.24+)

### Failure Handling
- Automatic retry with exponential backoff
- Configurable failure limits
- Pod replacement on node failure
- Timeout protection

## Basic Patterns

### 1. Single Task Job
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-migration
spec:
  template:
    spec:
      containers:
      - name: migrator
        image: postgres:15-alpine
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting data migration..."
          psql -h $DB_HOST -d $DB_NAME -c "UPDATE users SET status='active' WHERE created_at < '2024-01-01';"
          echo "Migration completed successfully!"
        env:
        - name: DB_HOST
          value: "postgres.database.svc.cluster.local"
      restartPolicy: Never  # Critical: Never or OnFailure only
  backoffLimit: 3         # Retry up to 3 times
```

### 2. Parallel Job with Fixed Completions
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-processing
spec:
  parallelism: 5        # Run 5 pods concurrently
  completions: 20       # Need 20 successful completions total
  template:
    spec:
      containers:
      - name: processor
        image: python:3.9-slim
        command: ["python", "-c"]
        args:
        - |
          import time
          import random
          import os
          
          # Simulate processing work
          task_id = random.randint(1000, 9999)
          print(f"Processing task {task_id}...")
          time.sleep(10)  # Simulate work
          print(f"Task {task_id} completed successfully!")
      restartPolicy: Never
```

### 3. Indexed Jobs (Kubernetes 1.24+)
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: indexed-simulation
spec:
  parallelism: 3
  completions: 10
  completionMode: Indexed  # Each pod gets unique index
  template:
    spec:
      containers:
      - name: simulation
        image: python:3.9-slim
        command: ["python", "-c"]
        args:
        - |
          import os
          import time
          
          # Get unique job index
          index = os.environ.get('JOB_COMPLETION_INDEX', '0')
          print(f"Running simulation #{index}")
          
          # Simulate different work based on index  
          time.sleep(int(index) * 2 + 5)
          print(f"Simulation #{index} completed!")
        env:
        - name: JOB_COMPLETION_INDEX
          valueFrom:
            fieldRef:
              fieldPath: metadata.annotations['batch.kubernetes.io/job-completion-index']
      restartPolicy: Never
```

## Job vs Other Workloads

### ✅ Use Jobs For:
- **Data migration** and database updates
- **Batch processing** and ETL pipelines
- **Image processing** and media conversion
- **Report generation** and analytics
- **Backup and archival** tasks
- **Machine learning training** jobs
- **One-time setup** and initialization tasks

### ❌ Don't Use Jobs For:
- **Web servers** → Use Deployments (need to stay running)
- **Scheduled tasks** → Use CronJobs (recurring execution)
- **Node monitoring** → Use DaemonSets (one per node)
- **Long-running services** → Use Deployments or StatefulSets

## Files in This Directory

1. **SIMPLE-JOBS.yaml** - Basic job examples with explanations
2. **01-single-task-job.yaml** - Simple one-time task execution
3. **02-parallel-processing.yaml** - Parallel job with multiple workers
4. **03-indexed-jobs.yaml** - Indexed jobs for unique task processing
5. **04-data-migration.yaml** - Real-world database migration example

## Quick Start

```bash
# Run basic job
kubectl apply -f SIMPLE-JOBS.yaml

# Check job status
kubectl get jobs
kubectl describe job data-processing

# Watch job progress
kubectl get jobs --watch

# View job pods
kubectl get pods -l job-name=data-processing

# Check job logs
kubectl logs -l job-name=data-processing
```

## Job Configuration Options

### Failure Handling
```yaml
spec:
  backoffLimit: 6              # Max retries (default: 6)
  activeDeadlineSeconds: 3600  # Job timeout (1 hour)
  ttlSecondsAfterFinished: 600 # Auto-cleanup after 10 minutes
```

### Parallelism Control
```yaml
spec:
  parallelism: 10     # Max pods running concurrently
  completions: 50     # Total successful completions needed
  
  # For work queue pattern (completions not specified):
  parallelism: 5      # Workers pull from shared queue
```

### Pod Management
```yaml
spec:
  template:
    spec:
      restartPolicy: Never    # Create new pod on failure
      # OR
      restartPolicy: OnFailure  # Restart container in same pod
```

### Success Policy (Kubernetes 1.33+)
```yaml
spec:
  successPolicy:
    rules:
    - succeededCount: 3    # Job succeeds when 3 pods complete
                          # (even if completions is higher)
```

## Common Job Patterns

### Work Queue Pattern
```yaml
# Multiple workers process from shared queue
# No completions specified - workers exit when queue empty
apiVersion: batch/v1
kind: Job
metadata:
  name: queue-workers
spec:
  parallelism: 5  # 5 workers
  # No completions - workers decide when done
  template:
    spec:
      containers:
      - name: worker
        image: queue-processor:v1.0
        env:
        - name: QUEUE_URL
          value: "redis://queue.default.svc.cluster.local:6379"
        command: ["python", "worker.py"]
      restartPolicy: Never
```

### Database Batch Processing
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: user-cleanup
spec:
  parallelism: 3
  completions: 1  # Only need one successful completion
  template:
    spec:
      containers:
      - name: cleanup
        image: postgres:15-alpine
        command: ["sh", "-c"]
        args:
        - |
          # Delete inactive users older than 2 years
          psql -h $DB_HOST -d $DB_NAME << 'EOF'
          BEGIN;
          DELETE FROM user_sessions WHERE user_id IN (
            SELECT id FROM users 
            WHERE last_login < NOW() - INTERVAL '2 years'
            AND status = 'inactive'
          );
          DELETE FROM users 
          WHERE last_login < NOW() - INTERVAL '2 years'
          AND status = 'inactive';
          COMMIT;
          EOF
          echo "Cleanup completed successfully"
        env:
        - name: DB_HOST
          value: "postgres.database.svc.cluster.local"
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: password
      restartPolicy: Never
  backoffLimit: 2
  activeDeadlineSeconds: 1800  # 30 minute timeout
```

## Advanced Features

### Resource Management
```yaml
spec:
  template:
    spec:
      containers:
      - name: processor
        image: data-processor:v1.0
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "4Gi"
            cpu: "2"
        # Prevent eviction during processing
        annotations:
          cluster-autoscaler.kubernetes.io/safe-to-evict: "false"
```

### Pod Disruption Control
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: job-pdb
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      job-name: critical-processing
```

### Node Affinity for Special Hardware
```yaml
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: accelerator
                operator: In
                values: ["nvidia-tesla-p100"]
      containers:
      - name: ml-training
        image: tensorflow/tensorflow:latest-gpu
        resources:
          limits:
            nvidia.com/gpu: 1
```

## Common Operations

### Managing Jobs
```bash
# Create job
kubectl apply -f my-job.yaml

# Monitor progress
kubectl get job my-job --watch
kubectl describe job my-job

# View job events
kubectl get events --field-selector involvedObject.name=my-job

# Check pod logs
kubectl logs -l job-name=my-job
kubectl logs -l job-name=my-job --previous  # Previous container logs
```

### Job Lifecycle
```bash
# Suspend job (stop creating new pods)
kubectl patch job my-job -p '{"spec":{"suspend":true}}'

# Resume job
kubectl patch job my-job -p '{"spec":{"suspend":false}}'

# Delete job (keeps pods)
kubectl delete job my-job

# Delete job and pods
kubectl delete job my-job --cascade=foreground
```

### Debugging Jobs
```bash
# Check why job failed
kubectl describe job failed-job
kubectl get events --field-selector involvedObject.name=failed-job

# Inspect failed pods
kubectl get pods -l job-name=failed-job
kubectl describe pod <failed-pod-name>
kubectl logs <failed-pod-name>

# Check resource constraints
kubectl top nodes
kubectl describe node <node-name>
```

## Troubleshooting

### Job Pods Not Starting
```bash
# Check job status
kubectl describe job my-job

# Common issues:
# - Insufficient resources
# - Image pull errors  
# - Node selector constraints
# - Pod security policies
```

### Job Never Completes
```bash
# Check if pods are succeeding
kubectl get pods -l job-name=my-job

# Check pod exit codes
kubectl describe pod <pod-name>

# Common issues:
# - Application never exits (exit 0)
# - Wrong restartPolicy (should be Never/OnFailure)
# - Infinite loops in application code
```

### Job Exceeds Backoff Limit
```bash
# Check failed pod logs
kubectl logs -l job-name=my-job --previous

# Common solutions:
# - Fix application bugs
# - Increase backoffLimit
# - Add resource limits
# - Fix environment configuration
```

## Best Practices

### Resource Planning
```yaml
# Always set resource requests and limits
resources:
  requests:
    memory: "512Mi"  # Minimum needed
    cpu: "200m"
  limits:
    memory: "2Gi"    # Maximum allowed
    cpu: "1"
```

### Failure Handling
```yaml
# Configure appropriate failure handling
spec:
  backoffLimit: 3              # Allow reasonable retries
  activeDeadlineSeconds: 3600  # Prevent runaway jobs
  ttlSecondsAfterFinished: 86400  # Clean up after 24 hours
```

### Monitoring and Observability
```yaml
metadata:
  annotations:
    # Add monitoring configuration
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    
    # Add ownership information
    team.company.com/owner: "data-engineering"
    runbook.company.com/url: "https://wiki.company.com/jobs/data-processing"
```

### Security
```yaml
spec:
  template:
    spec:
      # Use service accounts with minimal permissions
      serviceAccountName: job-runner
      
      # Set security context
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      
      containers:
      - name: processor
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
```

## Performance Optimization

### Parallel Processing
```yaml
# Optimize parallelism based on:
# - Available cluster resources
# - External system limits (database connections)
# - Task interdependencies

spec:
  parallelism: 10     # Start conservative
  completions: 100    # Total work items
  
  # Monitor and adjust based on:
  # - Resource utilization
  # - Task completion time
  # - External system performance
```

### Resource Efficiency
```yaml
# Right-size resources for job workload
resources:
  requests:
    memory: "256Mi"   # Based on actual usage patterns
    cpu: "100m"       # CPU-light jobs need less
  limits:
    memory: "1Gi"     # Allow headroom for data processing
    cpu: "500m"       # Prevent resource hogging
```

## Key Insights

**Jobs are designed for finite workloads** - they run to completion, unlike Deployments that run forever

**Always set restartPolicy to Never or OnFailure** - default Always will cause job to never complete

**Use parallelism wisely** - more parallel pods isn't always faster, consider external system limits

**Monitor resource usage** - batch jobs often have different resource patterns than web applications

**Plan for failures** - set appropriate backoffLimit and activeDeadlineSeconds to handle transient issues

**Clean up completed jobs** - use ttlSecondsAfterFinished to prevent accumulation of old job objects

**Jobs are building blocks** - they're used by CronJobs and other controllers for scheduled execution