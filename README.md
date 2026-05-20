# winpharm-lib

## What this repository does

This repository stores pre-built binary files that the Winpharm .NET build pipeline depends on but cannot compile in a CI environment. Every time a file is updated and pushed to `master`, a GitHub Actions pipeline automatically publishes a new GitHub Release with all binaries attached as downloadable assets.

## Why it is structured this way

Several Winpharm dependencies are produced by proprietary toolchains or licensed third-party SDKs:

- **Datacap OCX files** (dsiEMVX, dsiPDCX, DSICLientX) — point-of-sale hardware SDK, vendor-supplied binaries.
- **POS and workflow libraries** (CommonLib, DBAccess, POSDatabase, WorkflowLib, POSCobolLib) — compiled from COBOL/legacy sources not available in this repository.
- **DevExpress components** (v24.2) — licensed UI framework, cannot be distributed as source.

Storing these in a dedicated repository allows the `winpharm-net` CI pipeline to download them at build time using a GitHub Release download step, keeping the build fully automated without requiring any local dependency installation on the runner.

## Branching strategy

- `master` — single permanent branch. Every push triggers the release pipeline.

## Contents

### OCX files (`ocx/`)

| File | Description |
|---|---|
| dsiEMVX.ocx | Datacap EMV payment hardware SDK |
| dsiPDCX.ocx | Datacap POS device control SDK |
| DSICLientX.ocx | Datacap client communication SDK |

### DLL files (`dll/`)

| File | Description |
|---|---|
| CommonLib.dll | Shared utility library |
| DBAccess.dll | Database access layer |
| POSDatabase.dll | Point-of-sale database layer |
| WorkflowLib.dll | Workflow engine |
| POSCobolLib.dll | COBOL interop for POS |
| ExpressPharmLib.dll | DevExpress pharmacy UI components |
| ExpressPharmModel.dll | DevExpress data model components |
| DevExpress.Data.v24.2.dll | DevExpress core data library |
| DevExpress.Data.Desktop.v24.2.dll | DevExpress desktop data extensions |
| DevExpress.Drawing.v24.2.dll | DevExpress drawing library |
| DevExpress.Printing.v24.2.Core.dll | DevExpress print engine |
| DevExpress.Utils.v24.2.dll | DevExpress utilities |
| DevExpress.XtraEditors.v24.2.dll | DevExpress editor controls |
| DevExpress.XtraGrid.v24.2.dll | DevExpress grid control |
| DevExpress.XtraScheduler.v24.2.dll | DevExpress scheduler control |
| DevExpress.XtraScheduler.v24.2.Core.dll | DevExpress scheduler core |
| DevExpress.XtraScheduler.v24.2.Core.Desktop.dll | DevExpress scheduler desktop layer |

## Versioning

Every push to `master` triggers the pipeline. The version number is calculated automatically from commit messages using semantic versioning:

| Prefix | Effect |
|---|---|
| `bug:` | Patch increment (1.0.0 → 1.0.1) |
| `feat:` | Minor increment (1.0.0 → 1.1.0) |
| `BREAKING CHANGE` in body | Major increment (1.0.0 → 2.0.0) |

Unlike `winpharm-net` and `winpharm-cobol`, this repository does not detect changes per file — every release publishes all binaries regardless of what changed. This is intentional since the files here are stable dependencies that rarely change.

## Output

Each GitHub Release contains all OCX and DLL files as downloadable assets. The `winpharm-net` pipeline downloads them automatically using the GitHub CLI at build time.

## Initial version

`v1.0.0`
