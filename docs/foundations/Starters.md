# Starters

## Goals

* Understand how to integrate `Temporal Client` into an API
* Understand `WorkflowStartOptions` enough to make the right choice for your Use Case
* Understand how to Start OR Execute a Workflow
* Introduce Web UI and a Workflow Execution history

## Best Practices

### Workflow Id Requires A Strategy.

* `WorkflowId` should have business meaning. 
  * This identifier can be an AccountID, SessionID, etc. or some published format that includes these. 
* Prefer _pushing_ an WorkflowID into Workflow start options instead of retrieving the ID after-the-fact - even if the SDK will create one for you. 
* Acquaint your self with the "Workflow ID Reuse Policy" and other related WorkflowID policies to fit your use case
  * _Not all SDKs behave the same with WorkflowID presence_. Look in the [SDK](../sdk) for important particulars.
  
References: 
* https://docs.temporal.io/workflows#workflow-id-reuse-policy

### Do not use a Workflow RetryPolicy

This is different from an Activity RetryPolicy and you probably don't need it. 

Workflows Retries execute the _entire_ Workflow over again.

If you have Activities which are not idempotent, it could corrupt your Application.
Also consider that a Timer inside that Workflow will be rescheduled so the caller will possibly be blocked waiting for the Workflow to 
fulfill the Retry Policy.

This might be what you want. For example, if you are executing a Child Workflow that _is guaranteed_ to safely execute all related
steps, but you want to tune how many times to retry this unit can be handy. 

If you choose to use - Use with caution.


