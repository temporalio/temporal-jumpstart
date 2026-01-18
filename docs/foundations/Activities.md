# Activities

* Introduce our first Activity test using `ActivityTestEnvironment`
* Discuss the importance of _idempotency_ 
* Understand Dependency Injection in our Activity implementations
* Understand `ActivityOptions` 
  * Discuss the different `Timeouts` available 
  * Understand `RetryOptions` and gotchas
  * Understand choosing `NonRetryable` failure type ownership

## Best Practices

### Base Activity Options On User Experience Goals

Users care how long something takes to complete, not the number of times it was attempted.
Therefore, prefer the [ScheduleToClose Timeout](https://docs.temporal.io/encyclopedia/detecting-activity-failures#schedule-to-close-timeout)
to limit Activity executions, not RetryOptions.

That said, there are good reasons to limit Activity executions based on a counter. For example,
when using a notifications service that is not known to dedupe requests, it is best to 
limit the `max attempts` of RetryOptions to prevent accidentally deploying a spam server.

### Non-Retryable Error Strategy

Temporal supports declaring specific errors as [Non-Retryable](https://docs.temporal.io/encyclopedia/retry-policies#non-retryable-errors)
from both the Workflow code and the Activity code. 
Like the name implies, Errors returned of this `type`(**string**) will not be retried.

The question is, which "side" of the call should own this rule - the Workflow or the Activity?

##### Activity As Owner
If the Activity author is making explicit Errors which she knows will _never_ succeed, prefer
returning the Error as an ApplicationFailure with a `NonRetryableError`. 
This makes the Activity the "owner" of this rule so _any_ Workflow that calls this Activity
will need to handle this Error.
It also imposes a control flow on calling Workflows though so needs  

###### Example

If an Activity internally calls an API that periodically goes down for very long periods, 
return an ApplicationFailure with a NonRetryable Error of `ERR_UNAVAILABLE`. This allows
Workflow authors to respond and take a different course of action. 

##### Workflow As Owner
It is best to allow Workflow authors to have ownership of their own control flow.
It follows that Errors being returned from an Activity should be allowed to retry according to the _Workflow_ specification. 
This makes the Workflow the "owner" of the non-retryable rule.
This keeps the Activity decoupled from a Workflow specification so that it may remain more reusable and keeps a Workflow
from manually writing looped retry logic to handle errors declared non-retryable by the Activity error result.

###### Example

A new Application team wants to author a `MakePayment` Workflow that performs compensation if the `SubmitPayment` Activity, but 
not until it has failed for 7 days.

Unfortunately, the "Payments" team that owns the `SubmitPayment` Activity declares _any_ errors it encounters as **NonRetryable**.
The Workflow authors must work around this by keeping track of their own allowance of 7 days and retry in a loop until that threshold is met.

The Workflow code would be made simpler if the `SubmitPayment` Activity author had only declared truly terminal Errors **NonRetryable**
so that the Workflow can keep trying to submit the payment per its own rules using Temporal Retry configuration.

### Activity Heartbeat Considerations

#### When To Heartbeat

* **Cancellation**: If your Activities should be cancellable, you should implement the heartbeat so that the Temporal Service
  can reply to heartbeats that the Workflow is cancelled.
* **Longevity**: There is no hard rule about this, but if your [StartToCloseTimeout](https://docs.temporal.io/encyclopedia/detecting-activity-failures#start-to-close-timeout) is `>= 2 minutes` you should consider heartbeating.
  * Heartbeating will prevent your Workflow from being slowed by Activities which have gone offline (crashed or hung) and can get rescheduled on another process sooner.
* **Checkpointing**: If You need to resume a long-lived Activity from a _checkpoint_ like a **cursor, line number, or db record** you can include the current _checkpoint_ in `HeartbeatDetails` to resume the Activity from previous execution.
  * **NOTE**: You should not rely on the Heartbeat consistency; eg, Heartbeat requests can _fail_, especially if the process hard-crashed. Hence, **idempotency** remains vital _per resource_ being dealt with in an Activity. 

#### How To Heartbeat

1. You _MUST_ specify a `HeartbeatTimeout` in the **ActivityOptions** for the Worker to send the heartbeats to the Temporal Service.
   1. If you aren't seeing heartbeats hitting the Temporal Service, check that this option is specified.
2. You _MUST_ use the `ActivityContext#heartbeat` API for your SDK to ping a heartbeat to the Temporal Service.

Now the question is: How often should I `heartbeat` inside my Activity?

1. It is common to use the `Activity Context` to obtain the _current heartbeat timeout_ to determine this frequency.
2. It is also common to implement a _background_ heartbeat (eg, in another **Thread** or asyncio **Task**) to allow the primary work to block. 
   1. Note that background heartbeats should usually handle `cancellation` properly inside the Activity.

#### Throttling

Keep in mind that the SDK batches heartbeats; that is, they are [throttled](https://docs.temporal.io/encyclopedia/detecting-activity-failures#throttling).
So an activity can heartbeat as frequently as it likes, but the SDK batches consecutive heartbeats and
only reports the last one at **80% of heartbeat interval**.

1. This keeps costs of heartbeats down in Temporal Cloud. 
2. You might drop some heartbeats; keep this in mind if you are sending `Heartbeat Details`.

######  Example
Let’s say you provide Activity Options with the heartbeat timeout configured at _10 seconds_.
Inside the Activity implementation, you report a heartbeat every second in a loop.
You should expect that the last heartbeat around _8 seconds_ is the one which actually gets reported to the Temporal service.

#### Idempotency Everywhere

The `details` support for a Heartbeat is useful for long-running activities to resume an operation
where it was prior to a fault.

Note that data loss is possible with heartbeat details (see [Heartbeat Considerations](heartbeat-considerations) above).

> It is vital to make _each_ mutation of Application state inside the Activity idempotent.

###### Example

Let's say you have a long-running poll against a database table that needs to react to new
record appearances.

The Activity steps initially are:
1. Check heartbeat details for presence of any record data.
2. Start a loop that polls the database for new records, _starting at the heartbeat record id_ (if present)
3. For each record, use `POST` with this data to create a resource via an internal API

See the possibility for corruption? If the previous Activity Worker crashed after writing the record but before the 
heartbeat could provide details, you could duplicate the POST call for the same record.

This could be guarded against by either:
1. Including an "idempotency key" in the POST call,
2. By doing a read (eg a `GET`) to the resource to verify it does not exist.

### Determine Timeouts and Cancellations Inside Activity Code On Activity Options

Fetch the `StartToClose` or other timeouts configured for your Activity execution _within_ your Activity by using its related "context".
Different SDKs expose the Activity Options variously.

#### Constrain Resource Usage

Activities typically have some time-bound operations like:
1. Explicit `sleep` calls
2. Implicit connections to external resources like databases or APIs

Base any connection timeouts or suspension operations on the Activity Options you have passed in to avoid
having these hold onto Worker slots longer than anticipated.

#### Handle Cancellation Explicitly

Activities receive a `cancellation` request when a Workflow has been Cancelled.
They discover this cancellation by receiving a CancelledFailure in response to a `heartbeat` report.

If you have started an operation with an external resource, try to handle this cancellation inside the Activity
and clean up these calls before exiting.

Each SDK has its own way of retrieving the Cancellation and how to cancel connections or other resources.
