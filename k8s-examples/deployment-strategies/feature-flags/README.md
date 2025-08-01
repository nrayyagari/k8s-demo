# Feature Flags

Feature flags (also known as feature toggles or feature switches) are a software development technique that allows teams to enable or disable features in production without deploying new code. They provide a mechanism to control feature rollouts, conduct experiments, and manage risk.

## Why Use Feature Flags?

**Problems Solved:**
- **Decouple Deployment from Release**: Deploy code without exposing features to users
- **Risk Mitigation**: Enable gradual rollouts and instant rollbacks
- **A/B Testing**: Test different variations with real users
- **Continuous Delivery**: Deploy frequently while controlling feature availability

**When to Use:**
- ✅ Gradual feature rollouts to reduce risk
- ✅ A/B testing and experimentation
- ✅ Kill switches for problematic features
- ✅ Environment-specific feature control
- ✅ User segment-based feature access

## Core Concepts

### Flag Types

**Boolean Flags (On/Off)**
```yaml
new_dashboard_enabled: "true"
dark_mode_enabled: "false"
```

**Percentage Flags (Gradual Rollout)**
```yaml
new_checkout_percentage: "25"  # 25% of users
recommendations_percentage: "50"  # 50% of users
```

**String Flags (Variants)**
```yaml
recommendation_algorithm: "collaborative_filtering"
# Possible values: "collaborative_filtering", "content_based", "hybrid"
```

**JSON Flags (Complex Configuration)**
```yaml
ui_configuration: |
  {
    "theme": "dark",
    "sidebar_collapsed": false,
    "animations_enabled": true
  }
```

### Flag Evaluation Context

**Basic User Context:**
```javascript
const user = {
  key: "user-123",
  email: "user@example.com",
  name: "John Doe"
};
```

**Advanced User Context:**
```javascript
const user = {
  key: "user-123",
  email: "user@example.com",
  name: "John Doe",
  custom: {
    tier: "premium",
    region: "us-west",
    signup_date: "2024-01-15",
    device_type: "mobile",
    beta_user: true
  }
};
```

## Implementation Approaches

### 1. ConfigMap-Based (Simple)

**Configuration Management:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: feature-flags-config
data:
  # Boolean flags
  new_dashboard_enabled: "false"
  dark_mode_enabled: "true"
  
  # Percentage flags
  new_checkout_percentage: "10"
  
  # Complex configuration
  feature_rules.json: |
    {
      "new_dashboard": {
        "enabled": false,
        "rollout_percentage": 0,
        "user_segments": ["beta_users"]
      }
    }
```

**Application Integration:**
```javascript
// Environment-based flags
const newDashboardEnabled = process.env.FEATURE_NEW_DASHBOARD === 'true';

// Percentage-based rollout
const checkoutPercentage = parseInt(process.env.FEATURE_NEW_CHECKOUT_PERCENTAGE);
const userHash = hashCode(user.id) % 100;
const showNewCheckout = userHash < checkoutPercentage;

// JSON configuration
const featureRules = JSON.parse(process.env.FEATURE_RULES);
const dashboardConfig = featureRules.new_dashboard;
```

**Management Commands:**
```bash
# Enable a feature
kubectl patch configmap feature-flags-config \
  -p='{"data":{"new_dashboard_enabled":"true"}}'

# Update rollout percentage
kubectl patch configmap feature-flags-config \
  -p='{"data":{"new_checkout_percentage":"25"}}'

# Restart pods to pick up changes
kubectl rollout restart deployment/webapp
```

### 2. LaunchDarkly Integration (Advanced)

**SDK Integration:**
```javascript
const LaunchDarkly = require('launchdarkly-node-server-sdk');
const client = LaunchDarkly.init(process.env.LAUNCHDARKLY_SDK_KEY);

// Wait for initialization
await client.waitForInitialization();

// Boolean flag evaluation
const showNewDashboard = await client.variation('new-dashboard', user, false);

// String flag evaluation
const algorithm = await client.variation('recommendation-algorithm', user, 'default');

// JSON flag evaluation
const uiConfig = await client.variation('ui-configuration', user, defaultConfig);
```

**Advanced Targeting:**
```yaml
# LaunchDarkly targeting rules
targeting:
  - if: user.custom.tier equals "premium"
    then: serve true
  - if: user.custom.region is one of ["us-west", "us-east"]
    then: serve percentage rollout 50%
  - if: user.key is in segment "beta_users"
    then: serve true
  - else: serve false
```

### 3. Custom Feature Flag Service

**Service Implementation:**
```javascript
class FeatureFlagService {
  constructor(configSource) {
    this.configSource = configSource;
    this.cache = new Map();
    this.refreshInterval = 30000; // 30 seconds
    
    setInterval(() => this.refreshConfig(), this.refreshInterval);
  }
  
