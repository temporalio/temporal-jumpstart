# 📘 Protobuf Versioning: Best Practices and Pitfalls

Protobuf is designed to let schemas evolve gradually, without requiring a full API version bump every time something changes.  
Still, for major or incompatible changes, coarse-grained API versioning remains a common and recommended practice.  
The key idea is that versioning happens at the **message (schema) level**, not necessarily at the global API level.

When done carefully, this allows old and new services to communicate seamlessly during transitions.

---

## ✅ Non-Breaking Changes

Most schema evolution in Protobuf can be done without breaking compatibility, as long as you follow strict rules.

| Action              | How to Implement                                      | Compatibility Notes                                                                 |
|---------------------|-------------------------------------------------------|-------------------------------------------------------------------------------------|
| **Adding a field**  | Add a new field with a unique field number.           | ✅ Backward: Old code ignores it.<br>✅ Forward: New code assigns a default value.    |
| **Renaming a field**| Change the field name but keep the field number.      | ✅ Safe for binary.<br>⚠️ Risky for JSON/text & reflection. Avoid unless unused.     |
| **Removing a field**| Remove it, but reserve its field number (and name).   | ⚠️ Only safe if unused. Old clients sending it will lose data.                       |
| **Deprecating a field** | Mark `[deprecated = true]` to discourage usage.   | ✅ Full compatibility. Wire format intact.                                          |

---

## ❌ Breaking Changes

Some schema edits are inherently breaking because they change how the data is represented on the wire:

- Changing a field’s type (e.g., `int32 → string`).
- Changing cardinality (`optional ↔ repeated`).
- Reusing a field number (**never do this!**).

When breaking changes are unavoidable, you have two main strategies:

### 1️⃣ Introduce a new message type
Define a new message (e.g., `UserV2`) and migrate gradually. Old and new services can explicitly agree on which version they support.

### 2️⃣ Coarse-grained API versioning
For larger, structural changes across many messages, version entire namespaces (e.g., `package my.api.v1`, `package my.api.v2`).  
This provides a clean break while letting old clients coexist.  
*Example: Envoy Proxy’s migration from v2 to v3.*

---

## 📦 Language-Specific Library Versions

Schema versioning is separate from the versioning of **language-specific Protobuf libraries**.  
The schema compatibility rules above are universal, but each language’s library evolves on its own schedule.

Example: In 2022, the **Python Protobuf API** introduced breaking changes and moved to version 4.x, while Java and C++ stayed on 3.x.

---

## 📊 Quick Reference: Safe vs. Risky vs. Breaking

| Category          | Safe ✅                | Risky ⚠️                                      | Breaking ❌                                   |
|-------------------|------------------------|-----------------------------------------------|-----------------------------------------------|
| **Field operations** | Adding a new field   | Renaming a field (JSON/text issues)<br>Removing a field (if still in use) | Changing type<br>Changing cardinality<br>Reusing field numbers |
| **Deprecation**   | Deprecating a field    | –                                             | –                                             |
| **API evolution** | –                      | –                                             | New message types<br>Namespace versioning      |

---

## 🔑 Key Takeaways

- ✅ Safe: add fields, deprecate fields, reserve numbers when removing.
- ⚠️ Risky: renaming and removing fields unless you’re certain they’re unused.
- ❌ Breaking: changing types, changing cardinality, reusing field numbers.
- 🔄 For unavoidable breaks: introduce new messages or apply API-level versioning.
- 📦 Remember: library versioning ≠ schema versioning.

Protobuf’s design makes it easier to evolve services without disruption — but only if you respect its compatibility rules.