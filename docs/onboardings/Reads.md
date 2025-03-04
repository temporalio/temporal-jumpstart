# Onboardings:Reads

## Refactorings

> Requirement: We need to support the View of our submitted Entity Onboarding by fetching the Workflow
state that represents it.

We will use *Query* to retrieve this state inside our `GET /onboardings/{id}` API handler.

* Introduce explicit `queries` message to meet our *GetEntityOnboardingState* request
* Remove the complex history collection in our `GET` handler and reduce the code to use our *GetEntityOnboardingStatus* Query.
* Change our `GET` result to reflect our UI that needs
    * Approval status and Comment
    * Current Value
    * Id