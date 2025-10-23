# Jumpstart Foundations

The foundational modules for building Temporal applications using "top-down" Test-Driven Development. These modules describe the core patterns and decisions you'll make when building production applications.

## Core Modules (In Order)

Work through these modules in sequence to build a complete understanding:

1. **[Starters](Starters.md)** - How to start workflows from your applications, including client setup and workflow initiation patterns
2. **[Workflows](Workflows.md)** - Building durable workflow logic that orchestrates your business processes
3. **[Activities](Activities.md)** - Implementing business logic as activities with proper error handling and retries
4. **[Tests](Tests.md)** - Testing strategies for workflows and activities, including unit and integration tests
5. **[Versions](Versions.md)** - Handling workflow versioning and evolution for safe deployments
6. **[Workers](Workers.md)** - Configuring, deploying, and scaling workers to execute your workflows and activities

## Application-Specific Modules

The following modules appear based on your application requirements:

- **[Timers](Timers.md)** - Working with durable timers and delays for scheduling and timeout patterns
- **[Writes](Writes.md)** - Handling state mutations in workflows with signals and updates
- **[Reads](Reads.md)** - Querying workflow state without affecting execution
- **[Messaging](Messaging.md)** - Inter-workflow communication patterns including signals, queries, and child workflows

## Operational Modules

These modules address operational concerns for production applications:

- **[DataConverter](DataConverter.md)** - Custom data serialization, encryption, and compression for workflow payloads
