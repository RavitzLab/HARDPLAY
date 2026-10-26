# Repository hygiene

The public tree contains buildable native and web source, tests, required branding/fonts and their notices, build scripts, CI and current documentation.

Excluded: personal playlists and audio, exported WAVs, build packages, caches, node_modules, local credentials/configuration, hosting project identities, design-generation prompts and unused branding drafts. Local working materials are retained outside the public export.

Run from the repository root:

```sh
python3 scripts/audit-source.py
```

CI runs the source audit before the web checks. Superseded runs on the same branch are canceled.

The audit checks the current tracked tree for disallowed artifacts and common credential/personal-path patterns. It is a targeted check, not a guarantee that every possible secret is detectable. Never commit personal `.hardplay` files, `.env` files or signed private URLs. Report a suspected credential privately; revoke it before considering history cleanup.

`scripts/export-source.sh` creates a curated checkout in `build/github-project/`. It copies only the public manifest, preserves that checkout's Git metadata, removes stale exported files and runs the audit. It does not delete the original working materials, push commits or publish a release.

Removing a file from the current tree does not remove earlier Git objects. Historical design drafts remain recoverable from Git; history is not rewritten by this cleanup. Build installers belong in Releases rather than Git source.
