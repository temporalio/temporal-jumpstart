# Onboardings:Writes

## Refactorings

> Requirement: Support the **Approve** or **Reject** Command that passes along details of the Owner (or Deputy Owner) reasons for Approval/Rejection.

We can do this by extending our `PUT /onboardings/{id}` endpoint with an `Approval` struct that accepts either `APPROVED` or `REJECTED` status with an optional `Comment`.

This means employing the "Create or Update" strategy for our Onboarding entity, but now we need to decide
whether we want to:
1. Check for existence of the `OnboardEntity` Workflow before sending our `ApproveOnboarding` Signal or
2. Try to send the appropriate Signal to the Workflow and handle the `NotFound` here
    1. This is what we will do for now since it saves us a round-trip to check for existence in most cases

#### Support the **SetEntityValue** Command that mutates the value

// TODO using Update
