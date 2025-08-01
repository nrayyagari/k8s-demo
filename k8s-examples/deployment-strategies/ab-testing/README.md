# A/B Testing

A/B testing is a method of comparing two versions of a web page, application feature, or user experience to determine which performs better. It involves showing different variants to different user groups and measuring the impact on key metrics.

## Why Use A/B Testing?

**Problems Solved:**
- **Data-Driven Decisions**: Make feature decisions based on real user behavior, not assumptions
- **Risk Mitigation**: Test changes with limited users before full rollout
- **Performance Optimization**: Continuously improve conversion rates and user engagement
- **Feature Validation**: Validate that new features actually improve user experience

**When to Use:**
- ✅ Testing UI/UX changes that might impact user behavior
- ✅ Optimizing conversion funnels and business metrics
- ✅ Validating new features before full deployment
- ✅ Making data-driven product decisions

## Core Concepts

### Experiment Design

**Hypothesis Formation:**
```
"If we change [X] to [Y], then [metric] will [increase/decrease] by [amount] 
because [reasoning based on user behavior/psychology]"

Example: "If we change the checkout button color from blue to green, 
then conversion rate will increase by 5% because green suggests 'go' 
and creates more urgency"
```

**Key Elements:**
- **Control Group (A)**: Current version (baseline)
- **Treatment Group (B)**: New version being tested
- **Success Metrics**: Quantifiable measures of success
- **Guardrail Metrics**: Metrics that shouldn't degrade
- **Statistical Significance**: Confidence that results aren't due to chance

### Traffic Allocation Strategies

**Equal Split (50/50)**
```yaml
# Most common for comparing two variants
traffic_allocation:
  control: 50%
  treatment: 50%
```

**Unequal Split (90/10)**
```yaml
# Conservative approach for risky changes
traffic_allocation:
  control: 90%
  treatment: 10%
```

**Multi-Variate (A/B/C Testing)**
```yaml
# Testing multiple variants simultaneously
traffic_allocation:
  control: 34%
  treatment_b: 33%
  treatment_c: 33%
```

## Implementation Approaches

### 1. Pod-Based A/B Testing

**Simple Traffic Splitting:**
```yaml
# Control deployment (50% of pods)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-control
spec:
  replicas: 5
  selector:
    matchLabels:
      variant: control

# Treatment deployment (50% of pods)  
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-treatment
spec:
  replicas: 5
  selector:
    matchLabels:
      variant: treatment

# Service routes to both
apiVersion: v1
kind: Service
spec:
  selector:
    app: webapp  # Routes to both variants
```

**User Assignment Logic:**
```nginx
# Nginx configuration for consistent user assignment
set $user_id $http_x_user_id;
set $variant "control";

if ($user_id) {
  set_by_lua_block $variant {
    local user_id = ngx.var.user_id
    local hash = ngx.crc32_long(user_id)
    return (hash % 2 == 0) and "control" or "treatment"
  }
}

proxy_set_header X-Experiment-Variant $variant;
```

### 2. Service Mesh A/B Testing (Istio)

**Advanced Traffic Control:**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: webapp-ab-test
spec:
  http:
  # Bot exclusion
  - match:
    - headers:
        user-agent:
          regex: ".*(bot|crawler|spider).*"
    route:
    - destination:
        subset: control
      weight: 100

  # Geographic segmentation
  - match:
    - headers:
        x-country:
          exact: "US"
    route:
    - destination:
        subset: control
      weight: 60
    - destination:
        subset: treatment
      weight: 40

  # Default split
  - route:
    - destination:
        subset: control
      weight: 50
    - destination:
        subset: treatment
      weight: 50
```

**User Cohort Routing:**
```yaml
# Premium users get conservative allocation
- match:
  - headers:
      x-user-tier:
        exact: "premium"
  route:
  - destination:
      subset: control
    weight: 80  # More conservative for premium users
  - destination:
      subset: treatment
    weight: 20
