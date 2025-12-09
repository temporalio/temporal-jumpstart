# Workflows

### Goals

* Introduce `/tests` considerations
* Introduce our first test using the `TestWorklowEnvironment`
* Understand `Failure` versus `Exception` errors, their impact on Workflow executions, and how to work with them


## Best Practices

### Input Arguments

Consider including options into your Workflow inputs that alter its behavior for testing or other contexts.

##### Configurable Durations

If you are performing end-to-end testing in your CI/CD pipeline and want to exercise your Workflows without
lengthy tests due to `timer` usage, consider extending input arguments to either force the elapsed time or provide dynamic timeout values.

_Example_

Let's say our Workflow should only wait _N_ seconds for an approval (_Human-in-the-loop_).
Today, we kick off the Workflow with the following arguments:

```typescript
type MyWorkflowArgs = {
    value: string
}
```

We might intend to retrieve _timeout_ values we use from our environment or hard code it.
What if we want to exercise this Workflow with the same production configuration in our `staging` cluster.

One approach to make this Workflow more flexible and easier to adapt to various execution contexts is to extend the input arguments to _accept_ the timeout as an option.

```typescript
type MyWorkflowArgs = {
    // now we accept an optional parameter to alter timeout
    approvalTimeoutSeconds?: bigint
    value: string
}
```

This approach works for skipping Activities or other **execution** behaviors we want to manipulate at runtime.

### Workflow Structure

Workflows should generally follow this structure:

1. Initialize _state_ : This is typically a single object that gets updated by the Workflow over time.
2. Configure _read_ handlers: Expose state ASAP so that even failed workflows can reply with arguments, etc.
3. _Validate_: Validate this Execution given its time, inputs, and current application state.
4. Configure _write_ handlers: This includes queries, signals, and updates.
5. Perform _behavior_ : This is the where Timers, Activities, etc can now meet Application requirements over time.

**FAQ**
* Can you `Query` **Failed** Workflows?
  * Yes. It is important that the state being exposed via those Queries reflect the status accurately where applicable.

### Have an Exception/Failure Strategy

#### Exception Categories

Exceptions and Failures fall into two categories. By default, the category will impact how a Workflow Execution behaves when an
Exception is encountered:

* _**Transient Exceptions**_ are caused by bugs in Workflow code.
  * These will _not_ close the Workflow Execution (ie, exit as `Failed`).
  * Instead, the current Workflow Task will be rescheduled so that the bug may be fixed and redeployed to resume Execution.
* _**Application Failures**_ are SDK failure types explicitly **thrown/raised/returned** that bubble up in your Workflow Code.
  * These _will_ close the Workflow Execution with a `Failed` status.

Note that each SDK has options to tune how Exception types affect the Workflow Execution.
This is handy if you already have a custom Exception hierarchy that does not descend from a Temporal Failure type,
but you still want them to fail Workflow Executions.

References:
* https://docs.temporal.io/references/failures#application-failure
* https://docs.temporal.io/encyclopedia/detecting-workflow-failures

Given these distinctions, try to apply this best practice:

> Prefer handling errors that are raised by Activities to decide how to proceed instead of handling Application errors
> in Caller code.

### Calculating Elapsed Time

It is common to need the elapsed time between actions, like when a Workflow has started, or report the amount of time until
an action might be performed.

You might use the `workflow.GetInfo(ctx).WorkflowStartTime` (Golang) to determine when the Workflow was started,
but what if the caller started this Workflow while your system was undergoing maintenance and Workers were not available? This would skew
that variable of the elapsed time calculation.

If more precision is required to meet a time threshold (perhaps due to a Service Level Agreement (SLA)), consider adding a `timestamp` to the input argument
that is required at the "caller" call site. This gives a more accurate and traceable value upon which to base any elapsed time calculations.

Alternately, you can read from the Workflow Execution history via the low-level "DescribeWorkflowExecution" gRPC API to determine when the `WorkflowExecutionStarted`
event was minted, but keep in mind that now you have to perform an `LocalActivity` in your Workflow to obtain this value.