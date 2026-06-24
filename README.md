# dotfiles

## GitHub token

`gh` and `git` share a single token, `GH_TOKEN`, sourced from a direnv `.envrc`
placed somewhere strategic (e.g. `/workspaces` in Codespaces). The credential
helper in `.gitconfig` routes `github.com` git auth through `gh`, which uses
`GH_TOKEN`. The PAT needs access to every repo/org you work with (`repo`,
`read:org`, `workflow`, `gist`, or the fine-grained equivalent).

The platform-managed `GITHUB_TOKEN` is left alone — in Codespaces it's reserved
for gpg commit signing.

## In Codespaces

Either activate the setting to automatically install dotfiles or run:

```sh
cd /workspaces
gh repo clone dotfiles
dotfiles/install.sh
<open new terminal>
```
