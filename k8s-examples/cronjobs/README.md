# CronJobs: Scheduled Task Execution

## WHY Do CronJobs Exist?

**Problem**: Need to run tasks on a schedule (backups, reports, cleanup) automatically  
**Solution**: CronJobs create Jobs on a repeating schedule, just like Unix cron

## The Core Question

**"How do I run tasks automatically on a schedule?"**

Manual execution: Remember to run backup every night → Often forgotten  
CronJob: Automatically runs backup at 2 AM daily → Never forgotten

## What CronJobs Do

### Scheduled Execution
- Creates Jobs automatically based on cron schedule
- Handles timezone considerations
- Manages job history and cleanup
- Provides concurrency control

### Job Management
- Creates Job objects on schedule
- Monitors job success/failure
- Maintains configurable history limits
- Handles missed executions

### Production Reliability
- Prevents overlapping executions
- Handles node failures gracefully
- Provides audit trail of executions
- Integrates with monitoring systems

## Basic Pattern

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: database-backup
spec:
  schedule: "0 2 * * *"          # Daily at 2 AM
  timeZone: "America/New_York"   # Specific timezone
  concurrencyPolicy: Forbid      # Prevent overlapping jobs
  successfulJobsHistoryLimit: 3  # Keep 3 successful jobs
  failedJobsHistoryLimit: 1      # Keep 1 failed job
  startingDeadlineSeconds: 300   # Must start within 5 minutes
  
  jobTemplate:                   # Template for created Jobs
    spec:
      activeDeadlineSeconds: 3600  # 1 hour timeout
      template:
        spec:
          containers:
          - name: backup
            image: postgres:15-alpine
            command: ["sh", "-c"]
            args: ["pg_dump ... && aws s3 cp ..."]
          restartPolicy: OnFailure
```

## Cron Schedule Format

### Cron Expression Syntax
```
# ┌───────────── minute (0 - 59)
# │ ┌───────────── hour (0 - 23)
# │ │ ┌───────────── day of month (1 - 31)
# │ │ │ ┌───────────── month (1 - 12)
# │ │ │ │ ┌───────────── day of week (0 - 6) (Sunday=0)
# │ │ │ │ │
# * * * * *
```

### Common Schedules
```yaml
# Every minute (testing only!)
schedule: "* * * * *"

# Every 15 minutes
schedule: "*/15 * * * *"

# Every hour at minute 30
schedule: "30 * * * *"

# Daily at 2:30 AM
schedule: "30 2 * * *"

# Weekly on Sunday at midnight
schedule: "0 0 * * 0"

# Monthly on 1st at 9 AM
schedule: "0 9 1 * *"

# Weekdays at 6 PM
schedule: "0 18 * * 1-5"

# Twice daily (6 AM and 6 PM)
schedule: "0 6,18 * * *"
```

### Special Expressions
```yaml
# Yearly (January 1st at midnight)
schedule: "@yearly"    # Same as "0 0 1 1 *"

# Monthly (1st of month at midnight)
schedule: "@monthly"   # Same as "0 0 1 * *"

# Weekly (Sunday at midnight)
schedule: "@weekly"    # Same as "0 0 * * 0"

# Daily (midnight)
schedule: "@daily"     # Same as "0 0 * * *"

# Hourly (top of hour)
schedule: "@hourly"    # Same as "0 * * * *"
```

## Concurrency Policies

### Allow (Default)
- Allows multiple jobs to run simultaneously
- Can lead to resource contention
- Use when jobs are independent and lightweight

### Forbid
- Prevents overlapping executions
- Skips new job if previous is still running
- Best for resource-intensive or conflicting operations

### Replace
- Cancels running job and starts new one
- Use when newer execution is more important
- Good for data processing where latest data matters

```yaml
spec:
  concurrencyPolicy: Forbid  # Most common for production
```

## Files in This Directory

1. **SIMPLE-CRONJOBS.yaml** - Basic cronjob examples with explanations
2. **01-backup-cronjob.yaml** - Database backup automation
3. **02-cleanup-cronjob.yaml** - System cleanup and maintenance
4. **03-reporting-cronjob.yaml** - Automated report generation
5. **04-monitoring-cronjob.yaml** - Health checks and monitoring

## Quick Start

```bash
# Deploy basic cronjobs
kubectl apply -f SIMPLE-CRONJOBS.yaml

# Check cronjob status
kubectl get cronjobs
kubectl describe cronjob database-backup

# View cronjob history
kubectl get jobs
kubectl get jobs -l cronjob=database-backup

# Check recent executions
kubectl get pods -l job-name
kubectl logs -l job-name=database-backup-1642276800
```

## Time Zones and Scheduling

### Time Zone Support
```yaml
spec:
  schedule: "0 9 * * 1-5"        # 9 AM weekdays
  timeZone: "America/New_York"   # EST/EDT handling
  
  # Other timezone examples:
  # timeZone: "UTC"              # Universal time
  # timeZone: "Europe/London"    # GMT/BST handling
  # timeZone: "Asia/Tokyo"       # JST
