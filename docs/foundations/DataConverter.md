# Data Converter

Temporal messages always contain a collection of `Payloads` - the business data your Application utilizes to perform work.
Since this data is part of the message envelope being written into Temporal data stores it
typically must be secured:

* In transit to and from a Temporal Service 
* At rest in the Temporal Server persistence

## Data Converter

The `Data Converter` plugin to SDK Temporal Clients provides the hook to meet "in transit" data protection requirements.

`DataConverter` is really comprised of three interfaces you might implement to meet your security or other data requirements.
* `PayloadConverter`
* `PayloadCodec`
* `FailureConverter`

You may implement any of them depending on the role each performs within the data pipeline.

### Where To Implement Encryption 
The `PayloadCodec` interface is the right place to perform encryption/decryption on `Payloads` as they exit or enter our Temporal 
Application, NOT inside a `PayloadConverter` implementation.
This is because `PayloadConverter` will be subject to "Deadlock Detection" that could fail Workflow Tasks after just `1 second`. 

A `PayloadCodec` implementations can be asynchronous and are not subject to this timeout, so it makes sense to perform potentially
intensive work there. Also, a third-party Key Management provider could be used in this implementation.

### PayloadCodec Considerations

> Temporal SDK's do not support hot-loading right now for cryptographic key refreshment.

There are two primary requirements to determine for a production-grade `PayloadCodec` implementation:

1. How will cryptographic keys I use be rotated?
2. How will I obtain the current cryptographic key?

Temporal has some constraints you must keep in mind to reason toward your solution.

#### Rotating Cryptographic Keys

It can be tricky to build a reliable key rotation service, so you might consider using something like [Amazon KMS](https://docs.aws.amazon.com/kms/latest/developerguide/overview.html)
to manage this vital process for you.

> **;tldr: The Payload data you encrypt today _could be around forever_.**

Any strategy for rotation _must_ bear in mind:
1. The Temporal Namespace Retention Policy 
2. Arbitrary Workflow Lifetimes

If you are using asymmetric keys, you may need to perform this rotation manually so might consider doing so
on each Temporal SDK Worker deployment or when you periodically rotate your Compute infrastructure. Symmetric keys
can often be rotated automatically by a provider.

#### Obtaining Cryptographic Keys

_How_ you obtain and reference the cryptographic key in the `PayloadCodec` requires careful attention due to 
frequency of the transformations on Payloads and the risk of latency that might be introduced at this stage of a Workflow or Activity Task.

Consider adopting these recommendations to avoid Workflow Task timeouts or hitting rate limits on cryptography key providers:

* Do not fetch a cryptographic key inside the `PayloadCodec` methods directly, as this introduces unacceptable latency
in the transfer of data with Temporal Server.
* Instead, fetch the key when you create the `PayloadCodec` implementation (eg, during Worker startup)
and _cache_ that key to reduce expensive network lookups. 
* If you deploy infrequently or want to tap into a forced key rotation, update this key asynchronously _in your implementation_ and cache that result. 

**TIP:** If you are using Amazon KMS, you might consider pairing this with the [AWS Encryption SDK](https://docs.aws.amazon.com/encryption-sdk/latest/developer-guide/introduction.html) to get cached key support.
Be sure to read their [guide on this topic](https://docs.aws.amazon.com/encryption-sdk/latest/developer-guide/data-key-caching.html) to know the tradeoffs.