```

## Experiment Lifecycle

### Phase 1: Planning and Setup

**Sample Size Calculation:**
```python
import scipy.stats as stats
import numpy as np

def sample_size_calculation(baseline_rate, mde, alpha=0.05, power=0.8):
    """
    Calculate required sample size for A/B test
    
    baseline_rate: Current conversion rate (e.g., 0.15 = 15%)
    mde: Minimum detectable effect (e.g., 0.05 = 5% relative improvement) 
    alpha: Significance level (usually 0.05)
    power: Statistical power (usually 0.8)
    """
    treatment_rate = baseline_rate * (1 + mde)
    
    # Calculate required sample size per group
    n = stats.ttest_ind_from_stats(
        baseline_rate, np.sqrt(baseline_rate * (1 - baseline_rate)), 1000,
        treatment_rate, np.sqrt(treatment_rate * (1 - treatment_rate)), 1000
    ).statistic
    
    # Using power analysis formula
    z_alpha = stats.norm.ppf(1 - alpha/2)
    z_beta = stats.norm.ppf(power)
    
    pooled_rate = (baseline_rate + treatment_rate) / 2
    
    n_per_group = (
        2 * pooled_rate * (1 - pooled_rate) * 
        (z_alpha + z_beta)**2 / 
        (treatment_rate - baseline_rate)**2
    )
    
    return int(np.ceil(n_per_group))

# Example calculation
baseline = 0.15  # 15% conversion rate
mde = 0.05      # 5% relative improvement
required_n = sample_size_calculation(baseline, mde)
print(f"Required sample size per group: {required_n}")
```

### Phase 2: Experiment Execution

**Deployment Commands:**
```bash
# Deploy A/B test infrastructure
kubectl apply -f ab-testing-setup.yaml

# Verify traffic distribution
kubectl get pods -l app=webapp --show-labels
kubectl get endpoints webapp-service

# Monitor experiment in real-time
kubectl logs -l variant=control --tail=100 -f | grep conversion &
kubectl logs -l variant=treatment --tail=100 -f | grep conversion &
```

**Real-Time Monitoring:**
```bash
# Check traffic split
for i in {1..20}; do
  curl -s -H "X-User-ID: user$i" http://webapp-service | grep variant
  sleep 1
done

# Load test both variants
kubectl run load-test --image=fortio/fortio --restart=Never -- \
  load -qps 50 -t 3600s -c 10 \
  -H "X-User-ID: test-user-{#}" \
  http://webapp-service/
```

### Phase 3: Data Collection and Analysis

**Key Metrics to Track:**
```yaml
primary_metrics:
  - name: conversion_rate
    formula: "conversions / unique_visitors"
    goal: increase
    
  - name: revenue_per_user
    formula: "total_revenue / unique_visitors"  
    goal: increase

secondary_metrics:
  - name: click_through_rate
    formula: "clicks / impressions"
    goal: increase
    
  - name: time_on_page
    formula: "avg(session_duration)"
    goal: increase

guardrail_metrics:
  - name: page_load_time
    threshold: 2000ms
    
  - name: error_rate
    threshold: 1%
    
  - name: bounce_rate
    threshold: +10%  # Don't allow >10% increase
```

**Statistical Analysis:**
```python
import scipy.stats as stats
import pandas as pd