  async isEnabled(flagKey, user, defaultValue = false) {
    const config = await this.getConfig(flagKey);
    
    if (!config || !config.enabled) {
      return defaultValue;
    }
    
    // Apply targeting rules
    if (this.matchesTargeting(user, config.targeting)) {
      return config.value;
    }
    
    // Apply percentage rollout
    if (config.percentage > 0) {
      const hash = this.hashUser(user.key);
      return hash % 100 < config.percentage;
    }
    
    return defaultValue;
  }
  
  matchesTargeting(user, targeting) {
    for (const rule of targeting || []) {
      if (this.evaluateRule(user, rule)) {
        return true;
      }
    }
    return false;
  }
  
  evaluateRule(user, rule) {
    const attribute = this.getUserAttribute(user, rule.attribute);
    
    switch (rule.operator) {
      case 'equals':
        return attribute === rule.value;
      case 'in':
        return rule.values.includes(attribute);
      case 'contains':
        return attribute && attribute.includes(rule.value);
      case 'startsWith':
        return attribute && attribute.startsWith(rule.value);
      default:
        return false;
    }
  }
}
```

## Common Usage Patterns

### 1. Progressive Rollout

**Week-by-Week Rollout:**
```bash
# Week 1: Internal users only (0% external)
kubectl patch configmap feature-flags-config \
  -p='{"data":{"new_feature_percentage":"0","internal_only":"true"}}'

# Week 2: 5% external users
kubectl patch configmap feature-flags-config \
  -p='{"data":{"new_feature_percentage":"5","internal_only":"false"}}'

# Week 3: 25% of users
kubectl patch configmap feature-flags-config \
  -p='{"data":{"new_feature_percentage":"25"}}'

# Week 4: 100% rollout
kubectl patch configmap feature-flags-config \
  -p='{"data":{"new_feature_percentage":"100"}}'
```

### 2. User Segment Targeting

**Premium Features:**
```javascript
// Target premium users
if (user.tier === 'premium' && featureFlags.isEnabled('premium_features', user)) {
  return renderPremiumFeatures();
}

// Target specific regions
if (['us', 'ca', 'uk'].includes(user.region) && 
    featureFlags.isEnabled('regional_feature', user)) {
  return renderRegionalFeature();
}

// Target beta users
if (user.betaUser && featureFlags.isEnabled('beta_features', user)) {
  return renderBetaFeatures();
}
```

### 3. Kill Switch Pattern

**Emergency Disable:**
```bash
# Immediate disable of problematic feature
kubectl patch configmap feature-flags-config \
  -p='{"data":{"problematic_feature_enabled":"false"}}'

# Restart all pods to pick up change immediately
kubectl rollout restart deployment/webapp
```

**Automated Kill Switch:**
```javascript
// Monitor error rates and auto-disable
class FeatureFlagMonitor {
  constructor(featureFlagService, metricsService) {
    this.flags = featureFlagService;
    this.metrics = metricsService;
    
    // Check every 30 seconds
    setInterval(() => this.checkHealthMetrics(), 30000);
  }
  
  async checkHealthMetrics() {
    const errorRate = await this.metrics.getErrorRate('new_feature');
    const latency = await this.metrics.getLatency('new_feature');
    
    // Auto-disable if error rate > 5% or latency > 2s
    if (errorRate > 0.05 || latency > 2000) {
      await this.flags.disable('new_feature');
      this.alertTeam('Feature auto-disabled due to high error rate/latency');
    }
  }
}
```

### 4. A/B Testing Integration

**Experiment Setup:**
```javascript
class ABTestManager {
  constructor(featureFlagService, analyticsService) {
    this.flags = featureFlagService;
    this.analytics = analyticsService;
  }
  
  async assignUserToExperiment(user, experimentKey) {
    const experiment = await this.flags.getExperiment(experimentKey);
    
    if (!experiment || !experiment.enabled) {
      return 'control';
    }
    
    // Consistent assignment based on user ID
    const hash = this.hashUser(user.key, experiment.salt);
    const bucket = hash % 100;
    
    if (bucket < experiment.controlPercentage) {
      this.analytics.track('experiment_assignment', {
        user: user.key,
        experiment: experimentKey,
        variant: 'control'
      });
      return 'control';
    } else if (bucket < experiment.controlPercentage + experiment.treatmentPercentage) {
      this.analytics.track('experiment_assignment', {
        user: user.key,
        experiment: experimentKey,
        variant: 'treatment'
      });
      return 'treatment';
    }
    
    return 'control'; // Default fallback
  }
}
```

## Monitoring and Observability

### Metrics Collection

**Flag Evaluation Metrics:**
```javascript
// Instrument flag evaluations
const flagEvaluationCounter = new Counter({
  name: 'feature_flag_evaluations_total',
  help: 'Total number of feature flag evaluations',
  labelNames: ['flag_key', 'result', 'user_segment']
});

