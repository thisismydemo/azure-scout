---
description: Install AzureScout, sign in, run your first scan, and understand the output.
---

# Guide

Everything needed to install AzureScout, sign in, run a scan, and read what comes out.
Work through it in order the first time; after that, treat it as reference.

## Start here

| Page | What it answers |
|---|---|
| [Overview](./overview.md) | One command, two modes — inventory versus assessment, and which one you need |
| [Prerequisites](./prerequisites.md) | PowerShell version, required modules, and the .NET SDK some report tiers need |
| [Authentication](./authentication.md) | Five ways to sign in: interactive, device code, service principal with secret or certificate, and managed identity |
| [Usage](./usage.md) | Scope, output formats, category filtering, and worked examples |

## Control what runs

| Page | What it answers |
|---|---|
| [Permissions](./permissions.md) | The ARM roles and Graph permissions to request — and what you lose without each |
| [Category filtering](./category-filtering.md) | Scan a subset: `-Category Compute,Security,Networking` |
| [Parameters reference](./parameters.md) | Every parameter on `Invoke-AzureScout`, with defaults |

## After the run

| Page | What it answers |
|---|---|
| [Output files and formats](./output.md) | What lands on disk, where, and the run-folder layout |
| [Troubleshooting](./troubleshooting.md) | Run logs, common failures, and how to read a partial result |

## The one thing worth knowing up front

AzureScout is **read-only**. It never creates, modifies or deletes anything in the tenant.
`Reader` at the root management group is enough for the ARM side, and
`Invoke-AzureScout -PermissionAudit` tells you exactly which collectors will and will not
produce data **before** you commit to a full run — rather than leaving you to guess why a
worksheet came back empty.
