# Source customization and offline rebuild workflow

The original offline kit already has editable Git worktrees under `sources/`. The new companion repository should **not** duplicate them as untracked copies. Record upstream SHAs in `versions/source-commits.txt` and track your changes as patches or forks.

## Safe workflow

1. Inspect `git -C "$OFFLINE_KIT_ROOT/sources/emqx" status --short` before editing; record upstream SHA.
2. Create an ordinary local branch from the pinned source commit (on your VM), e.g. `git -C "$OFFLINE_KIT_ROOT/sources/emqx" switch -c offline-custom-emqx` if you have not previously branched.
3. Modify code in EMQX, Kafka or ThingsBoard. Do not edit their live compiled releases directly.
4. Commit your source changes **inside that project's local Git worktree**, then export commits as patches. Example: `git -C "$OFFLINE_KIT_ROOT/sources/emqx" format-patch b0604926195f9372b0068b61f88d409d639a2401 -o "$OFFLINE_DEVKIT_ROOT/patches/emqx"`.
5. The companion repository stores these patches, unit tests and manifest; larger long-lived changes should use dedicated Git forks, not huge patch series.
6. Rebuild with Internet disabled in a disposable/staged working copy. Run targeted tests before touching live runtime binaries.
7. Preserve and verify PostgreSQL, Kafka, EMQX node data and device secrets; deploy a new runtime build with rollback capability.

**Reapply** on another restored kit using `git am` in matching source tree, after ensuring correct base SHA and a clean worktree. Do not apply patches to a mismatched upstream version.

## Assets not in Git

Compiled releases, toolchain images, per-project dependency caches, offline RPM repos and source bundles belong in checksummed GitHub Release assets, subject to license and hosting limits. Never include customer data or tokens.
