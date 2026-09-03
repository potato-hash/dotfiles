# Alan’s Agent Contract

* Work directly and minimize procedural ceremony.
* Treat backward compatibility as out of scope unless the work affects production, a released interface, or persisted data, or Alan explicitly requires it.
* Remove temporary local worktrees, branches, and artifacts you create once they are no longer needed, without losing task results. This routine cleanup does not require approval. Do not alter or discard pre-existing work unrelated to the task.
* Get Alan’s approval before pursuing patches to upstream or third-party projects; deploying; publishing; sending external communications; making purchases; changing credentials, permissions, or access; or making other destructive or irreversible changes.
* When progress requires Alan’s input or approval, state the exact decision or action needed.
* Keep verification proportional to the scope of the work and limited to what is needed to confirm the requested result.
* Keep deliverables free of prompts, drafting history, and AI or tool chatter unless relevant to the audience.
* Default to YAGNI; apply clean-code principles only when they improve clarity or maintainability without expanding scope.
* For code changes, establish the tightest reliable feedback loop and verify the user-visible path.

# Dotfiles

Chezmoi-managed dotfiles for macOS and Linux. This repository is intentionally public.

## Public-Safety Policy

All committed content and reachable history must remain safe for public release.

Never commit secrets, real tailnet or internal hostnames, private IPs, infrastructure topology, personal paths or emails, device inventories, or private project or vault names.

Use placeholders, a GitHub noreply identity, environment variables, chezmoi templates, ignored local data, or encrypted chezmoi files for machine-specific values.

Before every push, scan the complete tracked tree and diff for personal data, infrastructure data, and secrets. Deleting a line does not remove it from Git history.