const flagEvaluationDuration = new Histogram({
  name: 'feature_flag_evaluation_duration_seconds',
  help: 'Time spent evaluating feature flags',
  labelNames: ['flag_key']
});

// Usage in flag service
async function evaluateFlag(flagKey, user, defaultValue) {
  const timer = flagEvaluationDuration.startTimer({ flag_key: flagKey });
  
  try {
    const result = await this.evaluate(flagKey, user, defaultValue);
    
    flagEvaluationCounter.inc({
      flag_key: flagKey,
      result: result.toString(),
      user_segment: user.segment || 'unknown'
    });
    
    return result;
  } finally {
    timer();
  }
}
```

**Prometheus Queries:**
```promql
# Flag evaluation rate
sum(rate(feature_flag_evaluations_total[5m])) by (flag_key, result)

# Flag evaluation latency
histogram_quantile(0.95, 
  sum(rate(feature_flag_evaluation_duration_seconds_bucket[5m])) by (le, flag_key)
)

# Flag result distribution
sum(feature_flag_evaluations_total) by (flag_key, result) / 
sum(feature_flag_evaluations_total) by (flag_key) * 100
```

### Dashboard Creation

**Grafana Dashboard:**
```json
{
  "dashboard": {
    "title": "Feature Flags Dashboard",
    "panels": [
      {
        "title": "Flag Evaluation Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(feature_flag_evaluations_total[5m])) by (flag_key)",
            "legendFormat": "{{flag_key}}"
          }
        ]
      },
      {
        "title": "Flag Results Distribution",
        "type": "piechart",
        "targets": [
          {
            "expr": "sum(feature_flag_evaluations_total{flag_key=\"new_dashboard\"}) by (result)",
            "legendFormat": "{{result}}"
          }
        ]
      },
      {
        "title": "Evaluation Latency",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, sum(rate(feature_flag_evaluation_duration_seconds_bucket[5m])) by (le, flag_key))",
            "legendFormat": "p95 - {{flag_key}}"
          }
        ]
      }
    ]
  }
}
```

### Alerting Rules

**Prometheus Alerts:**
```yaml
groups:
- name: feature-flags
  rules:
  - alert: FeatureFlagEvaluationLatencyHigh
    expr: |
      histogram_quantile(0.95, 
        sum(rate(feature_flag_evaluation_duration_seconds_bucket[5m])) by (le, flag_key)
      ) > 0.1
    for: 5m
    annotations:
      summary: "Feature flag evaluation latency is high"
      description: "Flag {{$labels.flag_key}} evaluation p95 latency is {{$value}}s"
      
  - alert: FeatureFlagEvaluationErrors
    expr: |
      sum(rate(feature_flag_evaluation_errors_total[5m])) by (flag_key) > 0.01
    for: 2m
    annotations:
      summary: "Feature flag evaluation errors detected"
      description: "Flag {{$labels.flag_key}} has error rate of {{$value}}/sec"
      
  - alert: FeatureFlagServiceDown
    expr: up{job="feature-flag-service"} == 0
    for: 1m
    annotations:
      summary: "Feature flag service is down"
      description: "Feature flag service has been down for more than 1 minute"
```

## Best Practices

### 1. Flag Management

**Naming Conventions:**
```yaml
# Good naming examples
enable_new_dashboard          # Clear purpose
checkout_flow_v2             # Version indicator  
premium_user_features        # Target audience
dark_mode_ui                 # Feature description

# Avoid generic names
feature_a                    # Not descriptive
new_stuff                    # Vague
temp_flag                    # Unclear lifecycle
```

**Documentation:**
```yaml
feature_flags:
  new_dashboard:
    description: "New dashboard UI with improved user experience"
    owner: "frontend-team"
    created_date: "2025-08-01"
    expected_removal: "2025-09-01"
    rollout_strategy: "percentage_based"
    business_impact: "Expected 15% increase in user engagement"
    rollback_plan: "Disable flag and alert on-call engineer"
```

### 2. Lifecycle Management

**Flag Lifecycle:**
```
Creation → Testing → Gradual Rollout → Full Rollout → Cleanup
    ↓         ↓           ↓              ↓           ↓
   Dev      QA      Production    All Users    Remove Code
```

**Automated Cleanup:**
```bash
# Find flags eligible for cleanup (100% rollout for 30+ days)
kubectl get configmap feature-flags-config -o json | \
  jq -r '.data | to_entries[] | select(.value == "100") | .key' | \
  xargs -I {} echo "Flag {} ready for cleanup"
