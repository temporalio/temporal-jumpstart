# Onboardings:Starters

#### Select Our Options

* **Workflow ID:** Let's use the same `id` as the resource that has been `PUT`
* **Workflow ID Reuse Policy:** Our requirements state that we want to allow the same WorkflowID if prior attempts were Canceled.
  Therefore, we are using this Policy that will reject duplicates unless previous attempts did not reach terminal state as `Completed'.

## Start an Entity Onboarding

1. Run all services (see main README)
2. Issue a request with the Swagger UI for `V1` paths that opens up OR
    1. Using your favorite HTTP Client send `PUT` request like
        1. `http PUT http://{HOSTNAME}/api/v1/onboardings/onboarding-123 value=some-value`
3. Now issue a `GET` to the same resource to see the input parameters and execution status of your Workflow
    1. eg `http GET http://{HOSTNAME}/api/v1/onboardings/onboarding-123`

**Expected outcome**

1. You should see a Workflow running  [locally](http://localhost:8233/namespaces/default/workflows) or in the [Temporal Cloud Namespace UI](https://cloud.temporal.io).
    1. WorkflowType: `WorkflowDefinitionDoesntExistYet`
    2. WorkflowId: `onboarding-123`
2. Enter the Workflow and you should see a "No Workers Running" caution and the first two events which indicate the
   Workflow has been scheduled to execute.
