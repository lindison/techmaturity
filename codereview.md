# Codex Review

Target: branch diff against main

The patch introduces publicly reachable destructive data reset behavior, unsafe server-side repository assessment inputs, and breaks existing DELETE links by removing Rails UJS without updating callers. These are functional and security issues that should be fixed before considering the patch correct.

Full review comments:

- [P1] Gate the database reset endpoint — /home/lindis/git/techmaturity/app/controllers/static_controller.rb:48-48
  Because this falls back to the hard-coded PIN `8805`, any deployment that does not explicitly set `RESET_PIN` exposes a publicly reachable `/data/reset` action that deletes all products/scores/tags. The data page is also linked in the main nav and there is no authentication or environment guard, so production data can be wiped by anyone who knows or reads the default PIN.

- [P1] Restrict repository assessment inputs — /home/lindis/git/techmaturity/app/services/repo_assessment_service.rb:68-71
  When `repo` is supplied on the public new-score page, these branches let the server either clone an arbitrary URL or inspect any local directory path. In production this enables SSRF-style requests to internal Git/HTTP endpoints and leaks whether local server paths exist (plus detected findings), so this needs to be limited to trusted users and/or a safe allowlist of public repository URLs.

- [P2] Preserve non-GET link handling — /home/lindis/git/techmaturity/app/views/layouts/application.html.erb:31-31
  Switching the layout to only load the importmap means Rails UJS is no longer loaded, but existing links such as `link_to ..., method: :delete` for removing assets and tags still depend on Rails UJS. In browsers those links now issue normal GET requests instead of DELETE, so the remove actions stop working unless the links are converted to Turbo's `data-turbo-method`/`button_to` or Rails UJS is imported.
