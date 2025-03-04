# Golang SDK: Tests

### Available Environments

###### TestWorkflowEnvironment
The Golang SDK maintains its own `TestWorkflowEnvironment`. 
"Timeskipping" is fully supported in this environment, making it useful for functional, blackbox tests.

Note that Workflow history is not produced during these tests, so features or assertions that need access
to the Execution history will not be able to use this Environment. For that, use [DevServer](devserver).

###### DevServer

The `DevServer` is a downloaded copy of the `temporal` CLI that runs the `dev-server`. 
It is useful for test suite integration since it exposes lifecycle methods (eg `Start/Stop`) to control the service.
Also, low-level APIs will also have access to Execution history for feature development or assertions.

This is useful for testing against specific Temporal Service versions or for interacting with Execution history.

Note: This is downloading a binary in its first test run, so be sure you do not have a short test timeout that might result 
in a corrupted download file. Alternatively, point your `Setup` of the DevServer to point to your already-available, 
local Temporal CLI.

