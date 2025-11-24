# Workflow Options Reference Guide

This guide categorizes Workflow Options (commonly called "Workflow Start Options" or "Client Options") across all Temporal SDKs. While the examples reference Java SDK naming conventions, the concepts apply universally across Go, TypeScript, Python, .NET, and PHP SDKs.

## Overview

Workflow Options configure how a Workflow Execution behaves when started. These options are set on the client side when creating a Workflow stub or starting a Workflow.

---

## Index of Categories

### 1. [Identifiers](#1-identifiers)
- [WorkflowId](#workflowid)
- [WorkflowIdReusePolicy](#workflowidreusepolicy)
- [WorkflowIdConflictPolicy](#workflowidconflictpolicy)

### 2. [Routing](#2-routing)
- [TaskQueue](#taskqueue)

### 3. [Timeouts](#3-timeouts)
- [WorkflowExecutionTimeout](#workflowexecutiontimeout)
- [WorkflowRunTimeout](#workflowruntimeout)
- [WorkflowTaskTimeout](#workflowtasktimeout)

### 4. [Reliability & Retry](#4-reliability--retry)
- [RetryOptions](#retryoptions)

### 5. [Scheduling](#5-scheduling)
- [CronSchedule](#cronschedule)
- [StartDelay](#startdelay)

### 6. [Observability & Metadata](#6-observability--metadata)
- [Memo](#memo)
- [SearchAttributes](#searchattributes)
- [TypedSearchAttributes](#typedsearchattributes)
- [StaticSummary](#staticsummary)
- [StaticDetails](#staticdetails)

### 7. [Advanced Features](#7-advanced-features)
- [ContextPropagators](#contextpropagators)
- [DisableEagerExecution](#disableeagerexecution)

### Additional Sections
- [Quick Reference Table](#quick-reference-table)
- [Common Patterns](#common-patterns)
- [SDK-Specific Notes](#sdk-specific-notes)
- [Additional Resources](#additional-resources)
- [Summary](#summary)

---

## Categories

### 1. Identifiers

Options that uniquely identify and control the lifecycle of Workflow Executions.

#### `WorkflowId`

**Description**: A unique identifier for the Workflow Execution within a namespace.

**Best Practices**:
- **Always set meaningful, business-domain Workflow IDs** rather than relying on auto-generated UUIDs
- Use identifiers that map to your business entities (e.g., `order-12345`, `user-onboarding-jane@example.com`)
- Meaningful IDs enable:
    - Easy deduplication of client-side retries
    - Simple lookups in the UI and CLI
    - Natural idempotency for your business processes
- Format: Consider a pattern like `{entity-type}-{entity-id}` or `{process-name}-{unique-key}`

**Default**: Auto-generated UUID (not recommended for production)

**Example Business Cases**:
- E-commerce: `order-processing-ORD-2024-001`
- User onboarding: `onboarding-user-abc123`
- Payment: `payment-stripe-pi_xyz789`

---

#### `WorkflowIdReusePolicy`

**Description**: Specifies server behavior when a **completed** Workflow with the same ID exists.

**Options**:
- `AllowDuplicateFailedOnly` (default): New run allowed only if previous run failed, was canceled, or terminated
- `AllowDuplicate`: New run allowed regardless of previous run status
- `RejectDuplicate`: New run rejected regardless of previous run status

**Note**: Under no conditions can two Workflows with the same namespace and Workflow ID run simultaneously.

---

#### `WorkflowIdConflictPolicy`

**Description**: Controls behavior when attempting to start a Workflow with an ID that's already in use by a *running* Workflow.

**Best Practices**:
- Use `UseExisting` for natural idempotency - if a Workflow is already running, connect to it
- Use `Fail` (default) when you want to explicitly prevent duplicate executions
- Use `TerminateExisting` carefully, typically in scenarios where you always want the latest version running

**Options**:
- `Fail` (default): Return an error if Workflow ID is already in use
- `UseExisting`: Return a handle to the existing running Workflow (does not start a new execution)
- `TerminateExisting`: Terminate the running Workflow and start a new one

**What "UseExisting" Means**:

When you start a Workflow with `UseExisting` and a Workflow with that ID is already running:
1. **No new Workflow is started** - the existing Workflow continues running unchanged
2. **You receive a Workflow handle** - this handle refers to the already-running Workflow
3. **You can interact with it** - use the handle to:
    - Query the Workflow for its current state
    - Send Signals to it
    - Wait for its result
    - Cancel it if needed

**Common Pattern - Idempotent Workflow Starts**:

This is especially useful for ensuring idempotency when you may retry a start operation:

```java
// First call - starts the Workflow
WorkflowOptions options = WorkflowOptions.newBuilder()
    .setWorkflowId("process-order-12345")
    .setWorkflowIdConflictPolicy(WorkflowIdConflictPolicy.USE_EXISTING)
    .setTaskQueue("orders")
    .build();

OrderWorkflow workflow = client.newWorkflowStub(OrderWorkflow.class, options);
WorkflowExecution execution = WorkflowClient.start(workflow::processOrder, orderData);

// Second call (maybe a retry) - gets handle to existing Workflow
// Does NOT start a second Workflow!
OrderWorkflow workflow2 = client.newWorkflowStub(OrderWorkflow.class, options);
WorkflowExecution execution2 = WorkflowClient.start(workflow2::processOrder, orderData);
// execution.getWorkflowId() == execution2.getWorkflowId()
// execution.getRunId() == execution2.getRunId()
// Both refer to the SAME running Workflow
```

**Use Cases**:
- **Retry safety**: Client code can safely retry start operations without creating duplicates
- **Process deduplication**: Ensure only one instance of a business process runs (e.g., "process-invoice-INV001")
- **Coordination**: Multiple services can independently try to start a Workflow, and all get connected to the same instance

**Comparison with WorkflowIdReusePolicy**:

These two policies serve different purposes:
- `WorkflowIdConflictPolicy`: Handles conflicts with *running* Workflows
- `WorkflowIdReusePolicy`: Handles conflicts with *completed* Workflows

You typically use both together for complete control over Workflow lifecycle.

---

### 2. Routing

Options that determine where Workflow Tasks are executed.

#### `TaskQueue`

**Description**: The Task Queue name where Workflow Tasks will be dispatched.

**Best Practices**:
- Must match the Task Queue that Workers are polling
- Use descriptive names that reflect the service or capability: `order-processing`, `email-service`, `payment-workflows`
- Consider Task Queue routing strategies:
    - **Service-based**: One Task Queue per microservice
    - **Capability-based**: Task Queues by function (e.g., `high-priority`, `background-jobs`)
    - **Tenant-based**: Separate Task Queues for different customers or environments
- Avoid generic names like `default` or `main` in production

**Required**: Yes

---

### 3. Timeouts

Timeout configurations that control Workflow Execution lifecycle boundaries.

> **Important**: In most cases, write _Workflows_ that control their own Lifecycle. 
> Callers should not control such business rules.
> Use input and configuration options to make it easy for the Workflow lifecycle to be tested and dynamic.

#### `WorkflowExecutionTimeout`

**Description**: Maximum time for the entire Workflow Execution, including retries and Continue-As-New runs.

**Best Practices**:
- Set this as a safety net to prevent runaway Workflows
- Should be significantly longer than your expected Workflow duration
- Typical values: Days to months for long-running business processes
- When timeout is reached, the Workflow cannot make progress and is terminated

**Default**: Unlimited (∞)

**Use Case Examples**:
- Month-long onboarding process: 45 days
- Annual subscription renewal: 380 days
- Short-lived orchestration: 24 hours

---

#### `WorkflowRunTimeout`

**Description**: Maximum time for a single Workflow Run (does not include retries or Continue-As-New).

**Best Practices**:
- Use for Workflows that should complete within a bounded time period
- The timeout applies per run, not across retries
- Set to a value that accounts for expected activity durations plus overhead
- Typical values: Hours to days

**Default**: Unlimited (∞), but inherits from `WorkflowExecutionTimeout` if set

**When to Use**:
- Setting a maximum duration for each attempt of a retryable Workflow
- Ensuring individual runs don't hang indefinitely

---

#### `WorkflowTaskTimeout`

**Description**: Maximum execution time for a single Workflow Task (the unit of Workflow code execution).

**Best Practices**:
- Default of 10 seconds is usually sufficient
- Only increase if your Workflow code legitimately takes longer (e.g., extensive local computation)
- If you're hitting this timeout, consider:
    - Moving heavy computation to Activities
    - Reducing complexity in Workflow code
    - Checking for non-determinism issues

**Default**: 10 seconds

**Maximum**: 120 seconds

**Common Issues**:
- If hitting this timeout repeatedly, it often indicates non-deterministic code or blocking operations in Workflow

---

### 4. Retryability

Options controlling Workflow retry behavior and failure handling.

> **Important**: This is rarely used for production code. 
> Prefer _Activity_ retry handling instead to avoid idempotency issues downstream.

#### `RetryOptions`

**Description**: Configuration for automatic Workflow retry on failure.

**Best Practices**:
- Set retry policies for transient failures (e.g., temporary service outages)
- Configure maximum attempts to prevent infinite retries
- Use exponential backoff for external service dependencies
- Consider carefully what failures should be retried vs. returned immediately

**Sub-Options**:
- `InitialInterval`: Starting retry delay (e.g., 1 second)
- `BackoffCoefficient`: Multiplier for delay between retries (typically 2.0)
- `MaximumInterval`: Cap on retry delay (e.g., 1 minute)
- `MaximumAttempts`: Maximum number of retry attempts (e.g., 10)
- `NonRetryableErrorTypes`: Error types that should not trigger retry

**Example**:
```java
RetryOptions.newBuilder()
    .setInitialInterval(Duration.ofSeconds(1))
    .setBackoffCoefficient(2.0)
    .setMaximumInterval(Duration.ofMinutes(1))
    .setMaximumAttempts(5)
    .build()
```

**Default**: No automatic retries unless explicitly configured

---

### 5. Scheduling

Options for controlling when and how often Workflows execute.

#### `CronSchedule`

**Description**: A cron expression that schedules the Workflow to run periodically.
> **Important**: Use Schedules instead.

**Best Practices**:
- Use standard cron syntax (5 or 6 fields)
- Default timezone is UTC unless specified otherwise
- Cannot be combined with `StartDelay`
- Each cron execution is a separate Workflow Run
- The Workflow should be idempotent for the time window

**Example Patterns**:
- Every minute: `* * * * *`
- Daily at 2 AM UTC: `0 2 * * *`
- Every Monday at 9 AM: `0 9 * * MON`
- First day of month: `0 0 1 * *`

**Use Cases**:
- Scheduled reports
- Periodic data synchronization
- Recurring maintenance tasks

**Note**: For complex scheduling needs, consider implementing scheduling logic within your Workflow using timers.

---

#### `StartDelay`

**Description**: Duration to wait before dispatching the first Workflow Task.

**Best Practices**:
- Useful for scheduled Workflows that should execute in the future
- Signals sent via Signal-With-Start will bypass the delay
- Regular Signals sent during the delay period are queued
- Cannot be combined with `CronSchedule`

**Use Cases**:
- Scheduled reminders (e.g., send email in 24 hours)
- Delayed job processing
- Time-based workflow orchestration

**Example**: Schedule a follow-up email 48 hours after user signup

---

### 6. Observability & Metadata

Options for storing and searching Workflow metadata.

#### `Memo`

**Description**: Non-indexed key-value metadata attached to the Workflow Execution.

**Best Practices**:
- Use for context that aids debugging but doesn't need to be searched
- Stored with Workflow history but not indexed
- Accessible through Workflow details in UI/CLI
- Values must be serializable by your DataConverter

**Use Cases**:
- Debug information: `{ "createdBy": "user@example.com", "sourceIp": "192.168.1.1" }`
- Context: `{ "requestId": "req-123", "apiVersion": "v2" }`
- Configuration snapshots

**Size Considerations**: Keep memo data reasonably small (under 1 KB recommended)

---

#### `SearchAttributes`

**Description**: Indexed key-value pairs for searching and filtering Workflow Executions (untyped version).

**Relationship with TypedSearchAttributes**:
- `SearchAttributes` is the original, untyped API that requires manual type specification
- `TypedSearchAttributes` is the newer, type-safe API (recommended)
- Both work and are maintained; TypedSearchAttributes provides better type safety and IDE support

**Details**: When using the untyped `SearchAttributes`, you must ensure the value types match what's registered in Temporal Server.

---

#### `TypedSearchAttributes`

**Description**: Type-safe indexed key-value pairs for searching and filtering Workflow Executions.

**Best Practices**:
- Must be registered with Temporal Server before use
- Use for fields you'll query on (e.g., customer ID, order status, region)
- Supported types: Text, Keyword, Int, Double, Bool, Datetime, KeywordList
- Choose correct type for your use case:
    - **Keyword**: Exact match searches, IDs
    - **Text**: Full-text search
    - **Int/Double**: Numeric ranges
    - **Datetime**: Time-based queries

**Example**:
```java
SearchAttributeKey<String> CUSTOMER_ID = 
    SearchAttributeKey.forKeyword("CustomerId");
SearchAttributeKey<Boolean> IS_PREMIUM = 
    SearchAttributeKey.forBoolean("IsPremium");

Map<String, Object> searchAttributes = 
    SearchAttributes.newBuilder()
        .set(CUSTOMER_ID, "CUST-12345")
        .set(IS_PREMIUM, true)
        .build();
```

**Use Cases**:
- Filtering Workflows by customer, order, or entity ID
- Querying by status, priority, or category
- Time-based filtering (created after date, etc.)

---

#### `StaticSummary`

**Description**: Single-line fixed summary displayed in UI/CLI for the Workflow Execution.

**Best Practices**:
- Keep concise (one line)
- Include key identifying information
- Appears prominently in Workflow lists
- Static (doesn't change during execution)

**Example**: `"Order #12345 - Premium Customer - Region: US-West"`

**Use Case**: Quickly identify Workflows in the UI without opening details.

---

#### `StaticDetails`

**Description**: Multi-line description or additional structured details about the Workflow Execution.

**Best Practices**:
- Use for extended context beyond the summary
- Can be structured data or formatted text
- Visible in Workflow detail views
- Static (doesn't change during execution)

**Example**:
```
Customer: Jane Doe (jane@example.com)
Order Type: Recurring Subscription
Payment Method: Credit Card ending in 4242
```

---

### 7. Advanced Features

Specialized options for advanced use cases.

#### `ContextPropagators`

**Description**: List of context propagation implementations to carry context across Workflow and Activity boundaries.

**Best Practices**:
- Use for tracing, logging context, or security principals
- Common use cases:
    - Distributed tracing (OpenTelemetry, Jaeger)
    - Logging correlation IDs
    - Authentication/authorization context
- Ensure propagated data is deterministic

**Example Use Cases**:
- Propagate trace IDs for distributed tracing
- Carry user identity across Workflow and Activities
- Pass request IDs for correlation

---

#### `DisableEagerExecution`

**Description**: Disables eager Workflow start optimization.

**Best Practices**:
- Leave at default (enabled) for best performance
- Only disable for specific testing or debugging scenarios
- Eager execution reduces latency when Worker and Client are co-located

**Default**: `false` (eager execution enabled)

**Background**: When enabled (default), if the Client requests eager execution and a Worker slot is available, the first Workflow Task is returned inline to the co-located Worker, reducing latency.

---

## Quick Reference Table

| Category | Option | Required | Default | Common Values |
|----------|--------|----------|---------|---------------|
| **Identifiers** | WorkflowId | Recommended | Auto-generated UUID | Business IDs |
| | WorkflowIdConflictPolicy | No | Fail | Fail, UseExisting |
| **Routing** | TaskQueue | **Yes** | None | Service names |
| **Timeouts** | WorkflowExecutionTimeout | No | ∞ | Days to months |
| | WorkflowRunTimeout | No | ∞ | Hours to days |
| | WorkflowTaskTimeout | No | 10s | 10-60s |
| **Reliability** | RetryOptions | Recommended | None | Varies by use case |
| **Scheduling** | CronSchedule | No | None | Cron expressions |
| | StartDelay | No | None | Duration values |
| **Observability** | TypedSearchAttributes | Recommended | Empty | Business attributes |
| | Memo | Optional | Empty | Debug context |
| | StaticSummary | Optional | Empty | One-line description |
| | StaticDetails | Optional | Empty | Multi-line details |
| **Advanced** | ContextPropagators | Optional | Empty | Tracing, auth |
| | DisableEagerExecution | No | false | true, false |

---

## Common Patterns

### Pattern 1: Production-Ready Configuration

```java
WorkflowOptions options = WorkflowOptions.newBuilder()
    // Identity
    .setWorkflowId("order-processing-" + orderId)
    .setWorkflowIdConflictPolicy(WorkflowIdConflictPolicy.USE_EXISTING)
    
    // Routing
    .setTaskQueue("order-processing")
    
    // Observability
    .setTypedSearchAttributes(
        SearchAttributes.newBuilder()
            .set(CUSTOMER_ID, customerId)
            .set(ORDER_STATUS, "pending")
            .build())
    .setMemo(ImmutableMap.of(
        "createdBy", userName,
        "apiVersion", "v2"))
    
    .build();
```

### Pattern 2: Scheduled/Recurring Workflow

```java
WorkflowOptions options = WorkflowOptions.newBuilder()
    .setWorkflowId("daily-report-" + LocalDate.now())
    .setTaskQueue("reporting")
    .setCronSchedule("0 2 * * *")  // 2 AM UTC daily
    .build();
```

### Pattern 3: Delayed Execution

```java
WorkflowOptions options = WorkflowOptions.newBuilder()
    .setWorkflowId("reminder-" + userId)
    .setTaskQueue("notifications")
    .setStartDelay(Duration.ofHours(24))
    .build();
```

---

## SDK-Specific Notes

While the concepts are universal, syntax varies by SDK:

- **Java**: `WorkflowOptions.newBuilder()`
- **Go**: `client.StartWorkflowOptions{}`
- **TypeScript**: `WorkflowOptions` interface
- **Python**: `WorkflowOptions` dataclass
- **.NET**: `WorkflowOptions` class
- **PHP**: `WorkflowOptions` class

Refer to your SDK's documentation for exact API syntax.

---

## Additional Resources

- [Temporal Documentation: Workflow Options](https://docs.temporal.io/workflows)
- [Best Practices: Starting Workflows](https://docs.temporal.io/develop/java/temporal-clients)
- [Workflow Retries](https://docs.temporal.io/encyclopedia/retry-policies)
- [Visibility & Search Attributes](https://docs.temporal.io/visibility)

---

## Summary

**Essential Options** (consider these for every Workflow start):
1. `WorkflowId` - Use business-meaningful IDs for idempotency and observability
2. `WorkflowIdReusePolicy` - Control behavior when reusing IDs of completed Workflows
3. `WorkflowIdConflictPolicy` - Control behavior when ID conflicts with running Workflows
4. `TaskQueue` - Route to correct Workers (required)

**Commonly Used for Observability**:
- `TypedSearchAttributes` - Enable filtering and searching Workflows
- `Memo` - For debugging context
- `StaticSummary` - For UI readability

**Specialized Use Cases** (avoid unless you have a specific need):
- `WorkflowExecutionTimeout` or `WorkflowRunTimeout` - Only for safety nets in exotic cases
- `RetryOptions` - Rarely needed; Workflows have built-in retry through Continue-As-New
- `CronSchedule` - For periodic execution
- `StartDelay` - For future execution
- `ContextPropagators` - For distributed tracing