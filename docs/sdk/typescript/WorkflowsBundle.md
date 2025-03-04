# TypeScript SDK: Workflows Bundle

Temporal Applications built with the TypeScript SDK should be "bundled" for Production deployments.
This bundle is produced by Webpack and a starter script [here](../../app/src/scripts/build-workflow-bundle.ts)
shows what goes into configuring this bundle output.

> The output _size_ of the Workflows bundle is something you must monitor during Production builds.

The bundle size directly impacts the memory footprint of the host at runtime. This is true regardless of the `ReuseV8Context` setting
since user code gets reloaded _for each Workflow_. 

Here are some "rules of thumb" to use as a base for determining the impact of your code on your compute resources:

* Assume that the per-Workflow memory footprint is _twice_ the Workflow bundle size (when `ReuseV8Context==true`)
* Try to keep the Workflow bundle size below 2MB.
* Take care to avoid extraneous package dependencies that can bloat the bundle unnecessarily.
* The generator for your messaging (for example, Protobufs) is a frequent cause of bundle bloat.
* Also pay attention to any dependencies you might be using in a custom `PayloadConverter`.