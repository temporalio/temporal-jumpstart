# Messaging

Temporal advances state by passing messages through your system. 
This elevates the importance of an intentional Message strategy in your system.

Regardless of what you choose to use, _at least_ the following should be considered:
### Serialization Compatibility
This becomes vital in organizations that embrace polyglot development.
If you are using common language structures, each likely has their own peculiarities for
serialization to JSON, for example; snake case vs camel case vs pascal case, etc.

### Schema Evolution
Workflows are inherently "long-lived" (even for a few minutes), so shipped changes to schema
can disrupt `Open` workflow executions with serialization errors in the DataConverter.

Prefer _additive_ schema changes over _breaking_ changes with your messages. 

For example, if you have a `User` message, you can add a `User.is_active` field without breaking
existing workflows. But if you want to _rename_ that field to `is_currently_active` you should _add_ that
field and deprecate the old one when deemed safe. Tolerate some duplication for the sake of safety.

### Schema Versioning
You should be able to evolve your schema without major version bumps, but sometimes it is easier to 
bump the version of your entire API. 
Pay attention to the DataConverter being used in your Temporal SDK Client

If you need to support new versions of your schema (eg, the "type" of the message object) in your Temporal orchestration signatures but
do not want to version your Workflows to support them, you might consider a [Custom Data Converter](https://docs.temporal.io/default-custom-data-converters#custom-data-converter)
to upgrade messages during the deserialization process.

## Serialization Frameworks

You might consider using a serialization framework like [Protobuf](https://protobuf.dev/) or [Avro](https://avro.apache.org/)
to define your messages. These can be a logical choice if you expect, or have experienced,
complexity with [Schema Evolution](#schema-evolution) or [Schema Versioning](#schema-versioning).
[Serialization Compatibility](#serialization-compatibility) can also be aided by serialization framework standardization.

Below are some best practices for Protobuf serialization.

## 📘 Protobuf Versioning: Best Practices and Pitfalls

Protobuf is designed to let schemas evolve gradually, without requiring a full API version bump every time something changes.  
Still, for major or incompatible changes, coarse-grained API versioning remains a common and recommended practice.  
The key idea is that versioning happens at the **message (schema) level**, not necessarily at the global API level.

When done carefully, this allows old and new services to communicate seamlessly during transitions.

---

### ✅ Non-Breaking Changes

Most schema evolution in Protobuf can be done without breaking compatibility, as long as you follow strict rules.

| Action              | How to Implement                                      | Compatibility Notes                                                                 |
|---------------------|-------------------------------------------------------|-------------------------------------------------------------------------------------|
| **Adding a field**  | Add a new field with a unique field number.           | ✅ Backward: Old code ignores it.<br>✅ Forward: New code assigns a default value.    |
| **Renaming a field**| Change the field name but keep the field number.      | ✅ Safe for binary.<br>⚠️ Risky for JSON/text & reflection. Avoid unless unused.     |
| **Removing a field**| Remove it, but reserve its field number (and name).   | ⚠️ Only safe if unused. Old clients sending it will lose data.                       |
| **Deprecating a field** | Mark `[deprecated = true]` to discourage usage.   | ✅ Full compatibility. Wire format intact.                                          |

---

### ❌ Breaking Changes

Some schema edits are inherently breaking because they change how the data is represented on the wire:

- Changing a field’s type (e.g., `int32 → string`).
- Changing cardinality (`optional ↔ repeated`).
- Reusing a field number (**never do this!**).

When breaking changes are unavoidable, you have two main strategies:

#### 1️⃣ Introduce a new message type
Define a new message (e.g., `UserV2`) and migrate gradually. Old and new services can explicitly agree on which version they support.

#### 2️⃣ Coarse-grained API versioning
For larger, structural changes across many messages, version entire namespaces (e.g., `package my.api.v1`, `package my.api.v2`).  
This provides a clean break while letting old clients coexist.  
*Example: Envoy Proxy’s migration from v2 to v3.*

---

### 📦 Language-Specific Library Versions

Schema versioning is separate from the versioning of **language-specific Protobuf libraries**.  
The schema compatibility rules above are universal, but each language’s library evolves on its own schedule.

Example: In 2022, the **Python Protobuf API** introduced breaking changes and moved to version 4.x, while Java and C++ stayed on 3.x.

---

### 📊 Quick Reference: Safe vs. Risky vs. Breaking

| Category          | Safe ✅                | Risky ⚠️                                      | Breaking ❌                                   |
|-------------------|------------------------|-----------------------------------------------|-----------------------------------------------|
| **Field operations** | Adding a new field   | Renaming a field (JSON/text issues)<br>Removing a field (if still in use) | Changing type<br>Changing cardinality<br>Reusing field numbers |
| **Deprecation**   | Deprecating a field    | –                                             | –                                             |
| **API evolution** | –                      | –                                             | New message types<br>Namespace versioning      |

---

### 🔑 Key Takeaways

- ✅ Safe: add fields, deprecate fields, reserve numbers when removing.
- ⚠️ Risky: renaming and removing fields unless you’re certain they’re unused.
- ❌ Breaking: changing types, changing cardinality, reusing field numbers.
- 🔄 For unavoidable breaks: introduce new messages or apply API-level versioning.
- 📦 Remember: library versioning ≠ schema versioning.

Protobuf’s design makes it easier to evolve services without disruption — but only if you respect its compatibility rules.