# Onboardings:Timers

## Refactorings

Our requirements demand we "wait" for approval before registering our entity with our CRM.
The onboarding must be completed within _seven days_ of submission. Let's wait that long before
exiting the Workflow as `Failed`. Here are steps we will take to model this safely:

* Introduce an explicit `state` object we can use as a private variable inside our Workflow to track the progress of various changes in our Workflow
    * Here, we are going to wait for `IsApproved` to be flipped to `true` before proceeding
* Extend our `OnboardEntityRequest` to accept an optional input for the `timeout` of approval
    * Why not use `WorkflowExecutionTimeout`?
        * Primarily because we want to express this as a _business rule_. We may want to extend this time later and we want to allow the workflow, not the caller, to govern execution rules.
        * Note that an approval could come in very late and while the activities that should complete are running they could be terminated due to the execution timeout. This would not be the intent of any time threshold.
    * Why not use a global constant for this delay timeout?
        * You can, but this will force a redeploy to make changes to product rules. We chose an optional input parameter with a fallback value to increase flexibility.
    * What about current tests that were built without this timeout constraint? There are two options:
        * We could use a "magic number" of `-1` to tell our Workflow to skip the approval
        * We could choose to be explicit and add `SkipApproval` to the input argument
            * This is the choice we make because it is clearer to maintainers
* Support an `Errors`  enumeration for raising a timed out OnboardEntity request.