```

### Daylight Saving Time
CronJobs with timezone automatically handle DST transitions:
- Spring forward: Job may be skipped if scheduled during "lost" hour
- Fall back: Job may run twice if scheduled during "repeated" hour

## History Management

```yaml
spec:
  # Control job retention
  successfulJobsHistoryLimit: 5   # Keep 5 successful jobs (default: 3)
  failedJobsHistoryLimit: 2       # Keep 2 failed jobs (default: 1)
  
  # Setting to 0 disables history
  successfulJobsHistoryLimit: 0   # No successful job history
```

## Production Examples

### Database Backup CronJob
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  annotations:
    team.company.com/owner: "database-team"
    backup.company.com/type: "full-backup"
    monitoring.company.com/alert-on-failure: "true"
spec:
  schedule: "0 2 * * *"              # Daily at 2 AM
  timeZone: "UTC"                    # Use UTC for consistency
  concurrencyPolicy: Forbid          # No overlapping backups
  successfulJobsHistoryLimit: 7      # Week of successful backups
  failedJobsHistoryLimit: 3          # Keep failed attempts for debugging
  startingDeadlineSeconds: 600       # Must start within 10 minutes
  
  jobTemplate:
    metadata:
      annotations:
        backup.company.com/database: "production"
    spec:
      activeDeadlineSeconds: 7200    # 2 hour timeout
      template:
        metadata:
          annotations:
            cluster-autoscaler.kubernetes.io/safe-to-evict: "false"
        spec:
          containers:
          - name: backup
            image: postgres:15-alpine
            command: ["sh", "-c"]
            args:
            - |
              echo "Starting backup at $(date)"
              
              # Create timestamped backup
              BACKUP_FILE="backup-$(date +%Y%m%d-%H%M%S).sql.gz"
              
              # Dump database with compression
              pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME | gzip > /tmp/$BACKUP_FILE
              
              # Upload to S3 with metadata
              aws s3 cp /tmp/$BACKUP_FILE s3://company-backups/postgres/$BACKUP_FILE \
                --metadata "database=$DB_NAME,backup-type=full,created-by=cronjob"
              
              # Verify upload
              aws s3 ls s3://company-backups/postgres/$BACKUP_FILE
              
              # Clean up local file
              rm /tmp/$BACKUP_FILE
              
              echo "Backup completed successfully at $(date)"
            
            env:
            - name: DB_HOST
              value: "postgres.database.svc.cluster.local"
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: postgres-backup-credentials
                  key: username
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-backup-credentials  
                  key: password
            - name: DB_NAME
              value: "production"
            
            resources:
              requests:
                memory: "256Mi"
                cpu: "100m"
              limits:
                memory: "1Gi"
                cpu: "500m"
          
          restartPolicy: OnFailure
```

### Log Cleanup CronJob
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: log-cleanup
  annotations:
    team.company.com/owner: "platform-team"
    cleanup.company.com/type: "log-rotation"
spec:
  schedule: "0 1 * * *"              # Daily at 1 AM
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: cleanup
            image: busybox:1.35
            command: ["sh", "-c"]
            args:
            - |
              echo "Starting log cleanup at $(date)"
              
              # Clean up application logs older than 30 days
              find /var/log/apps -name "*.log" -mtime +30 -delete
              
              # Clean up archived logs older than 90 days  
              find /var/log/apps -name "*.log.gz" -mtime +90 -delete
              
              # Report cleanup results
              echo "Cleanup completed at $(date)"
              echo "Disk usage after cleanup:"
              df -h /var/log/apps
            
            volumeMounts:
            - name: log-volume
              mountPath: /var/log/apps
              
          volumes:
          - name: log-volume
            hostPath:
              path: /var/log/applications
              
          restartPolicy: OnFailure
          
          # Run on specific nodes with log storage
          nodeSelector:
            node-role.kubernetes.io/log-storage: "true"
```

### Report Generation CronJob
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: weekly-report
  annotations:
    team.company.com/owner: "analytics-team"
    report.company.com/type: "weekly-summary"
spec:
  schedule: "0 8 * * 1"              # Monday at 8 AM
  timeZone: "America/New_York"       # Business timezone
  concurrencyPolicy: Forbid
  
  jobTemplate:
    spec:
      activeDeadlineSeconds: 1800    # 30 minute timeout
      template:
        spec:
          containers:
          - name: report-generator
            image: python:3.9-slim
            command: ["python", "-c"]
            args:
            - |
              import datetime
              import json
              import requests
              
              print("Generating weekly report...")
              
              # Calculate date range
              today = datetime.date.today()
              week_start = today - datetime.timedelta(days=today.weekday() + 7)
              week_end = week_start + datetime.timedelta(days=6)
              
              print(f"Report period: {week_start} to {week_end}")
              
              # Generate report data (simplified)
              report_data = {
                  "period": f"{week_start} to {week_end}",
                  "metrics": {
                      "total_users": 1500,
                      "new_signups": 45,
                      "active_sessions": 12000
                  }
              }
              
              # Send report (example)
              print("Report generated successfully")
              print(json.dumps(report_data, indent=2))
            
            resources:
              requests:
                memory: "128Mi"
                cpu: "50m"
              limits:
                memory: "512Mi"
                cpu: "200m"
                
          restartPolicy: OnFailure
```

