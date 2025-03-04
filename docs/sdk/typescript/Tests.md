# TypeScript SDK: Tests

This curriculum uses [mocha](https://mochajs.org/#getting-started) with bare NodeJS [assert](https://nodejs.org/api/assert.html).
There is an example of using [chai](https://www.chaijs.com/api/) with its [chai-as-promised plugin](https://www.npmjs.com/package/chai-as-promised) if
fluent BDD is your style.

TestDouble support is done in this curriculum with [sinon](https://sinonjs.org/releases/v19/).

Note that Mocha prescribes:
* Not to use [lambda functions](https://mochajs.org/#arrow-functions) for the callbacks that comprise your test. Use `function` instead.
* Not to use `async` [`describe`](https://mochajs.org/#limitations-of-asynchronous-callbacks).
* Understand the [hooks](https://mochajs.org/#hooks) ordering to avoid confusing connection errors and timeouts.

Be sure to increase the `timeout` of your `before` hooks in tests that create the 
TestWorkflowEnvironment to allow for a successful download of the test server. 
It is possible to end up with a corrupted download that is difficult to debug if the test
aborts before it is completed.

You can point the TestWorkflowEnvironment options to point to a known test server binary location to get around this occasional issue.
This can also simplify targetting specific versions of the Temporal service.