def analyze_ab_test(control_data, treatment_data, metric_name):
    """
    Analyze A/B test results with statistical significance
    """
    control_mean = np.mean(control_data)
    treatment_mean = np.mean(treatment_data)
    
    # Two-sample t-test
    t_stat, p_value = stats.ttest_ind(control_data, treatment_data)
    
    # Effect size (Cohen's d)
    pooled_std = np.sqrt(
        ((len(control_data) - 1) * np.var(control_data, ddof=1) + 
         (len(treatment_data) - 1) * np.var(treatment_data, ddof=1)) /
        (len(control_data) + len(treatment_data) - 2)
    )
    cohens_d = (treatment_mean - control_mean) / pooled_std
    
    # Confidence interval
    se_diff = pooled_std * np.sqrt(1/len(control_data) + 1/len(treatment_data))
    ci_lower = (treatment_mean - control_mean) - 1.96 * se_diff
    ci_upper = (treatment_mean - control_mean) + 1.96 * se_diff
    
    return {
        'metric': metric_name,
        'control_mean': control_mean,
        'treatment_mean': treatment_mean,
        'relative_improvement': (treatment_mean / control_mean - 1) * 100,
        'p_value': p_value,
        'cohens_d': cohens_d,
        'confidence_interval': (ci_lower, ci_upper),
        'significant': p_value < 0.05,
        'sample_size_control': len(control_data),
        'sample_size_treatment': len(treatment_data)
    }

# Example usage
control_conversions = np.random.binomial(1, 0.15, 5000)  # 15% baseline
treatment_conversions = np.random.binomial(1, 0.17, 5000)  # 17% treatment

results = analyze_ab_test(control_conversions, treatment_conversions, 'conversion_rate')
print(f"Results: {results}")
```

## Advanced Testing Strategies

### 1. Sequential Testing

**Early Stopping Rules:**
```python
def sequential_analysis(control_data, treatment_data, alpha=0.05):
    """
    Implement sequential testing with early stopping
    """
    n_control = len(control_data)
    n_treatment = len(treatment_data)
    
    # Calculate current effect
    control_rate = np.mean(control_data)
    treatment_rate = np.mean(treatment_data)
    
    # Sequential boundary calculation
    information_fraction = min(n_control, n_treatment) / 10000  # Target sample size
    
    # O'Brien-Fleming boundary
    z_boundary = 2.797 / np.sqrt(information_fraction)
    
    # Current z-score
    pooled_rate = (sum(control_data) + sum(treatment_data)) / (n_control + n_treatment)
    se = np.sqrt(pooled_rate * (1 - pooled_rate) * (1/n_control + 1/n_treatment))
    z_score = abs(treatment_rate - control_rate) / se
    
    return {
        'should_stop': z_score > z_boundary,
        'z_score': z_score,
        'z_boundary': z_boundary,
        'information_fraction': information_fraction
    }
```

### 2. Multi-Armed Bandit

**Adaptive Traffic Allocation:**
```python
class EpsilonGreedyBandit:
    def __init__(self, n_arms, epsilon=0.1):
        self.n_arms = n_arms
        self.epsilon = epsilon
        self.counts = np.zeros(n_arms)
        self.values = np.zeros(n_arms)
    
    def select_arm(self):
        if np.random.random() < self.epsilon:
            return np.random.randint(self.n_arms)  # Explore
        else:
            return np.argmax(self.values)  # Exploit
    
    def update(self, arm, reward):
        self.counts[arm] += 1
        n = self.counts[arm]
        value = self.values[arm]
        self.values[arm] = ((n - 1) / n) * value + (1 / n) * reward

# Usage in traffic allocation
bandit = EpsilonGreedyBandit(n_arms=2)  # Control and treatment

# Update traffic allocation based on performance
for user_session in user_sessions:
    arm = bandit.select_arm()  # 0 = control, 1 = treatment
    variant = "control" if arm == 0 else "treatment"
    
    # Serve user the selected variant
    result = serve_variant(user_session, variant)
    
    # Update bandit with reward (conversion = 1, no conversion = 0)
    bandit.update(arm, result.converted)
```

### 3. Bayesian A/B Testing

**Bayesian Analysis Framework:**
```python
import pymc3 as pm
import numpy as np