## Advanced Configuration

### Suspend CronJob
```yaml
spec:
  suspend: true  # Temporarily disable cronjob
```

### Custom Job Template
```yaml
jobTemplate:
  spec:
    # Job-specific configuration
    backoffLimit: 2
    activeDeadlineSeconds: 3600
    ttlSecondsAfterFinished: 86400
    
    template:
      # Pod template
      metadata:
        annotations:
          prometheus.io/scrape: "true"
      spec:
        serviceAccountName: cronjob-runner
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
```

## Common Operations

### Managing CronJobs
```bash
# Create cronjob
kubectl apply -f my-cronjob.yaml

# List cronjobs
kubectl get cronjobs
kubectl get cj  # Short form

# Describe cronjob
kubectl describe cronjob my-backup

# Suspend cronjob
kubectl patch cronjob my-backup -p '{"spec":{"suspend":true}}'

# Resume cronjob
kubectl patch cronjob my-backup -p '{"spec":{"suspend":false}}'
```

### Monitoring Executions
```bash
# View job history
kubectl get jobs -l cronjob=my-backup
kubectl get jobs --sort-by='.status.startTime'

# Check recent pods
kubectl get pods -l cronjob=my-backup
kubectl logs -l cronjob=my-backup --tail=100

# View events
kubectl get events --field-selector involvedObject.name=my-backup
```

### Manual Execution
```bash
# Create job from cronjob (testing)
kubectl create job manual-backup --from=cronjob/my-backup

# Check manual job
kubectl get job manual-backup
kubectl logs -l job-name=manual-backup
```

## Troubleshooting

### CronJob Not Running
```bash
# Check cronjob status
kubectl describe cronjob my-backup

# Common issues:
# - Suspended: spec.suspend=true
# - Invalid schedule format
# - Missing permissions
# - Resource constraints

# Check next scheduled time
kubectl get cronjob my-backup -o yaml | grep lastScheduleTime
```

### Jobs Failing
```bash
# Check failed jobs
kubectl get jobs -l cronjob=my-backup
kubectl describe job <failed-job-name>

# Check pod logs
kubectl logs -l job-name=<failed-job-name>

# Common issues:
# - Image pull errors
# - Resource limits exceeded
# - Application errors
# - Network connectivity
```

### Missed Executions
```bash
# Check if job was scheduled
kubectl describe cronjob my-backup

# Reasons for missed executions:
# - startingDeadlineSeconds exceeded
# - Cluster resources unavailable
# - Node failures
# - Scheduler issues
```

## Best Practices

### Scheduling Strategy
```yaml
# Spread cronjobs across time to avoid resource conflicts
# Good: Stagger backup times
backup-db1: "0 1 * * *"   # 1 AM
backup-db2: "0 2 * * *"   # 2 AM  
cleanup:    "0 3 * * *"   # 3 AM

# Bad: All at same time
backup-db1: "0 2 * * *"
backup-db2: "0 2 * * *"  # Resource conflict!
cleanup:    "0 2 * * *"  # Resource conflict!
```

### Resource Management
```yaml
# Set appropriate resource limits
resources:
  requests:
    memory: "256Mi"    # Conservative estimate
    cpu: "100m"
  limits:
    memory: "1Gi"      # Prevent memory leaks
    cpu: "500m"        # Prevent CPU hogging
```

### Monitoring and Alerting
```yaml
metadata:
  annotations:
    # Enable monitoring
    monitoring.company.com/alert-on-failure: "true"
    monitoring.company.com/expected-duration: "15m"
    
    # Contact information
    team.company.com/owner: "platform-team"
    team.company.com/slack: "#platform-alerts"
```

### Security
```yaml
jobTemplate:
  spec:
    template:
      spec:
        # Use minimal service account
        serviceAccountName: backup-runner
        
        # Security context
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          fsGroup: 2000
        
        containers:
        - name: backup
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
```

### Error Handling
```yaml
jobTemplate:
  spec:
    # Reasonable retry policy
    backoffLimit: 2
    
    # Timeout protection
    activeDeadlineSeconds: 3600
    
    # Cleanup policy
    ttlSecondsAfterFinished: 86400  # 24 hours
```

## Performance Considerations

### Resource Planning
- Schedule intensive jobs during low-traffic periods
- Avoid overlapping resource-heavy cronjobs
- Monitor cluster resource usage patterns
- Use node affinity for specialized workloads

### History Management
- Set reasonable history limits
- Clean up old jobs regularly
- Monitor storage usage for job logs
- Consider external log aggregation

## Key Insights

**CronJobs are built on Jobs** - they create Job objects on schedule, inheriting all Job capabilities

**Use timezone specification** - avoid confusion with daylight saving time and distributed teams

**Forbid concurrency for most use cases** - prevents resource conflicts and ensures data consistency

**Monitor execution patterns** - set up alerts for failed or missed executions

**Plan resource usage** - schedule intensive jobs during off-peak hours

**Test schedule expressions** - use online cron validators to verify complex schedules

**CronJobs enable automation** - they're essential for maintenance, monitoring, and batch processing in production