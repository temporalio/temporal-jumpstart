# Golang SDK: Starters

### StartWorkflowOptions quirks

The Golang SDK has a slightly more granular way to tune how WorkflowID duplicates are handled
when Starting a Workflow.

Before looking at this, let's review the definitions used for Workflow status:

| Progress Status |                  Associated Statuses                  | Description                                                                                   |
|:---------------:|:--------------------------------------------------------------:|:----------------------------------------------------------------------------------------------|
|     Closed      | Canceled<br/>Completed<br/>Failed<br/>Terminated<br/>Timed Out | Workflow is in a terminal state, so will not make progress. Will respond to `Query` requests. |
|      Open       |                            Running                             | Workflow is still able to make progress.                                                      |


Therefore, configure Execution behavior such that when providing a Workflow ID AND the Workflow is...

| Progress Status |         Option          | Description                                                                  |
|:---------------:|:-----------------------:|:-----------------------------------------------------------------------------|
|     Closed      | `WorkflowIDReusePolicy` | Configures whether to either return an Error or allow the `Execute` request. |
|      Open       |            `WorkflowIDConflictPolicy`             | Configures whether to fail for Workflow executions still making progress.    |

#### Recommendations:

**_DO NOT USE_**

* `WorkflowIDConflictPolicy.WORKFLOW_ID_REUSE_POLICY_TERMINATE_IF_RUNNING`
    * From the docs: "This option belongs in WorkflowIdConflictPolicy but is here for backwards compatibility."

**_DO USE_** 
* `WorkflowExecutionErrorWhenAlreadyStarted` should be `true` 
  * To adhere to The Principle Of Least Surprise, this setting will fail at the call site when a `WorkflowAlreadyStarted` error is returned. Otherwise, the caller will not be aware of this response.