def bayesian_ab_test(control_conversions, control_total, 
                    treatment_conversions, treatment_total):
    """
    Bayesian A/B test analysis
    """
    with pm.Model() as model:
        # Priors (Beta distribution for conversion rates)
        p_control = pm.Beta('p_control', alpha=1, beta=1)
        p_treatment = pm.Beta('p_treatment', alpha=1, beta=1)
        
        # Likelihoods
        control_obs = pm.Binomial('control_obs', n=control_total, p=p_control, 
                                observed=control_conversions)
        treatment_obs = pm.Binomial('treatment_obs', n=treatment_total, p=p_treatment,
                                  observed=treatment_conversions)
        
        # Derived quantity: probability treatment is better
        delta = pm.Deterministic('delta', p_treatment - p_control)
        
        # Sample from posterior
        trace = pm.sample(2000, tune=1000)
    
    # Calculate probability treatment is better
    prob_treatment_better = (trace['delta'] > 0).mean()
    
    return {
        'prob_treatment_better': prob_treatment_better,
        'control_posterior': trace['p_control'],
        'treatment_posterior': trace['p_treatment'],
        'effect_size_posterior': trace['delta']
    }
```

## Production Integration

### 1. CI/CD Pipeline Integration

**GitLab CI Example:**
```yaml
stages:
  - build
  - test
  - deploy-experiment
  - monitor
  - decide

deploy_ab_test:
  stage: deploy-experiment
  script:
    - kubectl apply -f k8s/ab-test-config.yaml
    - kubectl set image deployment/webapp-control webapp=$CI_REGISTRY_IMAGE:control-$CI_COMMIT_SHA
    - kubectl set image deployment/webapp-treatment webapp=$CI_REGISTRY_IMAGE:treatment-$CI_COMMIT_SHA
  environment:
    name: production-experiment
    url: https://myapp.com

monitor_experiment:
  stage: monitor
  script:
    - python scripts/monitor_experiment.py --experiment-id=$EXPERIMENT_ID --duration=7d
  artifacts:
    reports:
      junit: experiment-results.xml

decide_winner:
  stage: decide
  when: manual
  script:
    - python scripts/analyze_results.py --experiment-id=$EXPERIMENT_ID
    - python scripts/promote_winner.py --experiment-id=$EXPERIMENT_ID
```

### 2. Automated Decision Making

**Experiment Controller:**
```yaml
apiVersion: experiments.company.com/v1
kind: Experiment
metadata:
  name: checkout-optimization
spec:
  hypothesis: "Streamlined checkout flow increases conversion by 10%"
  
  variants:
    control:
      traffic_percentage: 50
      config:
        checkout_steps: 3
        button_color: "blue"
    treatment:
      traffic_percentage: 50
      config:
        checkout_steps: 2
        button_color: "green"
  
  success_criteria:
    primary_metric: conversion_rate
    minimum_improvement: 0.05
    significance_level: 0.05
    
  guardrails:
    - metric: error_rate
      threshold: 0.02
    - metric: page_load_time
      threshold: 2000
  
  auto_decision:
    enabled: true
    min_sample_size: 10000
    max_duration: 14d
```

### 3. Monitoring and Alerting

**Prometheus Alerts:**
```yaml
groups:
- name: ab-testing
  rules:
  - alert: ExperimentGuardrailViolation
    expr: |
      (
        sum(rate(http_requests_total{variant="treatment",code=~"5.*"}[5m])) /
        sum(rate(http_requests_total{variant="treatment"}[5m]))
      ) > 0.02
    for: 5m
    annotations:
      summary: "A/B test guardrail violated: high error rate in treatment"
      
  - alert: ExperimentStatisticalSignificance
    expr: |
      abs(
        (sum(rate(conversions_total{variant="treatment"}[24h])) / sum(rate(visitors_total{variant="treatment"}[24h]))) -
        (sum(rate(conversions_total{variant="control"}[24h])) / sum(rate(visitors_total{variant="control"}[24h])))
      ) > 0.05 and experiment_p_value < 0.05
    annotations:
      summary: "A/B test reached statistical significance"
