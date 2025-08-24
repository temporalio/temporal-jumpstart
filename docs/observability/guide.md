# Temporal Cloud: Observability

## Monitoring, Alerting, and Health

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Getting Started With Temporal Cloud Observability](#getting-started-with-temporal-cloud-observability)
- [Detecting Task Backlog](#detecting-task-backlog)
- [Detecting Greedy Worker Resources](#detecting-greedy-worker-resources)
- [Detecting Misconfigured Workers](#detecting-misconfigured-workers)
- [Detecting Availability Problems](#detecting-availability-problems)
- [Detecting Failures](#detecting-failures)
- [Workflow and Activity Metrics](#workflow-metrics)
- [Search Attributes and Stuck Workflows](#search-attributes)
- [References](#references)

---

# Overview

This document aims to address specific topics to answer questions like:

* Reference: What metrics should I use?
* Target: What are target values I should look for when observing these metrics?
* Interpret: How should I interpret the values of these metrics?
* Act: What are appropriate actions I should take when the targets are not being met?

Additionally, sample Prometheus and DataDog queries will be provided to help you kickstart your own dashboards. This guide will usually reference metric *full* names that include the *units* (where applicable) for clarity. When referencing Temporal documentation, you might find these metric names are shortened and do not include the units. See [this document](https://prometheus.io/docs/practices/naming/#metric-names) for more details about metric names.

Recall that your application long polls Temporal Cloud servers. Assessing the health of your application is achieved by the proper interpretation of the health of your *worker fleet* (1 or more workers) and its relationship with the related Temporal *Task Queue(s)*. These are tightly coupled so identifying their behavior is vital for operating a performant Temporal application. *If the diagnosis is incorrect, the prognosis will likely be incorrect as well.*

Temporal Cloud is consistently shown to be available and performant at extreme scale. Hence, we have found that customer application health is impacted primarily by:

* Misconfigured workers
* Under-resourced workers
* Under-provisioned (count) workers
* Some combination of the above

## Prerequisites

1. [Configure SDK Metrics In Your Worker](https://docs.temporal.io/references/sdk-metrics)
2. [Set up observability platform integration](https://docs.temporal.io/cloud/metrics/). 
3. Depending on your integration, you probably need to perform these tasks:
   1. Grafana users: Some of the sample queries are percentages. To configure your Dashboard units for these values, see [here](https://grafana.com/docs/grafana/latest/panels-visualizations/configure-standard-options/#unit).
   2. DataDog users: Enable percentiles by following instructions [here](https://docs.datadoghq.com/metrics/distributions/).
5. *This guide assumes you are already monitoring your worker host resource utilization (CPU, memory, etc).*

## Getting Started With Temporal Cloud Observability

### Minimal Observation

These metrics and alerts should be configured and understood first to gain intelligence into your application health and behaviors.

1. Create monitors and alerts for `schedule_to_start_latency` SDK metrics (both [workflows](https://docs.temporal.io/references/sdk-metrics#workflow_task_schedule_to_start_latency) and [activities](https://docs.temporal.io/references/sdk-metrics#activity_schedule_to_start_latency) variants). Here are [sample queries](#prometheus-query-samples).
   1. Alert at >`1000ms` for your **p99** value
   2. Plot >`200ms` for your **p95** value
   3. See [detecting task backlog](#detecting-task-backlog) to learn appropriate responses that accompany these values.

   **DataDog Alert Setup:**
   - Navigate to **Monitors** → **New Monitor** → **Metric**
   - Set **Define the metric**: `p99:temporal_workflow_task_schedule_to_start_latency{namespace:your_namespace}`
   - Set **Set alert conditions**: `above` threshold of `1000` (milliseconds)
   - Configure **Say what's happening**: "Workflow task schedule-to-start latency is high"

2. Create a Grafana panel called `Sync Match Rate` using [this query](#sync-match-rate-query)
   1. Alert at `<95%` for your **p99** value
   2. Plot `<99%` for your **p95** value
   3. See [not enough or under-powered resources](#not-enough-or-under-powered-resources) to learn appropriate responses that accompany these values.

   **DataDog Alert Setup:**
   - Navigate to **Monitors** → **New Monitor** → **Metric**
   - Set **Define the metric**: Use the sync match rate formula from [sync match rate](#sync-match-rate)
   - Set **Set alert conditions**: `below` threshold of `0.95` (95%)
   - Configure **Say what's happening**: "Sync match rate is below acceptable threshold"

3. Create a Grafana panel called `Poll Success Rate` using [this query](#poll-success-rate-query)
   1. Alert at `<90%` for your **p99** value
   2. Plot `<95%` for your **p95** value
   3. See [too many workers](#too-many-workers) to learn appropriate responses that accompany these values.

   **DataDog Alert Setup:**
   - Navigate to **Monitors** → **New Monitor** → **Metric**
   - Set **Define the metric**: Use the poll success rate formula from [poll success rate query](#poll-success-rate-query)
   - Set **Set alert conditions**: `below` threshold of `0.90` (90%)
   - Configure **Say what's happening**: "Poll success rate indicates potential worker over-provisioning"

4. Create monitors and alerts using `temporal_cloud_v0_service_latency_bucket` [Cloud Metric](https://docs.temporal.io/cloud/how-to-monitor-temporal-cloud-metrics#available-performance-metrics) .
   1. Alert the rate of errors at `<99.9%`
   2. See [detecting availability problems](#detecting-availability-problems) for formulas to calculate this rate and to understand availability.

   **DataDog Alert Setup:**
   - Navigate to **Monitors** → **New Monitor** → **Metric**
   - Set **Define the metric**: `avg:temporal.cloud.v0_service_latency_p99{$Namespace} by {operation}`
   - Set **Set alert conditions**: `above` threshold appropriate for your SLA
   - Configure **Say what's happening**: "Temporal Cloud service latency is elevated"

5. Create monitors and alerts using `temporal_cloud_v0_frontend_service_error_count` [Cloud Metric](https://docs.temporal.io/cloud/how-to-monitor-temporal-cloud-metrics#available-performance-metrics) .
   1. Alert the rate of errors at `<99.9%`
   2. See [detecting temporal cloud errors](#detecting-temporal-cloud-errors) for formulas to calculate this rate and to understand error count.

   **DataDog Alert Setup:**
   - Navigate to **Monitors** → **New Monitor** → **Metric**
   - Set **Define the metric**: `sum:temporal.cloud.v0_frontend_service_error{$Namespace}.as_rate()`
   - Set **Set alert conditions**: `above` threshold of `0.001` (0.1% error rate)
   - Configure **Say what's happening**: "Temporal Cloud frontend service errors detected"

6. Create monitors and alerts using `request_failure`  [SDK metric](https://docs.temporal.io/references/sdk-metrics#request).
   1. Alert the rate of errors at `<99.9%`
   2. See [detecting temporal request failures](#detecting-temporal-request-failures) for formulas to calculate this rate and to understand error count.

   **DataDog Alert Setup:**
   - Navigate to **Monitors** → **New Monitor** → **Metric**
   - Set **Define the metric**: Use the request failure rate formula from [detecting temporal request failures](#detecting-temporal-request-failures)
   - Set **Set alert conditions**: `below` threshold of `0.999` (99.9% success rate)
   - Configure **Say what's happening**: "SDK request failure rate is elevated"

### Deeper Observation

These metrics and alerts build on the [minimal observation](#minimal-observation) to dive deeper into specific potential causes for unfavorable conditions you might be experiencing.

7. Create monitors and alerts for `temporal_worker_task_slots_available` [SDK metric](https://docs.temporal.io/references/sdk-metrics#worker_task_slots_available)
   1. Alert at `0` for your **p99** value
   2. See [execution size configuration](#execution-size-configuration) for the responses you might choose based on this metric.

   **DataDog Alert Setup:**
   - Navigate to **Monitors** → **New Monitor** → **Metric**
   - Set **Define the metric**: `temporal_worker_task_slots_available{namespace:your_namespace,worker_type:workflowworker}`
   - Set **Set alert conditions**: `below or equal to` threshold of `0`
   - Configure **Say what's happening**: "Worker task slots are exhausted"

8. Create monitors for `temporal_sticky_cache_size` [SDK metric](https://docs.temporal.io/references/sdk-metrics#sticky_cache_size).
   1. Plot at **`{value} > {WorkflowCacheSize.Value}`**
   2. See [sticky cache configuration](#sticky-cache-configuration) for more details on this configuration.

   **DataDog Alert Setup:**
   - Navigate to **Monitors** → **New Monitor** → **Metric**
   - Set **Define the metric**: `max:temporal_sticky_cache_size{namespace:your_namespace}`
   - Set **Set alert conditions**: `above` threshold of your configured WorkflowCacheSize value
   - Configure **Say what's happening**: "Sticky cache size exceeds configured limit"

9. Create monitors for `temporal_sticky_cache_total_forced_eviction` [SDK metric](https://docs.temporal.io/references/sdk-metrics#sticky_cache_total_forced_eviction).
   1. *Java SDK only*
   2. Alert at **`>{predetermined_high_number}`**
   3. See [sticky cache configuration](#sticky-cache-configuration) for details and appropriate responses.

   **DataDog Alert Setup (Java SDK only):**
   - Navigate to **Monitors** → **New Monitor** → **Metric**
   - Set **Define the metric**: `sum:temporal_sticky_cache_total_forced_eviction.count{namespace:your_namespace}.as_rate()`
   - Set **Set alert conditions**: `above` threshold based on your baseline
   - Configure **Say what's happening**: "High sticky cache eviction rate detected"

## Detecting Task Backlog

### Reference Metrics

* `[sdk metric] workflow_schedule_to_start_latency`
* `[sdk metric] activity_schedule_to_start_latency`
* `[cloud metric] temporal_cloud_v0_poll_success_count`
* `[cloud metric] temporal_cloud_v0_poll_success_sync_count`

### Symptoms

* If your [schedule to start latency](#schedule-to-start-latency) alert fires or appears high, cross-check this with the [sync match rate](#sync-match-rate) to determine if [you need to change your worker or fleet](#not-enough-or-under-powered-resources), or [if you need to contact Temporal Cloud support](#temporal-cloud-bottleneck).
* If your [sync match rate](#sync-match-rate) is low, you [can contact Temporal Cloud support](#temporal-cloud-bottleneck).

### Schedule To Start Latency

The Schedule-To-Start metric represents how long Tasks are staying, unprocessed, in the Task Queues. Put differently, it is the time between when a Task is enqueued and when it is picked up by a Worker. This time being long (likely) means that your Workers can't keep up — either increase the number of workers (if the host load is already high) or increase the number of pollers per worker  
The `schedule_to_start_latency` SDK metric for both [workflows](https://docs.temporal.io/references/sdk-metrics#workflow_task_schedule_to_start_latency) and [activities](https://docs.temporal.io/references/sdk-metrics#activity_schedule_to_start_latency) should have alerts.

#### Prometheus Query Samples

*Workflow Task Latency, 99th percentile*

**Prometheus:**
```
histogram_quantile(0.99, sum(rate(temporal_workflow_task_schedule_to_start_latency_seconds_bucket[5m])) by (le, namespace, task_queue))
```

**DataDog:**
```
p99:temporal_workflow_task_schedule_to_start_latency{namespace:$namespace} by {namespace,task_queue}
```

*Workflow Task Latency, average*

**Prometheus:**
```
sum(increase(temporal_workflow_task_schedule_to_start_latency_seconds_sum[5m])) by (namespace, task_queue)/sum(increase(temporal_workflow_task_schedule_to_start_latency_seconds_count[5m])) by (namespace, task_queue)
```

**DataDog:**
```
avg:temporal_workflow_task_schedule_to_start_latency.sum{namespace:$namespace} by {namespace,task_queue} / avg:temporal_workflow_task_schedule_to_start_latency.count{namespace:$namespace} by {namespace,task_queue}
```

*Activity Task Latency, 99th percentile*

**Prometheus:**
```
histogram_quantile(0.99, sum(rate(temporal_activity_schedule_to_start_latency_seconds_bucket[5m])) by (le, namespace, task_queue))
```

**DataDog:**
```
p99:temporal_activity_schedule_to_start_latency{namespace:$namespace} by {namespace,task_queue}
```

*Activity Task Latency, average*

**Prometheus:**
```
sum(increase(temporal_activity_schedule_to_start_latency_seconds_sum[5m])) by (namespace, task_queue)/sum(increase(temporal_activity_schedule_to_start_latency_seconds_count[5m])) by (namespace, task_queue)
```

**DataDog:**
```
avg:temporal_activity_schedule_to_start_latency.sum{namespace:$namespace} by {namespace,task_queue} / avg:temporal_activity_schedule_to_start_latency.count{namespace:$namespace} by {namespace,task_queue}
```

#### Target

This latency should obviously be a very low value - close to zero. Anything else, indicates bottlenecking.

### Sync Match Rate

The `sync match rate` measures the rate of tasks that can be delivered to workers without having to be persisted (workers are up and available to pick them up) to the rate of all delivered tasks.

#### Calculate Sync Match Rate

`temporal_cloud_v0_poll_success_sync_count` / `temporal_cloud_v0_poll_success_count` = N%

#### Sync Match Rate Query

*sync_match_rate query*

**Prometheus:**
```
sum by(temporal_namespace) (
  rate(
    temporal_cloud_v0_poll_success_sync_count{temporal_namespace=~"$namespace"}[5m]
  )
)/
sum by(temporal_namespace) (
  rate(
    temporal_cloud_v0_poll_success_count{temporal_namespace=~"$namespace"}[5m]
  )
)
```

**DataDog:**
```
sum:temporal.cloud.v0_poll_success_sync{$Namespace} by {temporal_namespace}.as_rate() / sum:temporal.cloud.v0_poll_success{$Namespace} by {temporal_namespace}.as_rate()
```

#### Target

The `sync match rate` should be *at least* **`>95%,`** but preferably **`>99%.`**

### Interpretation

#### Not enough or under-powered resources

If the `ScheduleToStart` latency is *high* and the `Sync Match Rate` is *high*, the TaskQueue is experiencing a backlog of tasks.   
There are three typical causes for this:

1. There are not enough workers to perform work
2. Each worker is either under resourced, or is misconfigured, to handle enough work
3. There is congestion caused by the environment (eg., network) hosting the worker(s) and Temporal Cloud.

##### Actions

Consider

* Increasing either the number of available workers, OR
* Verifying that your worker hosts are appropriately resourced, OR
* Increasing the worker configuration value for concurrent pollers for workers/task executions (if your worker resources can accommodate the increased load), OR
   * TypeScript: [workflows](https://typescript.temporal.io/api/interfaces/worker.WorkerOptions#maxconcurrentworkflowtaskexecutions)
   * Golang: [workflows](https://docs.temporal.io/go/how-to-set-workeroptions-in-go#maxconcurrentworkflowtaskpollers)
* Doing some combination of these

#### Temporal Cloud bottleneck

If the `ScheduleToStart` latency is *high* and the `Sync Match Rate` is *also low*, Temporal Cloud could very well be the bottleneck and you should reach out via support channels for us to confirm.

### Caveat

If you are setting the **ScheduleToStartTimeout** value in your [Activity Options](https://docs.temporal.io/go/how-to-set-a-schedule-to-start-timeout-in-go), it will skew your observations if you are not following the guidance [here](https://docs.temporal.io/concepts/what-is-a-schedule-to-start-timeout). As such, we recommend that you avoid setting this value.

## Detecting Greedy Worker Resources

As mentioned [here](https://docs.temporal.io/dev-guide/worker-performance#hosts-and-resources-provisioning), you can have *too many* workers.  
If you see the [Poll Success Rate](#calculate-poll-success-rate) showing low numbers, [you might have too many resources polling Temporal Cloud](#too-many-workers).

### Reference Metrics

* `[cloud metric] temporal_cloud_v0_poll_success_count`
* `[cloud metric] temporal_cloud_v0_poll_success_sync_count`
* `[cloud metric] temporal_cloud_v0_poll_timeout_count`
* `[sdk metric] temporal_workflow_schedule_to_start_latency`
* `[sdk metric] temporal_activity_schedule_to_start_latency`

### Calculate Poll Success Rate

`(temporal_cloud_v0_poll_success_count + temporal_cloud_v0_poll_success_sync_count)(temporal_cloud_v0_poll_success_count + temporal_cloud_v0_poll_success_sync_count + temporal_cloud_v0_poll_timeout_count)`

### Target

`Poll Success Rate` should be **`>90%`** in most cases of systems with a steady load.   
For high volume and low latency, try to target **`>95%`**.

### Interpretation

#### Too Many Workers

If you see *at the same time:*

* Low `Poll Success Rate`*,  AND*
* Low `schedule_to_start_latency`, AND
* Low worker hosts resource utilization

***then you might have too many workers.***

#### Actions

Consider sizing down your workers by either:

* Reducing the number of workers polling the impacted Task Queue, OR
* Reducing the concurrent pollers per worker, OR
* Both

#### Poll Success Rate Query

*poll_success_rate query*

**Prometheus:**
```
(
  (
    sum by(temporal_namespace) (
      rate(
        temporal_cloud_v0_poll_success_count{temporal_namespace=~"$namespace"}[5m]
      )
    )
  +
    sum by(temporal_namespace) (
      rate(
        temporal_cloud_v0_poll_success_sync_count{temporal_namespace=~"$namespace"}[5m]
      )
    )
  )
/
  (
    (
        sum by(temporal_namespace) (
          rate(
            temporal_cloud_v0_poll_success_count{temporal_namespace=~"$namespace"}[5m]
          )
        )
      +
        sum by(temporal_namespace) (
          rate(
            temporal_cloud_v0_poll_success_sync_count{temporal_namespace=~"$namespace"}[5m]
          )
        )
    )
  +
    sum by(temporal_namespace) (
      rate(
        temporal_cloud_v0_poll_timeout_count{temporal_namespace=~"$namespace"}[5m]
      )
    )
))
```

**DataDog:**
```
(sum:temporal.cloud.v0_poll_success{$Namespace} by {temporal_namespace}.as_rate() + sum:temporal.cloud.v0_poll_success_sync{$Namespace} by {temporal_namespace}.as_rate()) / (sum:temporal.cloud.v0_poll_success{$Namespace} by {temporal_namespace}.as_rate() + sum:temporal.cloud.v0_poll_success_sync{$Namespace} by {temporal_namespace}.as_rate() + sum:temporal.cloud.v0_poll_timeout{$Namespace} by {temporal_namespace}.as_rate())
```

## Detecting Misconfigured Workers

The configuration of your workers can negatively affect the efficiency of your task processing as well.   
Please review [this document](https://docs.temporal.io/dev-guide/worker-performance#configuration).

### Reference Metrics

* `[sdk metric] temporal_worker_task_slots_available`
* `[sdk metric] sticky_cache_size`
* `[sdk metric] sticky_cache_total_forced_eviction`

### Execution Size Configuration

The [maxConcurrentWorkflowTaskExecutionSize](https://docs.temporal.io/go/how-to-set-workeroptions-in-go#maxconcurrentworkflowtaskexecutionsize) and [maxConcurrentActivityExecutionSize](https://docs.temporal.io/go/how-to-set-workeroptions-in-go#maxconcurrentactivityexecutionsize) define the number of total available slots for the worker. If this is set too low, the worker would not be able to keep up processing tasks.

#### Target

The `temporal_worker_task_slots_available` metric should always be `>0`.

#### Prometheus Samples

*Over Time*

**Prometheus:**
```
avg_over_time(temporal_worker_task_slots_available{namespace="$namespace",worker_type="WorkflowWorker"}[10m])
```

**DataDog:**
```
avg:temporal_worker_task_slots_available{namespace:$namespace,worker_type:workflowworker}.rollup(avg, 600)
```

*Current Time*

**Prometheus:**
```
temporal_worker_task_slots_available{namespace="default", worker_type="WorkflowWorker", task_queue="$task_queue_name"}
```

**DataDog:**
```
temporal_worker_task_slots_available{namespace:default,worker_type:workflowworker,task_queue:$task_queue_name}
```

#### Interpretation

You are likely experiencing a task [backlog](#detecting-task-backlog) if you are seeing inadequate slot counts frequently.   
The work is not getting processed as fast as it should/can.

#### Action

Increase the [maxConcurrentWorkflowTaskExecutionSize](https://docs.temporal.io/go/how-to-set-workeroptions-in-go#maxconcurrentworkflowtaskexecutionsize) and [maxConcurrentActivityExecutionSize](https://docs.temporal.io/go/how-to-set-workeroptions-in-go#maxconcurrentactivityexecutionsize) values and keep an eye on your worker resource metrics (CPU utilization, etc) to make sure you haven't created a new issue.

### Sticky Cache Configuration

The [WorkflowCacheSize](https://www.javadoc.io/static/io.temporal/temporal-sdk/1.0.0/io/temporal/worker/WorkerFactoryOptions.Builder.html#setWorkflowCacheSize-int-) should always be greater than the **`sticky_cache_size`** metric value.   
Additionally, you can watch **`sticky_cache_total_forced_eviction`** for unusually high numbers that are likely an indicator of inefficiency, since workflows are being evicted from the cache.

#### Target

The **`sticky_cache_size`** should report less than or equal to your WorkflowCacheSize value.  
Also, **`sticky_cache_total_forced_eviction`** should not be reporting high numbers (relative).

#### Action

* If you see a high eviction count, verify there are no other inefficiencies in your worker configuration or resource provisioning ([backlog](#detecting-task-backlog)).
* If you see the cache size metric exceed the WorkflowCacheSize, increase this value if your worker resources can accommodate it or provision more workers.
* Finally, take time to review [this document](https://docs.temporal.io/dev-guide/worker-performance#configuration) and see if [this document](https://docs.temporal.io/dev-guide/worker-performance#workflow-cache-tuning) further addresses potential cache issues.

#### Prometheus Sample

*Sticky Cache Size*

**Prometheus:**
```
max_over_time(temporal_sticky_cache_size{namespace="$namespace"}[10m])
```

**DataDog:**
```
max:temporal_sticky_cache_size{namespace:$namespace}.rollup(max, 600)
```

*Sticky Cache Evictions*

**Prometheus:**
```
rate(temporal_sticky_cache_total_forced_eviction_total{namespace="$namespace"}[5m])
```

**DataDog:**
```
sum:temporal_sticky_cache_total_forced_eviction.count{namespace:$namespace}.as_rate()
```

## Detecting Availability Problems

If you see a sudden drop in worker resource utilization, you might want to verify Temporal Cloud's API is not showing increased latencies.

### Reference Metrics

* `[cloud metric] temporal_cloud_v0_service_latency_bucket`

#### Prometheus Query

**Prometheus:**
```
histogram_quantile(0.99, sum(rate(temporal_cloud_v0_service_latency_bucket[5m])) by (temporal_namespace, operation, le))
```

**DataDog:**
```
avg:temporal.cloud.v0_service_latency_p99{$Namespace} by {operation}
```

## Detecting Failures

### Detecting Temporal Cloud Errors

Detects Temporal Cloud front-end service API errors. Note: This is not equal to the Temporal Cloud SLA.

#### Reference Metrics

* `[cloud metric] temporal_cloud_v0_frontend_service_error_count`

#### Prometheus Query: Daily Average 10 Minute Window Errors

**Prometheus:**
```
avg_over_time((
  (
    (
        sum(increase(temporal_cloud_v0_frontend_service_request_count{temporal_namespace=~"$namespace", operation=~"StartWorkflowExecution|SignalWorkflowExecution|SignalWithStartWorkflowExecution|RequestCancelWorkflowExecution|TerminateWorkflowExecution"}[10m]))
        -
        sum(increase(temporal_cloud_v0_frontend_service_error_count{temporal_namespace=~"$namespace", operation=~"StartWorkflowExecution|SignalWorkflowExecution|SignalWithStartWorkflowExecution|RequestCancelWorkflowExecution|TerminateWorkflowExecution"}[10m]))
    )
  /
     sum(increase(temporal_cloud_v0_frontend_service_request_count{temporal_namespace=~"$namespace", operation=~"StartWorkflowExecution|SignalWorkflowExecution|SignalWithStartWorkflowExecution|RequestCancelWorkflowExecution|TerminateWorkflowExecution"}[10m]))
  )
  or vector(1)
)[1d:10m])
```

**DataDog:**
```
(sum:temporal.cloud.v0_frontend_service_request{$Namespace,operation:startworkflowexecution OR operation:signalworkflowexecution OR operation:signalwithstartworkflowexecution OR operation:requestcancelworkflowexecution OR operation:terminateworkflowexecution}.as_count() - sum:temporal.cloud.v0_frontend_service_error{$Namespace,operation:startworkflowexecution OR operation:signalworkflowexecution OR operation:signalwithstartworkflowexecution OR operation:requestcancelworkflowexecution OR operation:terminateworkflowexecution}.as_count()) / sum:temporal.cloud.v0_frontend_service_request{$Namespace,operation:startworkflowexecution OR operation:signalworkflowexecution OR operation:signalwithstartworkflowexecution OR operation:requestcancelworkflowexecution OR operation:terminateworkflowexecution}.as_count()
```

### Detecting Temporal Request Failures

Percentage of Temporal Client RPC requests that failed.

#### Reference Metrics

* `[SDK metric] request_failure`

#### Prometheus Query: Daily Average 5 Minute Window Errors

**Prometheus:**
```
(
  sum(rate(request_total{namespace=~"$namespace"}[5m]))
  -
  sum(rate(request_failure{namespace=~"$namespace"}[5m]))
) / sum(rate(request{namespace=~"$namespace"}[5m]))
```

**DataDog:**
```
(sum:temporal_request.count{namespace:$namespace}.as_rate() - sum:temporal_request_failure{namespace:$namespace}.as_rate()) / sum:temporal_request.count{namespace:$namespace}.as_rate()
```

### Detecting Activity and Workflow Failures

The metrics `temporal_activity_execution_failed` and `temporal_cloud_v0_workflow_failed_count` together provide failure detection for Temporal applications. These metrics work in tandem to give you both granular component-level visibility and high-level workflow health insights.  
If not using infinite retry policies, Activity failures can lead to Workflow failures:

#### Failure Cascade

```
Activity Failure → Retry Logic → More Activity Failures → Workflow Decision → Potential Workflow Failure
```

* **Activity failures** are often recoverable and expected
* **Workflow failures** represent terminal states requiring immediate attention
* A spike in activity failures may precede workflow failures

Generally Temporal recommends that Workflows should be designed to always succeed. If an Activity fails more than its retry policy allows, we suggest having the Workflow handle Activity failure and take action to notify a human to take corrective action or be aware of the error.

#### Ratio-Based Monitoring

##### Failure Conversion Rate

Monitor the ratio of workflow failures to activity failures:

```
workflow_failure_rate = temporal_cloud_v0_workflow_failed_count / temporal_activity_execution_failed
```

What to watch for:

* **High ratio (>0.1)**: Poor error handling - activities failing are causing workflow failures
* **Low ratio (<0.01)**: Good resilience - activities fail but workflows recover
* **Sudden spikes**: Indicates systematic issues

##### Activity Success Rate

```
activity_success_rate = (total_activities - temporal_activity_execution_failed) / total_activities
```

Target: >95% for most applications. Lower success rate can be a sign of system troubles.

See also:

- [Temporal Error Handling Strategies](https://learn.temporal.io/courses/errstrat/)
- [https://docs.temporal.io/references/failures](https://docs.temporal.io/references/failures)
- [https://docs.temporal.io/encyclopedia/detecting-workflow-failures](https://docs.temporal.io/encyclopedia/detecting-workflow-failures)

### High Activity Failure Count Monitoring

If you set an Activity retry policy that allows for many retries, it may be helpful to Activities can detect their own retry counts and take action based on them:  
first, setting a custom metric:

**Java:**
```java
if(Activity.getExecutionContext().getInfo().getAttempt() > 5) {
  Activity.getExecutionContext().getMetricsScope().counter("HighActivityErrorCount").inc(1);
}
```

**.NET:**
```csharp
if(ActivityExecutionContext.Current.Info.Attempt > 5) {
  ActivityExecutionContext.Current.MetricMeter.CreateCounter<int>("HighActivityErrorCount").Add(1);
}
```

Then you can monitor for activities with high error counts and check logs to find Workflows that are waiting on their Activities to succeed.

Activities can also delay the next retry:

**Java:**
```java
if(Activity.getExecutionContext().getInfo().getAttempt() > 10) {
  Activity.getExecutionContext().getMetricsScope().counter("VeryHighActivityErrorCount").inc(1);
  PageARealPerson();

  // delay next retry
  throw ApplicationFailure.newFailureWithCauseAndDelay(
    e.getMessage(),
    e.getClass().getName(),
    e,
    // set larger retry interval thats longer than what would be in your retry policy to slow down retries
    Duration.ofHours(2)); // just for sample 2hrs
}  else {
   throw e; // use configured retry policy
}
```

**.NET:**
```csharp
if(ActivityExecutionContext.Current.Info.Attempt > 10) {
  ActivityExecutionContext.Current.MetricMeter.CreateCounter<int>("VeryHighActivityErrorCount").Add(1);
  PageARealPerson();

  // delay next retry
  throw new ApplicationFailureException(
    e.Message,
    e.GetType().Name,
    e,
    // set larger retry interval thats longer than what would be in your retry policy to slow down retries  
    TimeSpan.FromHours(2)); // just for sample 2hrs
}  else {
   throw e; // use configured retry policy  
}
```

### Detecting Non-Determinism Errors (NDEs)

Non-deterministic errors (NDEs) in Temporal are critical issues that need immediate attention since they can corrupt workflow state. Here are several strategies to detect and alert for them:

#### Detection

##### Monitor the temporal_workflow_task_execution_failed_total Metric by error_type NonDeterminismError

**Prometheus:**
```
increase(temporal_workflow_task_execution_failed_total{error_type="NonDeterminismError"}[5m]) > 0
```

**DataDog:**
```
sum:temporal_workflow_task_execution_failed.count{error_type:nondeterminismerror}.as_count()
```

**DataDog Alert Setup:**
- Navigate to **Monitors** → **New Monitor** → **Metric**
- Set **Define the metric**: `sum:temporal_workflow_task_execution_failed.count{error_type:nondeterminismerror}.as_count()`
- Set **Set alert conditions**: `above` threshold of `0`
- Configure **Say what's happening**: "Non-determinism error detected in Temporal workflow"
- Set **Priority**: `P1` (Critical)

##### Grafana Alert Rule

```
- alert: TemporalNonDeterminismError
  expr: increase(temporal_workflow_task_execution_failed_total{error_type="NonDeterminismError"}[5m]) > 0
  for: 0m
  labels:
    severity: critical
    component: temporal
  annotations:
    summary: "Non-determinism error detected in Temporal workflow"
    description: "Workflow task execution failed due to non-determinism in namespace {{ $labels.namespace }}, task queue {{ $labels.task_queue }}"
```

### Diving Deeper: Log Detection

NDEs errors should log out with TMPRL1100  ([ref](https://github.com/temporalio/rules/blob/main/rules/TMPRL1100.md)) - and include the workflow IDs:

```
java.lang.RuntimeException: Failure processing workflow task. WorkflowId=HelloActivityWorkflow, RunId=28aae576-7dca-45a9-85e1-20ae6590b9b9, Attempt=2
<snip>
Caused by: io.temporal.worker.NonDeterministicException: [TMPRL1100] Failure handling event 11 of type 'EVENT_TYPE_TIMER_STARTED' during replay. [TMPRL1100] Event 11 of type EVENT_TYPE_TIMER_STARTED does not match command type COMMAND_TYPE_COMPLETE_WORKFLOW_EXECUTION. {WorkflowTaskStartedEventId=17, CurrentStartedEventId=9}
	at io.temporal.internal.statemachines.WorkflowStateMachines.handleCommandEvent(WorkflowStateMachines.java:559)
```

Use metrics + alerts to detect the errors, then find specific workflows in the logs (or in the UI).

### Detecting Network Latency

In addition to the cloud metric temporal_cloud_v0_service_latency_bucket mentioned above, SDK metrics [request_latency](https://docs.temporal.io/references/sdk-metrics#request_latency) and [long_request_latency](https://docs.temporal.io/references/sdk-metrics#long_request_latency) can be used to monitor service latency.

request_latency - request latency for requests (e.g. RespondWorkflowTaskCompleted, RespondActivityTaskCompleted):

**Prometheus:**
```
# P95 request latency
histogram_quantile(0.95, rate(request_latency_bucket[5m]))
```

**DataDog:**
```
p95:temporal_request_latency{namespace:$namespace}
```

long_request_latency - Specifically for long-polling requests (e.g. PollWorkflowTaskQueue, PollActivityTaskQueue, GetWorkflowExecutionHistory):

**Prometheus:**
```
# Track long request patterns
histogram_quantile(0.99, rate(long_request_latency_bucket[5m]))
```

**DataDog:**
```
p99:temporal_long_request_latency{namespace:$namespace}
```

High latency here usually represents a network problem.

**DataDog Alert Setup for Network Latency:**
- Navigate to **Monitors** → **New Monitor** → **Metric**
- Set **Define the metric**: `p95:temporal_request_latency{namespace:your_namespace}`
- Set **Set alert conditions**: `above` threshold appropriate for your network SLA
- Configure **Say what's happening**: "High network latency detected between SDK and Temporal Cloud"

### Usage and Detecting Resource Exhaustion & Namespace RPS and APS Rate Limits

The Cloud metric temporal_cloud_v0_resource_exhausted_error_count is the primary indicator for Cloud-side throttling, signaling that [namespace limits](https://docs.temporal.io/cloud/namespaces#constraints-and-limitations) are being hit and ResourceExhausted gRPC errors are occurring. This generally does not break workflow processing due to how resources are prioritized. In fact, some workloads often run with high amounts of resource exhaustion errors because they are not latency sensitive. Being APS or RPS resource constrained can slow down throughput and is a good indicator that you should request additional capacity.

To specifically identify whether RPS or APS limits are being hit, this metric can be filtered using the resource_exhausted_cause label, which will show values like ApsLimit or RpsLimit. This label also helps identify the specific operation that was throttled (e.g., polling, respond activity tasks).

**DataDog Alert Setup for Resource Exhaustion:**
- Navigate to **Monitors** → **New Monitor** → **Metric**
- Set **Define the metric**: `sum:temporal.cloud.v0_resource_exhausted_error{$Namespace} by {resource_exhausted_cause}.as_rate()`
- Set **Set alert conditions**: `above` threshold based on your tolerance for throttling
- Configure **Say what's happening**: "Temporal Cloud namespace limits being hit: {{resource_exhausted_cause.name}}"

Related useful information:

- Namespace Limits (APS is visible in the Namespace UI)
- temporal_cloud_v0_total_action_count: Useful for tracking the overall action rate (APS).
- temporal_cloud_v0_frontend_service_request_count: Useful for tracking the request rate (RPS)
- SDK metric long_request_failure with cause resource_exhausted

## Workflow and Activity Metrics

Temporal Cloud provides six workflow metrics that track different workflow execution outcomes ([ref](https://docs.temporal.io/production-deployment/cloud/metrics/reference#workflow)):

### Workflow Metrics:

1. `temporal_cloud_v0_workflow_success_count` - Workflows that successfully completed
2. `temporal_cloud_v0_workflow_failed_count` - Workflows that failed before completion
3. `temporal_cloud_v0_workflow_cancel_count` - Workflows canceled before completing
4. `temporal_cloud_v0_workflow_terminate_count` - Workflows terminated before completing execution
5. `temporal_cloud_v0_workflow_timeout_count` - Workflows that timed out before completing execution
6. `temporal_cloud_v0_workflow_continued_as_new_count` - Workflow Executions that were Continued-As-New from a past execution

### Health Monitoring

Calculate success rates baselines and identify trends:

**Prometheus:**
```
# Overall workflow success rate
(rate(temporal_cloud_v0_workflow_success_count[5m]) / 
 (rate(temporal_cloud_v0_workflow_success_count[5m]) + 
  rate(temporal_cloud_v0_workflow_failed_count[5m]) + 
  rate(temporal_cloud_v0_workflow_timeout_count[5m]))) * 100
```

**DataDog:**
```
(sum:temporal.cloud.v0_workflow_success{$Namespace}.as_rate() / (sum:temporal.cloud.v0_workflow_success{$Namespace}.as_rate() + sum:temporal.cloud.v0_workflow_failed{$Namespace}.as_rate() + sum:temporal.cloud.v0_workflow_timeout{$Namespace}.as_rate())) * 100
```

**DataDog Alert Setup for Workflow Success Rate:**
- Navigate to **Monitors** → **New Monitor** → **Metric**
- Set **Define the metric**: Use the workflow success rate formula above
- Set **Set alert conditions**: `below` threshold of `95` (95% success rate)
- Configure **Say what's happening**: "Workflow success rate has dropped below acceptable threshold"

#### Error Analysis & Alerting

Set up alerts for different failure modes:

* **High failure rates**: Monitor `workflow_failed_count` for workflow logic issues
* **Timeout patterns**: Track `workflow_timeout_count` for performance problems and improper timeout settings
* **Unexpected terminations**: Watch `workflow_terminate_count` for operational issues

**DataDog Alert Setup for Workflow Failures:**
- Navigate to **Monitors** → **New Monitor** → **Metric**
- Set **Define the metric**: `sum:temporal.cloud.v0_workflow_failed{$Namespace}.as_rate()`
- Set **Set alert conditions**: `above` threshold based on your baseline
- Configure **Say what's happening**: "Elevated workflow failure rate detected"

**DataDog Alert Setup for Workflow Timeouts:**
- Navigate to **Monitors** → **New Monitor** → **Metric**
- Set **Define the metric**: `sum:temporal.cloud.v0_workflow_timeout{$Namespace}.as_rate()`
- Set **Set alert conditions**: `above` threshold based on your baseline
- Configure **Say what's happening**: "Workflow timeout rate is elevated"

Related, SDK metric workflow_endtoend_latency will tell you total workflow execution time from schedule to completion for a single Workflow Run. (A retried Workflow Execution is a separate Run.)  
You can compare this to your [workflow timeout](https://docs.temporal.io/encyclopedia/detecting-workflow-failures#workflow-run-timeout) settings if set. Compare with temporal_cloud_v0_workflow_timeout_count to correlate timeouts.

### Activity Metrics

There are a few Activity Metrics that we haven't discussed before.

activity_execution_latency ([**ref**](https://docs.temporal.io/references/sdk-metrics)) - Measures time from Activity Task generation to SDK completion response. Use this to:

* Establish SLA monitoring and alerting
* Identify performance bottlenecks in specific activity types
* Track performance trends over time

**DataDog Alert Setup for Activity Latency:**
- Navigate to **Monitors** → **New Monitor** → **Metric**
- Set **Define the metric**: `p95:temporal_activity_execution_latency{namespace:your_namespace}`
- Set **Set alert conditions**: `above` threshold based on your activity SLA
- Configure **Say what's happening**: "Activity execution latency SLA breach"

activity_poll_no_task ([ref](https://docs.temporal.io/references/sdk-metrics) ) - Counts when Activity Workers poll but find no tasks. Helps with:

* Right-sizing your worker pool (too many idle polls = over-provisioned workers)
* Understanding workload patterns
* Optimizing polling configurations

#### End-to-End Performance

activity_succeed_endtoend_latency ([ref](https://docs.temporal.io/references/sdk-metrics)) - Measures total time from scheduling to completion for successful activities. Perfect for:

* Business-level SLA monitoring
* Understanding true user-experienced latency
* Performance benchmarking and optimization

#### Local Activity Metrics

Local activities have their own set of metrics: local_activity_execution_latency, local_activity_execution_failed, etc. ([ref](https://docs.temporal.io/references/sdk-metrics)) which are important because local activities execute within the workflow worker process. Good to:

* Monitor local activity performance differences
* Identify when local activities might be causing workflow worker issues

#### Error and Health Monitoring

activity_task_error ([ref](https://docs.temporal.io/references/sdk-metrics)) - Captures internal errors during activity handling, essential for:

* Detecting SDK or infrastructure issues
* Distinguishing between business logic failures and system errors
* Maintaining system reliability

**DataDog Alert Setup for Activity Task Errors:**
- Navigate to **Monitors** → **New Monitor** → **Metric**
- Set **Define the metric**: `sum:temporal_activity_task_error{namespace:your_namespace}.as_rate()`
- Set **Set alert conditions**: `above` threshold of `0.01` (1% error rate)
- Configure **Say what's happening**: "Activity task error rate is elevated"

Unregistered_activity_invocation ([**ref**](https://docs.temporal.io/references/sdk-metrics)) - Alerts when workflows try to invoke activities that aren't registered with workers:

* Catch deployment issues early
* Prevent silent failures in distributed systems
* Ensure proper activity registration

**DataDog Alert Setup for Unregistered Activities:**
- Navigate to **Monitors** → **New Monitor** → **Metric**
- Set **Define the metric**: `sum:temporal_unregistered_activity_invocation.count{namespace:your_namespace}.as_count()`
- Set **Set alert conditions**: `above` threshold of `0`
- Configure **Say what's happening**: "Unregistered activity invocation detected - check deployment"
- Set **Priority**: `P2` (High)

## Search Attributes and Stuck Workflows

Search Attributes in Temporal are indexed metadata fields that enable powerful querying and monitoring of workflow executions.

ExecutionStatus: The current state of workflow execution

* Values: `Running`, `Completed`, `Failed`, `Canceled`, `Terminated`, `ContinuedAsNew`, `TimedOut`
* Critical for identifying workflow states and filtering problem workflows

StartTime & CloseTime: Temporal boundaries of workflow execution

* Use to calculate execution duration and identify long-running workflows
* Format: RFC3339Nano or epoch time in nanoseconds

ExecutionDuration: Total execution time (available only for closed workflows)

* Stored in nanoseconds, queryable in multiple formats
* Essential for performance analysis

HistoryLength: Number of events in workflow history

* Indicates workflow complexity and potential performance issues
* Available only for closed workflows

TaskQueue: The task queue used by the workflow

* Useful for isolating issues to specific worker pools

WorkflowType: The type/name of the workflow

* Essential for filtering specific workflow types

### Custom Search Attributes

Custom Search Attributes can be used to help detect Workflows in a specific state:

1. Set an attribute "State" during normal workflow progress
2. temporal workflow list --query "ProcessingStage = 'payment-verification'

Custom Search Attributes can be used to detect Workflows might be temporarily stuck:

1. Set an attribute "Priority" on workflow start
2. temporal workflow list --query "Priority = 'high' AND ExecutionStatus = 'Running' AND StartTime < '$(date -d '1 hour ago' --iso-8601)'"

You can set a Custom Search Attributes when Workflows are experiencing long retries:

1. Set an attribute "State" during normal workflow progress
2. If the Workflow's activities failures exceed their retry policies, catch that error, page, and set "State" to "ActivityRetryExceeded" or "MaybeStuck" and then retry with a more generous retry policy
3. Then you can find such workflows when diagnosing:   
   temporal workflow list --query "State = 'ActivityRetryExceeded'


### Detecting "Stuck Workflows"

Workflows occasionally run longer than expected or desired. This is often a hint that something needs to change in the Workflow. But it is appropriate to consider how to detect such cases.  
The appropriate solution is somewhat dependent on what code you have written already, what the business needs are, and what is causing Workflows to be stuck.

Here are some techniques you can use to detect Workflows that aren't proceeding as you would like:

* Monitor relevant Temporal metrics for broader system health. For example, to detect latency in workflows and activities, use schedule_to_start SDK metrics.
   * See [Schedule To Start Latency](#schedule-to-start-latency) above.
   * Monitor end-to-end latencies, see [Workflow Metrics](#workflow-metrics) and [Activity Metrics](#activity-metrics) above.
* Add Timers in Workflow code to detect and handle overruns.
   * Maxim discusses this in a community post [here](https://community.temporal.io/t/how-can-workflow-detect-itself-stuck-in-a-state-for-too-long/1238/9).
   * This is often the simplest and cleanest implementation: let Workflows self-manage.
* Use visibility queries to find long-running Workflows.
   * You can look for Workflows by StartTime.
   * Can be implemented in a monitoring workflow that looks for Workflows open for "too long" and notifies a human operator.
   * If appropriate, use custom search attributes for more granular tracking. For example:
      * Set an attribute "Priority" on workflow start
      * temporal workflow list --query "Priority = 'high' AND ExecutionStatus = 'Running' AND StartTime < '$(date -d '1 hour ago' --iso-8601)'"
   * See [Search Attributes](#custom-search-attributes) above for more details
* Monitor for higher than normal Activity Retries. See [High Activity Failure Count Monitoring](#high-activity-failure-count-monitoring) above.

In most cases, the best guidance is to let Workflows monitor their own deadlines with a Timer.

## References

* [https://docs.temporal.io/cloud/how-to-monitor-temporal-cloud-metrics](https://docs.temporal.io/cloud/how-to-monitor-temporal-cloud-metrics)
* [https://docs.temporal.io/references/sdk-metrics](https://docs.temporal.io/references/sdk-metrics)
* [https://docs.temporal.io/application-development/worker-performance#metrics](https://docs.temporal.io/application-development/worker-performance#metrics)
* [https://docs.temporal.io/troubleshooting/performance-bottlenecks](https://docs.temporal.io/troubleshooting/performance-bottlenecks)