```

### 3. Performance Optimization

**Caching Strategy:**
```javascript
class CachedFeatureFlagService {
  constructor(upstream, cacheConfig) {
    this.upstream = upstream;
    this.cache = new Map();
    this.cacheTTL = cacheConfig.ttl || 300000; // 5 minutes
    
    // Refresh cache periodically
    setInterval(() => this.refreshCache(), this.cacheTTL / 2);
  }
  
  async isEnabled(flagKey, user, defaultValue) {
    const cacheKey = `${flagKey}:${this.getUserCacheKey(user)}`;
    const cached = this.cache.get(cacheKey);
    
    if (cached && cached.timestamp > Date.now() - this.cacheTTL) {
      return cached.value;
    }
    
    // Fetch from upstream
    const value = await this.upstream.isEnabled(flagKey, user, defaultValue);
    
    this.cache.set(cacheKey, {
      value,
      timestamp: Date.now()
    });
    
    return value;
  }
}
```

**Batch Evaluation:**
```javascript
// Evaluate multiple flags in one call
async function evaluateFlags(flagKeys, user, defaults = {}) {
  const results = {};
  
  // Batch evaluation to reduce latency
  const evaluations = await Promise.all(
    flagKeys.map(key => 
      this.flags.isEnabled(key, user, defaults[key])
        .then(result => ({ key, result }))
        .catch(error => ({ key, result: defaults[key], error }))
    )
  );
  
  evaluations.forEach(({ key, result }) => {
    results[key] = result;
  });
  
  return results;
}
```

### 4. Security Considerations

**Access Control:**
```yaml
# RBAC for flag management
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: feature-flag-manager
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["feature-flags-config"]
  verbs: ["get", "update", "patch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: feature-flag-managers
subjects:
- kind: User
  name: devops-team
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: feature-flag-manager
  apiGroup: rbac.authorization.k8s.io
```

**Audit Logging:**
```javascript
class AuditedFeatureFlagService {
  constructor(upstream, auditLogger) {
    this.upstream = upstream;
    this.audit = auditLogger;
  }
  
  async updateFlag(flagKey, newValue, user) {
    const oldValue = await this.upstream.getFlag(flagKey);
    
    await this.upstream.updateFlag(flagKey, newValue);
    
    await this.audit.log({
      action: 'flag_updated',
      flag_key: flagKey,
      old_value: oldValue,
      new_value: newValue,
      user: user.id,
      timestamp: new Date().toISOString()
    });
  }
}
```

## Troubleshooting

### Common Issues

**Flags Not Updating:**
```bash
# Check ConfigMap changes
kubectl get configmap feature-flags-config -o yaml

# Verify pod environment variables
kubectl exec -it webapp-pod -- env | grep FEATURE

# Check if pods need restart for ConfigMap changes
kubectl rollout restart deployment/webapp
```

**Inconsistent Flag Values:**
```bash
# Check for caching issues
kubectl logs -l app=webapp | grep "flag_cache"

# Verify user context consistency
kubectl logs -l app=webapp | grep "user_context" | tail -20
```

**Performance Issues:**
```bash
# Check flag evaluation latency
kubectl logs -l app=webapp | grep "flag_evaluation_duration"

# Monitor flag service health
kubectl get pods -l app=feature-flag-service
kubectl logs -l app=feature-flag-service --tail=50
```

### Debug Commands

**Flag Evaluation Testing:**
```bash
# Test flag via API
curl -H "X-User-ID: test-user" \
     -H "X-User-Tier: premium" \
     http://webapp-service/debug/flags

# Check flag configuration
kubectl exec -it webapp-pod -- cat /etc/feature-flags/feature_rules.json | jq
```

**Monitoring Commands:**
```bash
# Watch flag evaluations in real-time
kubectl logs -l app=webapp -f | grep feature_flag

# Check flag service metrics
curl http://webapp-service:9090/metrics | grep feature_flag
```

## Files in This Section

- **`01-basic-feature-flags.yaml`**: ConfigMap-based feature flags with simple implementation
- **`02-advanced-feature-flags-launchdarkly.yaml`**: Enterprise-grade feature flags with LaunchDarkly
- **`SIMPLE-FEATURE-FLAGS.yaml`**: Quick-start template for immediate use

## Next Steps

1. **Start Simple**: Implement basic ConfigMap-based feature flags
2. **Add Monitoring**: Set up comprehensive metrics and alerting
3. **User Targeting**: Implement user segment-based targeting
4. **Service Integration**: Integrate with LaunchDarkly or similar service
5. **Automation**: Build automated flag lifecycle management