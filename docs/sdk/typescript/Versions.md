# TypeScript SDK: Versions

The TypeScript SDK has some subtle differences in what constitutes a non-deterministic change.

Review the code-change docs [here](https://docs.temporal.io/workflows#non-deterministic-change). 

### Timers

* Non-Determinism : A timer `duration` change will _not_ cause a Non-Determinism Exception (NDE). Note the new duration will not be effectual during Workflow Execution replay.
* Zero: A `Timer(0)` will be internally changed to `Timer(1)` and schedule Task.


