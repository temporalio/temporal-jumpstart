# Isolation

There are two fundamental isolation units in Temporal applications: `Namespace` and `Task Queue`.

The distinction each of these meets in your Applications is driven by a wide variety of requirements.
Here are some recommendations to help you decide how to segment workloads in your system.

## [Namespaces](https://docs.temporal.io/namespaces)

How "coarse" should your isolation be with Temporal namespaces?

Namespaces are disambiguated in Temporal Cloud by a naming convention (format).

The simplest Temporal Cloud namespace formats often look something like:
* `{applicationName}-{environment}`;  **orders-prod**
* `{teamName}-{environment}`; **payments-staging**
* `{boundedContext}-{environment}`; **shipping-test**

Tenancy*, Tiers, or Business Units within an organization might demand a higher level of organization; eg
* `{businessUnit}-{boundedContext}-{environment}`; **northamerica-processing-uat**
* `{tier}-{service}-{environment}`; **premium-provisioning-dev**

> Multi-tenancy should be carefully considered as a basis for Namespace isolation.
