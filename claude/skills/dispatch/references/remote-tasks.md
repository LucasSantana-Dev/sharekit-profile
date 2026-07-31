# Named Remote Tasks

Placeholders resolve per the substitution contract in [../SKILL.md](../SKILL.md)
execution flow: `<homelab>` = homelab SSH alias, `<project-a>` = the project-a
repo name. Substitute both before running any mapped script.

| Alias         | Script                       |
|---------------|------------------------------|
| ci-watch      | ci-watch.sh                  |
| pr-triage     | pr-triage.sh                 |
| release-check | <project-a>-release-check.sh       |
| dependabot    | dependabot-report.sh         |
| health        | <project-a>-health.sh              |
| drift         | <homelab>-drift.sh             |
| security      | security-hygiene.sh          |
| sync          | workspace-sync.sh            |
| self-update   | agent-self-update.sh         |
| weekly        | weekly-health-score.sh       |
