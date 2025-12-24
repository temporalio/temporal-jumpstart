# Workflows

Workflows are the core abstraction in Temporal for modeling durable, reliable business processes. This guide provides best practices, patterns, and testing strategies for writing effective Workflows.

## Index of Categories

### 1. [Best Practices](#1-best-practices)
- [Workflow Input](#workflow-input)
- [Workflow Structure](#workflow-structure)
- [Exception & Failure Strategy](#exception--failure-strategy)

### 2. [Common Patterns](#2-common-patterns)
- [Configurable Durations for Testing](#configurable-durations-for-testing)
- [Calculating Elapsed Time](#calculating-elapsed-time)

### 3. [Testing Considerations](#3-testing-considerations)

### Additional Sections
- [Quick Reference](#quick-reference)
- [Additional Resources](#additional-resources)
- [Summary](#summary)

---

## 1. Best Practices

### Workflow Input

**Description**: Design Workflow inputs to support more than business data. Intentful messages can carry along
important execution context and behavioral options to produce Workflows that are both extensible and testable.

**Best Practices**:
- Include execution options in your Workflow inputs that alter behavior for testing or different contexts
- Make durations, timeouts, and other configuration values configurable via input arguments
- This enables the same Workflow code to run in different environments (production, staging, testing) with appropriate timing

**Use Cases**:
- End-to-end testing without lengthy waits
- Environment-specific behavior (staging vs production configuration injection)
- SLA-driven timeout variations

---

#### Example: Configurable Durations for Testing

**Description**: Design Workflows to accept configurable durations rather than hard-coding timeout values.

**Problem**: If you are performing end-to-end testing in your CI/CD pipeline and want to exercise your Workflows without lengthy tests due to `timer` usage, hard-coded timeouts make tests slow.

**Solution**: Extend input arguments to either force elapsed time or provide dynamic timeout values.

**Scenario**:

Let's say our Workflow should only wait _N_ seconds for an approval (_Human-in-the-loop_). Initially, we might define:

```typescript
type MyWorkflowArgs = {
    value: string
}
```

We might intend to retrieve timeout values from our environment or hard code them. But what if we want to exercise this Workflow with the same production configuration in our `staging` cluster?

**Better Approach**: Make the Workflow more flexible by accepting the timeout as an option:

```typescript
type ExecutionOptions = {
    approvalTimeoutSeconds?: bigint
}

type MyWorkflowArgs = {
    // now we accept an optional parameter to alter timeout
    executionOptions?: ExecutionOptions
    value: string
}
```

This approach works for altering **execution** behaviors we want to manipulate at runtime.

**Benefits**:
- Same Workflow code works across all environments
- Tests can use shorter timeouts
- Production can use appropriate SLA-based timeouts
- No code changes needed for different contexts

---

### Workflow Structure

**Prerequisite**: Understand the [Temporal Workflow Execution Event Loop](https://docs.temporal.io/handling-messages#message-handler-concurrency).

**Description**: Recommended structure for organizing Workflow code.

**Best Practice**:

Workflows should generally follow this high-level structure:

1. **Initialize state**: This is typically a single object that gets updated by the Workflow over time.
2. **Configure read handlers**: Expose state ASAP so that even failed Workflows can reply with arguments, etc.
3. **Configure write handlers**: This includes queries, signals, and updates.
4. **Validate**: Validate this Execution given its time, inputs, and current application state.
5. **Load Context**: Load (via [Activity](Activities.md)) configuration or environment variables that may be required for Workflow behavior.
6. **Perform behavior**: This is where Timers, Activities, etc. can now meet Application requirements over time.

**Benefits**:
- State is accessible early, even if the Workflow fails later
- Validation happens before expensive operations
- Handlers are set up before the main Workflow logic
- Clear separation of concerns

**SDK Variances**:
How this structure is implemented depends on how Workflows are designed with the selected SDK; that is, how it is registered with the Worker:

**Functional Style** (Go, TypeScript):
- The Worker registers **a single function** as the Workflow definition
- This function "wires up" message handlers and workflow behavior inside its body
- **All six steps** of the structure occur within this one function:
  - State initialization happens at the top of the function
  - Handler registration (queries, signals, updates) happens inline via SDK APIs
  - Validation, context loading, and behavior logic follow in the same function scope

**Classical Style** (Java, .NET, Python, Ruby):
- The Worker registers **a class Type** as the Workflow definition
- The class constructor handles **state initialization**
  - Always provide one constructor that is a [Workflow Initializer](https://docs.temporal.io/handling-messages#workflow-initializers). Note that it must have exactly the same signature as your primary Workflow `Execute` function.
- Message handlers are separate, annotated methods (e.g., `@QueryMethod`, `@SignalMethod`) that **configure read and write handlers**
- The main Workflow method (annotated as the primary Workflow method) contains the remaining structure:
  - _Validate_
  - _Load Context_
  - _Perform behavior_

---

### Exception & Failure Strategy

**Description**: Understanding how exceptions and failures affect Workflow Executions and how to handle them properly.

#### Exception Categories

Exceptions and Failures fall into two categories. By default, the category will impact how a Workflow Execution behaves when an Exception is encountered:

**1. Transient Exceptions**
- **Cause**: Bugs in Workflow code
- **Behavior**: Will _not_ close the Workflow Execution (i.e., exit as `Failed`)
- **Recovery**: The current Workflow Task will be rescheduled so that the bug may be fixed and redeployed to resume Execution

**2. Application Failures**
- **Definition**: SDK failure types explicitly **thrown/raised/returned** that bubble up in your Workflow Code
- **Behavior**: Will close the Workflow Execution with a `Failed` status

**Configuration Note**: Each SDK has options to tune how Exception types affect the Workflow Execution. This is handy if you already have a custom Exception hierarchy that does not descend from a Temporal Failure type, but you still want them to fail Workflow Executions.

**Best Practice: Distinguish between Business and Execution Failure**:

> Workflows that execute as instructed did not fail, even if the intended business goal did not succeed. 

Consider capturing _business_ failures as properties on your internal **Workflow State** object 
to expose these as **Queries** or **Search Attributes**. 

A Temporal Failure thrown due to a _business_ condition will
- Show the Execution _itself_ as having failed (eg, could not do as instructed)
- Increment the `workflow_failed` metric which can skew the perceived health of the Application

**Benefits**:
- Keeps execution concerns separate from business concerns
- Avoids the false perception of poor system health
- Workflow can be `Completed` successfully even if business goals were not met

**Best Practice: Don't Leak Implementation Details**:

> Prefer handling errors raised by Activities to transform to Caller failure expectations.

**Benefits**:
- Encapsulates error handling within the Workflow
- Cleaner Caller code
- Better separation of concerns
- Workflow maintains control over its own lifecycle

**References**:
- [Temporal Failures Documentation](https://docs.temporal.io/references/failures#application-failure)
- [Detecting Workflow Failures](https://docs.temporal.io/encyclopedia/detecting-workflow-failures)

---

## 2. Common Patterns

### Establish The Workflow Lifecycle

**Description**: Workflows should control their own lifecycle and error handling. The time-to-live for a Workflow should be obvious in code.

* Be intentional about how long a Workflow should stay `Open`
    * Specify and enforce the time-to-live within a background `Wait Condition`.
* Handle Cancellations explicitly in the Workflow. This is especially important for long-running Workflows.
* Regardless of whether your Workflow is long- or short-running, have a plan for change management via Workflow Versioning.

### Encapsulate Workflow State

**Description**: Workflows should encapsulate their state in a single object. This makes it easier to reason about the Workflow's behavior and makes it easier to test.

* Always initialize an object called `state` in the Workflow Initializer. It is useful for debugging and extensibility.
  * Do not support multiple data fields on your Workflow. Use the `state` object.
* Always capture input messages (Signals/Updates) and Activity responses directly onto the `state` object.
* Avoid exploding `boolean` state indicators and prefer simple inference based on `null` values to determine what has happened in a Workflow.
* Always support a `getState` Query that returns this state object. 
  * This is useful for business and operations scenarios.
  * This is how to test for `state` assertions in your `TestWorkflowEnvironment` tests.

### Calculating Elapsed Time

**Description**: Best practices for calculating elapsed time in Workflows.

**Scenario**: It is common to need the elapsed time between actions, like when a Workflow has started, or report the amount of time until an action might be performed.

**Naive Approach**: You might use `workflow.GetInfo(ctx).WorkflowStartTime` (Golang) to determine when the Workflow was started.

**Problem**: What if the Caller started this Workflow while your system was undergoing maintenance and Workers were not available? This would skew that elapsed time calculation.

**Better Solutions**:

**Option 1: Pass Timestamp as Input** (Recommended)

If more precision is required to meet a time threshold (perhaps due to a Service Level Agreement (SLA)), consider adding a `timestamp` to the input argument that is required at the "caller" call site. This gives a more accurate and traceable value upon which to base any elapsed time calculations.

**Benefits**:
- Accurate timestamp reflecting business intent
- Traceable in Workflow history
- Not affected by Worker availability
- Supports precise SLA calculations

**Option 2: Read from Workflow History**

Alternately, you can read from the Workflow Execution history via the low-level "DescribeWorkflowExecution" gRPC API to determine when the `WorkflowExecutionStarted` event was minted.

**Trade-offs**:
- Accurate timestamp from Temporal Server
- Requires performing a `LocalActivity` in your Workflow to obtain this value
- More complex implementation
- Additional API call overhead

**Recommendation**: Prefer Option 1 (pass timestamp as input) for simplicity and clarity.

---

## 3. Testing Considerations

**Key Points**:
- Use `TestWorkflowEnvironment` for unit testing Workflows
- Configure shorter timeouts for tests using configurable duration patterns (see [Configurable Durations](#configurable-durations-for-testing))
- Test both success and failure scenarios
- Verify that failed Workflows can still be queried for state
- Test exception handling for both Transient Exceptions and Application Failures

**Testing Goals**:
- Introduce `/tests` considerations
- Introduce our first test using the `TestWorkflowEnvironment`
- Understand `Failure` versus `Exception` errors, their impact on Workflow executions, and how to work with them

---

## Additional Resources

- [Temporal Workflows Documentation](https://docs.temporal.io/workflows)
- [Workflow Testing Best Practices](https://docs.temporal.io/develop/testing/overview)
- [Failure Handling](https://docs.temporal.io/references/failures)
- [Detecting Workflow Failures](https://docs.temporal.io/encyclopedia/detecting-workflow-failures)

---

## Summary

**Essential Best Practices** (apply to every Workflow):

1. **Workflow Input** - Design inputs with configurable execution options and behavioral parameters for flexibility across environments
2. **Workflow Structure** - Follow the recommended 6-step structure: initialize state → configure read handlers → configure write handlers → validate → load context → perform behavior
   - Implementation varies by SDK: Functional style (Go, TypeScript) uses a single function; Classical style (Java, .NET, Python, Ruby) distributes across class methods
3. **Exception & Failure Strategy** - Distinguish business failures from execution failures; capture business failures as state rather than throwing exceptions
4. **Don't Leak Implementation Details** - Handle Activity errors within Workflows and transform them for Callers

**Common Patterns**:

1. **Establish The Workflow Lifecycle** - Be explicit about time-to-live, handle cancellations, and plan for versioning
2. **Encapsulate Workflow State** - Use a single `state` object to track all workflow data; expose it via a `getState` Query
3. **Calculating Elapsed Time** - Pass timestamps as input arguments for accurate time calculations unaffected by Worker availability

**Testing**:
- Use `TestWorkflowEnvironment` for unit tests
- Configure shorter timeouts via input arguments for fast end-to-end tests
- Test both success and failure scenarios
- Verify failed Workflows remain queryable for state