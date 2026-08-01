---
description: Run AzureScout unattended from Azure Automation, GitHub Actions, or Azure DevOps.
---

# Automation

AzureScout is built to run without a human at the keyboard: no interactive prompts, no COM
dependencies, and a run log written for every run including failed ones.

## Pick a host

| Page | Use it when |
|---|---|
| [Azure Automation Account](./automation.md) | You want a scheduled runbook inside Azure, authenticating with a managed identity and writing to blob storage |
| [GitHub Actions](./github-actions.md) | Your pipelines already live in GitHub — a composite action is provided |
| [Azure DevOps](./azure-devops.md) | Your pipelines live in ADO, or you also want to inventory ADO itself: projects, pipelines, service connections, repos and agent pools |

## What every unattended run needs

- **A non-interactive identity** — a managed identity, or a service principal with a secret or
  certificate. See [Authentication](../guide/authentication.md).
- **Reader at the scope you want covered.** Anything narrower silently reduces what is
  collected, so run [`-PermissionAudit`](../guide/permissions.md) once from the same identity
  first.
- **Somewhere durable for the output.** In an Azure Automation sandbox the filesystem is
  discarded when the job ends, so blob storage is the only copy that survives.

## Reading a headless run

Every run writes `scout-run.log` with phases, elapsed times, counts and full error detail —
including runs that failed. Two further artefacts make a run auditable rather than merely
finished:

- `raw-inventory.json` — everything collected, written **before** any manifest decided what to
  display, so a resource type no collector claims still leaves a trace.
- `collector-rowcounts.json` — what each collector produced, and why it produced nothing.

That last distinction is the one that matters unattended: an empty worksheet and a collector
that was never permitted to run look identical in a report, and these files tell them apart.