```

**Grafana Dashboard:**
```json
{
  "dashboard": {
    "title": "A/B Test Dashboard",
    "panels": [
      {
        "title": "Conversion Rate by Variant",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate(conversions_total{variant=\"control\"}[1h])) / sum(rate(visitors_total{variant=\"control\"}[1h]))",
            "legendFormat": "Control"
          },
          {
            "expr": "sum(rate(conversions_total{variant=\"treatment\"}[1h])) / sum(rate(visitors_total{variant=\"treatment\"}[1h]))",
            "legendFormat": "Treatment"
          }
        ]
      },
      {
        "title": "Statistical Significance",
        "type": "stat",
        "targets": [
          {
            "expr": "experiment_p_value",
            "legendFormat": "P-Value"
          }
        ],
        "thresholds": [
          {"color": "red", "value": 0.05},
          {"color": "green", "value": 0}
        ]
      }
    ]
  }
}
```

## Best Practices

### 1. Experiment Design
- **Clear Hypothesis**: Always start with a specific, testable hypothesis
- **Single Variable**: Test one change at a time to isolate effects
- **Sufficient Sample Size**: Calculate required sample size before starting
- **Proper Randomization**: Ensure users are randomly assigned to variants

### 2. Implementation
- **Consistent Assignment**: Same users should always see the same variant
- **Exclusion Rules**: Exclude bots, internal traffic, and edge cases
- **Gradual Ramp**: Start with small traffic percentage and increase gradually
- **Isolation**: Prevent other changes from affecting experiment results

### 3. Analysis
- **Multiple Testing Correction**: Adjust for multiple comparisons when testing multiple metrics
- **Segmentation Analysis**: Analyze results across different user segments
- **Practical Significance**: Consider business impact, not just statistical significance
- **Confidence Intervals**: Report effect size with confidence intervals

### 4. Ethics and Privacy
- **User Consent**: Ensure compliance with privacy regulations
- **Transparent Communication**: Be open about testing when required
- **Fair Treatment**: Don't disadvantage any user group unfairly
- **Data Protection**: Secure and properly handle user data

## Troubleshooting

### Traffic Not Splitting Correctly
```bash
# Check service endpoints
kubectl get endpoints webapp-service -o yaml

# Verify variant labels
kubectl get pods -l app=webapp --show-labels

# Test traffic distribution
for i in {1..50}; do
  curl -s -H "X-User-ID: test$i" http://webapp-service | grep variant
done | sort | uniq -c
```

### Inconsistent User Assignment
```bash
# Test same user gets consistent variant
for i in {1..10}; do
  curl -s -H "X-User-ID: consistent-user" http://webapp-service | grep variant
done | sort | uniq
```

### Statistical Analysis Issues
```python
# Check for sample size imbalance
control_size = len(control_data)
treatment_size = len(treatment_data)
imbalance_ratio = max(control_size, treatment_size) / min(control_size, treatment_size)

if imbalance_ratio > 1.2:
    print(f"Warning: Sample size imbalance {imbalance_ratio:.2f}")

# Check for time-based bias
daily_results = group_by_day(experiment_data)
for day, data in daily_results.items():
    print(f"Day {day}: Control={data.control_rate:.3f}, Treatment={data.treatment_rate:.3f}")
```

## Files in This Section

- **`01-basic-ab-testing.yaml`**: Simple A/B testing with pod-based traffic splitting
- **`02-advanced-ab-testing-istio.yaml`**: Advanced A/B testing using Istio service mesh
- **`SIMPLE-AB-TESTING.yaml`**: Quick-start template for immediate use

## Next Steps

1. **Basic Setup**: Start with simple pod-based A/B testing
2. **Metrics Integration**: Implement comprehensive tracking and analytics
3. **Service Mesh**: Upgrade to Istio for advanced traffic control
4. **Automation**: Build automated experiment management and decision making
5. **Advanced Methods**: Explore Bayesian testing and multi-armed bandits