# Activities

Activities are the "doers" in your Workflow code, the "steps" of a process, or the "channel" to external operations. Non-determinism is NOT required in Activity code. Activities can be as fast or as slow as the behavior inside needs to complete.

An `Activity` is an implementation of the **Adapter** pattern, so it is common to use existing API clients, DB connections, etc on the _inside_ of an Activity while the message contract is enforced for _adapting_ to Temporal orchestration concerns.

## Index of Categories

### 1. [Activity Types](#1-activity-types)
- [Understanding Task Execution](#understanding-task-execution)
- [Choosing Which Type to Use](#choosing-which-type-to-use)

### 2. [Best Practices & Patterns](#2-best-practices--patterns)
- [Test With The SDK `ActivityTestEnvironment`](#test-with-the-sdk-activitytestenvironment)
- [Inject Dependencies At Startup](#inject-dependencies-at-startup)
- [Prefer Explicit, Singular Message Signatures](#prefer-explicit-singular-message-signatures)
- [Maintain Interface Compatibility](#maintain-interface-compatibility)
- [Enforce Idempotency](#enforce-idempotency)
- [Implement Activity Coarseness Carefully](#implement-activity-coarseness-carefully)
- [Configure Activity Options On User Experience Goals](#configure-activity-options-on-user-experience-goals)
- [Use Non-Retryable Errors](#use-non-retryable-errors)
- [Determine Timeouts and Cancellations](#determine-timeouts-and-cancellations-inside-activity-code-on-activity-options)

### 3. [Regular Activity Special Considerations](#3-regular-activity-special-considerations)
- [Activity Heartbeat Considerations](#activity-heartbeat-considerations)
- [Constrain Resource Lifetimes](#constrain-resource-lifetimes)
- [Asynchronously Completed Activity](#asynchronously-completed-activity)
- [Activity Rate-Limiting](#let-temporal-service-perform-activity-rate-limiting-when-needed)

### Additional Sections
- [Additional Resources](#additional-resources)

---

## 1. Activity Types

There are two types of Activities a Workflow may execute: [Local Activity](https://docs.temporal.io/local-activity) and [Activity](https://docs.temporal.io/activities) (Regular Activity). They share their _purpose_ in a Workflow, but it is vital to understand their distinctives.

### Understanding Task Execution

**Local Activities** are executed within the current `Workflow Task`, NOT as a discrete, scheduled Activity Task.
1. _N_ Local Activities might be executed within the Workflow Task Timeout window.
2. Local Activities will always execute in the same Process as the current Workflow Task.
   1. ...But don't assume the host is always guaranteed to be the same. Workflow Workers fail, too.
3. The SDK Worker manages an internal Task Queue for scheduling these types of Activities. It follows that the durability and availability is subject to Workflow Worker guarantees.

**"Regular" Activities** are executed due to a discrete, scheduled _Activity Task_ from an Activity Task Queue.

### Choosing Which Type to Use

Temporal does not enforce what happens inside any Activity, but here is some guidance for choosing one Type over another.

| Local Activity | Regular Activity |
|---|---|
| Execution is _fast_ (`< 60 seconds`) | Execution _might_ be fast, but _might not_ (`> 60 seconds`) |
| Virtually guaranteed to succeed | Will fail sometimes |
| NO I/O | HAS I/O |
| Do NOT require heartbeat | Will utilize heartbeat |
| Won't "steal" capacity from Workflow Task operations like _signal_, _query_, etc. | Execution in its own Task Queue |
| | Will be completed asynchronously |
| **Common Uses:** Configuration lookups, environment lookups, quick cache lookups, in-memory calculations, random value generation, in-memory validations | **Common Uses:** API calls, database operations, file operations, long-polling tasks, message consumers |

> Local Activities can cut costs on Temporal Cloud, but prefer Activity Type choice on technical requirements - not cost.

#### Gotchas

1. **Local Activity** can actually _slow_ your Workflow down:
   1. If they fail repeatedly, failure will cause the entire Workflow Task to eventually fail 
   2. If the _retry interval_ exceeds the Workflow Task Timeout, a Timer is to scheduled for the retry.
      1. This can result in more actions (and greater cost)
2. **Local Activity** might be retried _even when it did not fail_ due to the Workflow Task it belongs to failing for a _different_ reason. 

---

## 2. Best Practices & Patterns

Regardless of which Activity Type, these are some best practices to strive for in implementation.

### Test With The SDK `ActivityTestEnvironment`

This "environment" does not connect to or use a real Temporal service, unlike the `WorkflowTestEnvironment`.

Use this test environment when:
* The Activity implementation interacts with the `ActivityExecutionContext` for timeout values, descriptors, etc. 
* `Heartbeat` usage should be verified or stubbed
* `ApplicationFailure`s should be verified

### Inject Dependencies At Startup
Pass dependencies the Activity implementation requires into the Activity implementation at
Application startup. This avoids expensive, frequent Dials to remote services.

Be careful about shared state across Activity implementations. How this is guarded depends on the SDK.

### Prefer Explicit, Singular Message Signatures

**Activity** should have an explicit "Request" and "Response" argument, just like any other Temporal primitive.
Be liberal in message propagation and don't couple messages to each other by reusing them across different Activity implementations.

### Maintain Interface Compatibility

Consider how to defensively make changes on both "sides" of Workflow and Activity code; changing signatures
can introduce issues after deployment.

If your Workers are deployed with [Worker Versioning](https://docs.temporal.io/worker-versioning), interface compatibility between
Activity and Workflow code is less brittle. [Here are details on Activity behavior with Worker Versioning.](https://docs.temporal.io/worker-versioning#actvity-behavior-across-versions)

Defensive programming with input argument assertions becomes even more important if Workers
are deployed with rolling deployments since Workflow and Activity versions might be out of step during rollout.

An Activity that is co-located with a Workflow within a 
moves in tandem with the Workflow so this concern is not as great.

**Command inputs (requests) to Activity are not written to event history**. 
That means you can safely change these signatures for inputs.

Note that the response payloads _are_ written to history and can impact Workflow determinism in myriad ways
so be careful about how deployments are done between Activity and Workflow code.

### Enforce Idempotency

Activities SHOULD be idempotent. Temporal does not _enforce_ for you, but it is risky _not_ to enforce it yourself.

> Always code your Activity as if it might be executed 100 times quickly due to retries caused by failure. 
> What could be corrupted in the resources you are using "inside" the Activity?

Protect the resources you are interacting with in your Activities by either implementing an _idempotency key_
for them to reference or by inspecting the state of the resource (or its presence) before performing mutations against it.

### Implement Activity Coarseness Carefully

How much should I do in a single Activity? 
This [article here](https://temporal.io/blog/how-many-activities-should-i-use-in-my-temporal-workflow) articulates constraints that 
should guide how coarse or granular your Activity implementations should be.

Here are some key principles to consider:

#### Commands/Writes: Prefer performing at most ONE mutation to a resource in an Activity.
Failure conditions become unwieldy and idempotency gets trickier to enforce when you mutate
more than one resource in an Activity. Caller Workflows are forced to respond to too many conditions
that can make Workflow code hard to understand.

#### Queries/Reads: Accumulate data and liberally call resources within reason
If remote resources are not overly sensitive to chatty retries, consider accumulating relevant
data into a single Response message that can save on Activity roundtrips. 
This is valid _so long as the Activity retains cohesion_.

### Configure Activity Options On User Experience Goals

Users care about operation latency, not the number of times it was attempted.
Prefer the [ScheduleToClose Timeout](https://docs.temporal.io/encyclopedia/detecting-activity-failures#schedule-to-close-timeout)
to limit Activity executions, not RetryOptions.

That said, there are good reasons to limit Activity executions based on a counter. For example,
when using a notifications service that is not known to dedupe requests, it is best to 
limit the `max attempts` of RetryOptions to prevent accidentally deploying a spam server.

### Use Non-Retryable Errors

Temporal supports declaring specific errors as [Non-Retryable](https://docs.temporal.io/encyclopedia/retry-policies#non-retryable-errors)
from both the Workflow code and the Activity code. 
Like the name implies, Errors returned of this `type`(**string**) will not be retried.
These are especially useful for explicit contracts and increased cognition of possible failure conditions.  

#### Determine The Non-Retryable Declaration Owner - Workflow or the Activity

###### Activity As Owner
If the Activity author is making explicit Errors which she knows will _never_ succeed, prefer
returning the Error as an ApplicationFailure with a `NonRetryableError`. 
This makes the Activity the "owner" of this rule so _any_ Workflow that calls this Activity
will need to handle this Error.
It also imposes a control flow on calling Workflows though so needs  

**_Example_**

If an Activity internally calls an API that periodically goes down for very long periods, 
return an ApplicationFailure with a NonRetryable Error of `ERR_UNAVAILABLE`. This allows
Workflow authors to respond and take a different course of action. 

###### Workflow As Owner
It is best to allow Workflow authors to have ownership of their own control flow.
It follows that Errors being returned from an Activity should be allowed to retry according to the _Workflow_ specification. 
This makes the Workflow the "owner" of the non-retryable rule.
This keeps the Activity decoupled from a Workflow specification so that it may remain more reusable and keeps a Workflow
from manually writing looped retry logic to handle errors declared non-retryable by the Activity error result.

**_Example_**

A new Application team wants to author a `MakePayment` Workflow that performs compensation if the `SubmitPayment` Activity, but 
not until it has failed for 7 days.

Unfortunately, the "Payments" team that owns the `SubmitPayment` Activity declares _any_ errors it encounters as **NonRetryable**.
The Workflow authors must work around this by keeping track of their own allowance of 7 days and retry in a loop until that threshold is met.

The Workflow code would be made simpler if the `SubmitPayment` Activity author had only declared truly terminal Errors **NonRetryable**
so that the Workflow can keep trying to submit the payment per its own rules using Temporal Retry configuration.

### Determine Timeouts and Cancellations Inside Activity Code On Activity Options

Fetch the `StartToClose` or other timeouts configured for your Activity execution _within_ your Activity by using its related "context".
Different SDKs expose the Activity Options variously.

#### Constrain Resource Usage

Activities typically have some time-bound operations like:
1. Explicit `sleep` calls
2. Implicit connections to external resources like databases or APIs

Base any connection timeouts or suspension operations on the Activity Options you have passed in to avoid
having these hold onto Worker slots longer than anticipated.

---

## 3. Regular Activity Special Considerations

These are best practices that apply to facilities _only_ available with Regular Activities.

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

Note that data loss is possible with heartbeat details. The importance of idempotency cannot be overstated when using heartbeat details.

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

#### Handle Cancellation Explicitly

Activities receive a `cancellation` request when a Workflow has been Cancelled.
They discover this cancellation by receiving a CancelledFailure in response to a `heartbeat` report.

If you have started an operation with an external resource, try to handle this cancellation inside the Activity
and clean up these calls before exiting.

Each SDK has its own way of retrieving the Cancellation and how to cancel connections or other resources.

### Constrain Resource Lifetimes

Use the `StartToCloseTimeout`, available on the `ActivityExecutionContext` to limit resource access lifetimes like
API Connections, Database transactions, etc. 

Failure to do so can result in Activity "zombies" that stay connected to the resource even after Temporal has
scheduled a new Activity execution, leading to idempotency risks and unnecessary **slot** reservations.

Temporal does not attempt to kill a thread or task associated with an Activity if it "hangs" or exceeds
the amount of time allocated by Activity Option timeouts.

### Asynchronously Completed Activity

These are only available with Regular Activities; that is, a discrete `Activity Task` exists for the Activity.

How can an Activity start an operation remotely that will take a long time to complete without
occupying a [Worker slot](https://docs.temporal.io/develop/worker-performance#slots)?

There are [two primary patterns](https://docs.temporal.io/activity-execution#asynchronous-activity-completion) for handling this scenario documented.

Choose the **Asynchronous Activity** completion approach when:
* The remote operation intends to periodically heartbeat its status
* The remote service does not object to Temporal SDK dependencies and Client connection where needed.
* The `WorkflowID/ActivityID` and/or `TaskToken` details can be forwarded to the remote service.
* Visibility in the Temporal UI for Async Activity tracking is vital. 
* Activity slots are precious; it is desired to free them up for other Tasks.

#### Gotchas

Each Activity is **execution** receives a unique `TaskToken`. That means _retries_ each receive
a new Task Token. If a remote service expects to use the `TaskToken` from an Activity execution that
**fails**, the `AsyncActivityClient` (or "handle") will fail when using that token as being no longer valid.

Prefer using the combination of `WorkflowID` & `ActivityID` to instruct remote operations how to **complete** or **heartbeat**
the Activity out-of-band.

### Let Temporal Service Perform Activity Rate-Limiting (when needed)

Configure your Worker with `TaskQueueActivitiesPerSecond` (depending on SDK) to protect
downstream resources or otherwise control execution rate. This effectively offloads the rate limit
to Temporal Service and allows simple rate limiting across _N_ Worker processes.

Note that this value should be the same across all Worker processes connected to this TaskQueue.

---

## Additional Resources

- [Temporal Activities Documentation](https://docs.temporal.io/activities)
- [Local Activity Documentation](https://docs.temporal.io/local-activity)
- [Activity Testing Best Practices](https://docs.temporal.io/develop/testing/overview)
- [Retry Policies and Non-Retryable Errors](https://docs.temporal.io/encyclopedia/retry-policies)
- [Detecting Activity Failures](https://docs.temporal.io/encyclopedia/detecting-activity-failures)
- [Activity Execution Patterns](https://docs.temporal.io/activity-execution)
- [How Many Activities Should I Use in My Temporal Workflow](https://temporal.io/blog/how-many-activities-should-i-use-in-my-temporal-workflow)