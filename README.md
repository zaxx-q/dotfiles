# dotfiles

My personal dotfiles and machine setup, managed with
[chezmoi](https://www.chezmoi.io/). One command turns a fresh Fedora, Arch,
Debian or macOS install into my environment: shell, editor and terminal
configs, scripts, packages, fonts and, on Fedora and Arch, the niri desktop
with Noctalia.

- **Configs** are real files in `~`, not symlinks into a clone. A few
  [symlinks](#symlinks) remain, on purpose.
- **Per machine facts** (distro, GUI or not, WSL, your name and email) are
  detected or asked for once by `chezmoi init`.
- **Setup** (packages, `/etc` files, services, fonts, mise languages, plugins,
  keys) is done by chezmoi run scripts, and re-runs on its own when what it
  depends on changes.
- **Settings** (package lists, mise languages, fonts, services, skip lists) are
  YAML files in [`home/.chezmoidata/`](home/.chezmoidata).

Contents: [New machine](#setting-up-a-new-machine) ·
[How it fits together](#how-it-fits-together) ·
[Workflow](#day-to-day-workflow) ·
[Command cheat sheet](#command-cheat-sheet) ·
[Symlinks](#symlinks) ·
[System files](#system-files) ·
[Repo layout](#whats-in-the-repo) ·
[Settings](#settings) ·
[Scripts and fonts](#scripts-and-fonts) ·
[Install scripts](#what-chezmoi-apply-runs) ·
[What's not in the repo](#whats-not-in-the-repo) ·
[Troubleshooting](#troubleshooting) ·
[Development](#development) ·
[Credits](#credits)

## Setting up a new machine

On a machine with nothing installed except `curl`:

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply zaxx-q
```

That downloads chezmoi into `~/.local/bin`, clones this repo, asks a few
questions, then applies everything. Things to know:

- **`zaxx-q` is short for `zaxx-q/dotfiles`.** With only a username, chezmoi
  looks for a repo called `dotfiles`. A repo with another name needs `user/repo`.
- **If the work is still on a branch**, add `--branch <name>` after `--apply`,
  for example `init --apply --branch wip zaxx-q`. It isn't needed once the
  branch is merged into `main`.
- **It clones over HTTPS**, because a fresh machine has no SSH key yet, so the
  repo has to be public. That's also why no secret is allowed in it, see
  [What's not in the repo](#whats-not-in-the-repo). After the first apply you can
  switch the remote to SSH for pushing:
  `chezmoi git -- remote set-url origin git@github.com:zaxx-q/dotfiles.git`.
- **Leave out `-b "$HOME/.local/bin"`** and the installer puts chezmoi in `./bin`
  and leaves it there. With it you keep a `chezmoi` command afterwards. If you
  prefer your package manager (`sudo dnf install chezmoi`,
  `sudo pacman -S chezmoi`, `brew install chezmoi`), install that and run just
  `chezmoi init --apply zaxx-q`.
- **Keep the `sh -c "$(curl ...)"` form** rather than `curl ... | sh`. The
  questions need your terminal.

`init` asks for your name and email (git), an optional GPG signing key id and,
on Arch and Fedora outside of WSL and containers, whether to set up the niri
desktop. The answers go to `~/.config/chezmoi/chezmoi.toml` and are never put
in this repo. To answer without a terminal:

```sh
chezmoi init --apply zaxx-q \
  --promptString "Full name (git user.name)=Jane Doe,Email address (git user.email)=jane@example.com,GPG signing key ID for git (leave empty to skip)=" \
  --promptBool "Set up the niri desktop environment and GUI apps=true"
```

`apply` asks for your sudo password (packages, `/etc` files, services, `chsh`)
and the first run takes a while. When it's done, log out and back in so the new
shell, groups and desktop session are picked up. To look before you leap, run
`chezmoi init zaxx-q` (no `--apply`) and then `chezmoi diff`, or
`chezmoi apply --exclude scripts` to only write files.

## How it fits together

| What | Where |
| :-- | :-- |
| **Source**: this repo, the desired state | `~/.local/share/chezmoi` (chezmoi's own files are in its `home/` folder, see `.chezmoiroot`) |
| **Destination**: the real thing | your home directory, `~` |
| **Config**: this machine's answers and overrides, never in git | `~/.config/chezmoi/chezmoi.toml` |
| **State**: which scripts already ran, and what chezmoi last wrote | `~/.config/chezmoi/chezmoistate.boltdb` |
| **Cache**: downloaded externals (tpm, ...) | `~/.cache/chezmoi` |

`chezmoi apply` makes the destination match the source. It never copies in the
other direction by itself. When you change something in `~` (or an app does),
you take it into the repo yourself with `chezmoi re-add` or `chezmoi add`.

Source file names say what a file becomes. The ones this repo uses:

| In the repo | In `~` |
| :-- | :-- |
| `dot_config/git/config` | `~/.config/git/config` (`dot_` becomes `.`) |
| `executable_foo` | `foo`, mode 755 |
| `dot_config/private_gnupg` | `~/.config/gnupg`, mode 700 (files 600) |
| `create_config.local.tmpl` | created once if missing, never overwritten afterwards |
| `symlink_foo.tmpl` | a symlink, the file's content is the link target |
| `foo.tmpl` | `foo`, after the Go template inside is rendered |

Prefixes can be combined, in a fixed order (see the
[naming reference](https://www.chezmoi.io/reference/source-state-attributes/)).
`chezmoi source-path ~/.zshenv` and `chezmoi target-path <source file>` convert
between the two names.

Templates see your machine's facts. Print them with `chezmoi data`:
`.distro` (`arch`, `debian`, `fedora`, `darwin`, `unsupported`), `.gui`, `.wsl`,
`.container`, `.name`, `.email`, plus everything in `home/.chezmoidata/`.

## Day to day workflow

**The loop.** Change something, look at it, save it in git:

1. Edit. Either `chezmoi edit --apply ~/.config/ghostty/config` (opens the
   repo's copy and applies when you quit), or `chezmoi cd` and edit there, then
   `chezmoi apply`. The `dfr` alias opens the repo in Zed.
2. Check with `chezmoi diff`.
3. Save: `chezmoi git -- add -A`, `chezmoi git -- commit -m "..."`,
   `chezmoi git -- push`. Or `chezmoi cd` and use git as usual.

**An app changed its own config** (Zed, the pi agent, ...). Run `chezmoi diff`,
then `chezmoi re-add` to take the new version into the repo, then commit.
`re-add` skips templates, so use `chezmoi merge <target>` for those. A few files
are only created, never overwritten, so edit them freely on a machine:
`~/.config/mise/config.toml`, `~/.config/git/config.local`,
`~/.config/ghostty/config.local`, `~/.config/niri/config.kdl.local`,
`~/.config/zsh/.zprofile.local`, `~/.config/lazygit/config.yml`,
`~/.config/xfce4/.../thunar.xml` and `~/.pi/agent/trust.json`.

**Start tracking a new file.** `chezmoi add ~/.config/foo/foo.conf`. Add
`--template` if it needs per machine values. Stop tracking with
`chezmoi forget <target>` (the file stays in `~`). You can add a whole folder
such as `~/.pi/agent`: the runtime files in it (sessions, auth, caches, ...) are
listed at the bottom of `home/.chezmoiignore`, so chezmoi skips them with a
warning. When a program starts writing a new kind of runtime file, add its path
there. Don't `chezmoi add` a file that is already a template, chezmoi stops to
ask because it would turn the template into a plain file.

**Add or remove a package, language, font or service.** Edit
`home/.chezmoidata/packages.yaml` or `system.yaml`, then `chezmoi apply`. The
install scripts run again on their own because their rendered text changed. For
one machine only, put the change in `~/.config/chezmoi/chezmoi.toml`, see
[Settings](#settings).

**Pull changes from another machine.** `chezmoi update` pulls the repo and
applies it. `chezmoi git -- pull` only pulls, so you can run `chezmoi diff`
first.

**A second or third machine.** Run the one-line command from
[Setting up a new machine](#setting-up-a-new-machine). Change something on one,
push, then `chezmoi update` on the others.

**See what's going on.** `chezmoi status` (what differs), `chezmoi managed`
(what chezmoi owns), `chezmoi unmanaged ~/.config` (what it doesn't),
`chezmoi doctor` (problems), `chezmoi cat <target>` (what a file will look like
after rendering).

**Run the install scripts again.** After swapping hardware, or to repair a
half-finished install:

```sh
chezmoi state delete-bucket --bucket=scriptState
chezmoi apply
```

## Command cheat sheet

Set up and sync:

| Command | What it does |
| :-- | :-- |
| `chezmoi init <user/repo>` | Clone the repo, ask the questions, write the config |
| `chezmoi init --apply <user/repo>` | The same, then apply |
| `chezmoi init --prompt` | Ask the questions again, with the current config in place |
| `chezmoi apply` | Make `~` match the repo |
| `chezmoi apply -n -v` | Dry run, shows what it would do |
| `chezmoi apply --exclude scripts` | Write files only, skip the install scripts |
| `chezmoi apply <target>` | Apply one file or directory |
| `chezmoi apply --refresh-externals` | Download tpm and other externals again |
| `chezmoi update` | `git pull --rebase`, then apply |
| `chezmoi upgrade` | Upgrade chezmoi itself (when installed with the script) |

Look:

| Command | What it does |
| :-- | :-- |
| `chezmoi status` | One line per file that differs, like `git status` |
| `chezmoi diff` | The differences, and the scripts that would run |
| `chezmoi verify` | Exit code 0 when `~` matches the repo |
| `chezmoi managed` | Everything chezmoi manages (`-i files` to narrow it) |
| `chezmoi unmanaged [dir]` | Files in `~` that aren't tracked |
| `chezmoi ignored` | Targets this machine skips (`.chezmoiignore`) |
| `chezmoi cat <target>` | A file as chezmoi would write it |
| `chezmoi data` | The template data for this machine |
| `chezmoi source-path [target]` | Where the repo (or a file's source) is |
| `chezmoi doctor` | Checks the setup |

Change:

| Command | What it does |
| :-- | :-- |
| `chezmoi edit <target>` | Edit the repo's copy of a file (`--apply`, `--watch`) |
| `chezmoi edit-config` | Edit `~/.config/chezmoi/chezmoi.toml` |
| `chezmoi cd` | A shell inside the repo (`exit` to leave) |
| `chezmoi git -- <args>` | Run git in the repo |
| `chezmoi add <path>` | Start tracking a file or directory (`--template`) |
| `chezmoi re-add` | Take changed files from `~` into the repo, not templates |
| `chezmoi merge <target>` | Merge the file in `~` with the repo's version in your merge tool, for templates |
| `chezmoi forget <target>` | Stop tracking, keep the file |
| `chezmoi execute-template '{{ .distro }}'` | Try a template expression |
| `chezmoi state delete-bucket --bucket=scriptState` | Make every script run again at the next apply |

Handy flags: `-n` dry run, `-v` verbose, `--force` no prompts, `-i` / `-x`
include or exclude entry types (`files`, `dirs`, `symlinks`, `scripts`,
`externals`, ...).

## Symlinks

Most files are real files now, including the ones outside of `~` (`/etc/dnf/dnf.conf`,
keyd's config, ...). Nothing links into the repo. Symlinks are still used where
a link is the point:

| Link | Points to | Why |
| :-- | :-- | :-- |
| `~/.XCompose` | `~/.config/XCompose` | Programs look in `~/.XCompose`, the file is kept in `~/.config` |
| `~/.local/bin/local/{node,npm,pnpm,yarn}` | `~/.local/share/mise/installs/bun/latest/bin/bun` | bun stands in for node and its package managers |
| `~/.local/bin/local/npx` | `.../bun/latest/bin/bunx` | Same, for `npx` |
| `/etc/resolv.conf` | `/run/systemd/resolve/stub-resolv.conf` | systemd-resolved. Made by a script, with `sudo`, on Arch and Fedora outside WSL and containers |

The bun links are chezmoi `symlink_` entries. They show up as dangling until
the mise script has installed bun, which is fine. `~/.XCompose` is one too.
`resolv.conf` is created by `run_onchange_after_10-system-files`, because chezmoi
only manages `~`.

## System files

chezmoi only manages `~`, so files such as `/etc/greetd/config.toml` live in
`home/.system/` (chezmoi ignores that folder) and the `after_10-system-files`
script copies them with `sudo`. Everything in `home/.system/files/<scope>/` is
installed to the same path under `/`:

| Folder | Installed on |
| :-- | :-- |
| `files/all/` | every Linux machine |
| `files/gui/` | machines with the desktop (`gui = true`) |
| `files/fedora/`, `files/arch/`, `files/debian/` | that distro |
| `files/fedora-gui/`, `files/arch-gui/`, `files/debian-gui/` | that distro, with the desktop |

So `home/.system/files/fedora-gui/etc/greetd/config.toml` ends up as
`/etc/greetd/config.toml` on a Fedora desktop. A file that is executable in the
repo is installed with mode 755, the others with 644.

**Add a file**, from the repo (`chezmoi cd`):

```sh
./run sys:add --scope fedora-gui /etc/greetd/config.toml
```

That copies it to the right folder (`sudo` is only used for a file you can't
read), commit it and the next `chezmoi apply` installs it. Run the command again
to update the copy after you changed the file in `/etc`. Files that aren't world
readable are refused unless you add `--force`, since they may hold secrets and
the repo is public. The script runs again by itself when a file in a scope of
the machine changes.

**Compare** with what's installed: `./run sys:diff` shows what differs between
the repo and `/` on this machine and exits with 1 if anything does. It's one
way: edits made in `/etc` aren't picked up until you `sys:add` the file again.

Things to know: a file you remove from the repo stays on the machines that
already have it. The first time a different real file gets replaced, a `.bak`
copy is kept next to it. A few files that need a condition (keyd, `dnf.conf`,
the niri session, WSL) are still listed by hand in the script instead.

## What's in the repo

| Path | What it is |
| :-- | :-- |
| `home/` | The chezmoi source (`.chezmoiroot` points here) |
| `home/dot_*`, `home/private_*`, `home/executable_*`, ... | Files for `~`, with chezmoi's [naming](https://www.chezmoi.io/reference/source-state-attributes/) |
| `home/.chezmoi.toml.tmpl` | Detects the machine and asks the `init` questions |
| `home/.chezmoidata/` | Settings: packages, mise, fonts, services, skip lists |
| `home/.chezmoiignore` | Which targets a machine doesn't get (desktop-less, skipped, ...) |
| `home/.chezmoiexternal.toml.tmpl` | Things chezmoi downloads (tpm, scripts from GitHub) |
| `home/.chezmoiscripts/` | The install scripts |
| `home/.chezmoitemplates/` | Shared bits for the scripts (shell prelude, package lists) |
| `home/.system/` | Files that go outside of `~`, copied by a script. `files/<scope>/` is installed to `/` automatically, see [System files](#system-files) |
| `_docs/` | Notes on the package lists and the optional scripts, plus a one-off helper that moved a machine off an old symlink based setup |
| `run` | Lint and format helper, also what CI runs |

Only `dot_config/zsh/dot_xdg.local.tmpl` and a few other `*.tmpl` configs that
need your home directory or your machine's facts are templates. Everything else
is copied as is.

## Settings

Settings that apply to every machine live in `home/.chezmoidata/`. A single
machine can override any of them in the `[data]` table of
`~/.config/chezmoi/chezmoi.toml` (`chezmoi edit-config`). Overrides are kept
when `chezmoi init` runs again. Lists are replaced, not merged. For example:

```toml
[data]
  autostart_niri = false    # `exec uwsm start` from the TTY login

  [data.packages.fedora]
    cli_extras = ["keyd", "trans", "earlyoom"]
```

`packages.yaml` holds the package lists per distro
(`packages.<distro>.{cli,gui,aur,aur_gui,brew,cask}`, each with `_extras` and
`_skip` variants) and the package manager options. `system.yaml` holds the mise
languages, fonts, external scripts, services, sudoers entries, udev rules, XDG
user directories and `skip.targets` / `skip.system`, the config files a machine
doesn't get.

What's chosen right now: the Fedora desktop packages I skip, mise `node` and
`python` skipped (so `bun` and `uv` are installed instead), every external
script skipped, and the `keyd`, `trans` and `earlyoom` extras.

## Scripts and fonts

**Scripts in the repo.** Everything in `home/dot_local/bin/` is deployed to
`~/.local/bin`, and `home/dot_local/bin/local/` to `~/.local/bin/local`. Both
are on your `PATH`, `local` first. The desktop-only ones (screen recording,
window launchers, ...) are only deployed when `gui = true`, the list is in
`.chezmoiignore`.

**nickjj's tools** (`bmsu`, `invoice`, `lcurl`, `notes`, `plutus`, `wait-until`
and `webserver`, described in [`_docs/scripts.md`](_docs/scripts.md)) aren't in
the repo. chezmoi downloads them from GitHub into `~/.local/bin`, except the ones
listed in `external_scripts.skip` in `home/.chezmoidata/system.yaml`. I skip all
seven, so none are installed. To install some, remove their
names from that `skip` list (or, for one machine only, put
`[data.external_scripts]` with `skip = []` in `chezmoi.toml`) and run
`chezmoi apply`. The version is part of each URL, change it to upgrade and run
`chezmoi apply --refresh-externals`.

**Your own scripts.** Create the script, make it executable and let chezmoi
take it over:

```sh
vim ~/.local/bin/myscript && chmod +x ~/.local/bin/myscript
chezmoi add ~/.local/bin/myscript     # becomes home/dot_local/bin/executable_myscript
chezmoi git -- add -A && chezmoi git -- commit -m "Add myscript" && chezmoi git -- push
```

Use `~/.local/bin/local/` the same way if you like to keep yours apart. A script
you don't `chezmoi add` stays on that machine only, chezmoi never touches files it
doesn't manage (`chezmoi unmanaged ~/.local/bin` lists them). For a script that
should only exist on desktops, also add its path to the `{{ if not .gui }}` list
in `.chezmoiignore`. `./run lint` shellchecks anything with a shebang.

**Fonts** come from `fonts` in `home/.chezmoidata/system.yaml`: a download URL and
the file name patterns to take from the archive. The `after_31-fonts` script
downloads them into `~/.local/share/fonts` and runs `fc-cache`, and runs again
when the list changes. You get Inconsolata Nerd Font, Inter and Fira Code. Add a
font under `fonts.extras`. A font is skipped when files matching its patterns are
already installed, so when you upgrade one, delete the old files first. On WSL
the fonts are only staged in `/tmp/dfr-fonts` and the script prints the steps to
install them on Windows.

## What `chezmoi apply` runs

Scripts live in `home/.chezmoiscripts/`. `run_onchange_*` ones run again only
when their rendered content changes, which includes the package lists or files
they depend on. To force them all to run again, see
[Day to day workflow](#day-to-day-workflow).

| Script | Does |
| :-- | :-- |
| `before_00-create-dirs` | Creates the directories programs expect |
| `before_10-install-packages` | Packages for Fedora, Arch (pacman + AUR), Debian and macOS, GPU / Wi-Fi / Bluetooth detection, RPM Fusion, Terra, COPRs, mise |
| `after_10-system-files` | `/etc` and `/usr/share` files from `home/.system/` (all of `files/<scope>/`), resolv.conf, WSL files, masked units |
| `after_20-sudoers-udev` | sudoers.d entries (checked with `visudo`) and udev rules, if any are set |
| `after_21-services-groups` | Enables services and adds you to `docker` / `libvirt` (desktop only) |
| `after_22-docker-desktop` | `pass init` for Docker Desktop, only if you added that package |
| `after_30-mise` | Languages (and Debian CLI tools) with `mise use --global` |
| `after_31-fonts` | Downloads the fonts from `fonts.*` |
| `after_32-tmux-plugins` | `tpm` plugins, runs when `tmux.conf` changes |
| `after_33-zsh-plugins` | antidote and the zsh plugins, runs when `.zsh_plugins.txt` changes |
| `after_40-default-shell` | Adds zsh to `/etc/shells` and runs `chsh` |
| `once_after_41` / `42` | SSH key and GPG key, only if you don't have them |

chezmoi downloads `tpm` and the scripts in `external_scripts` itself, see
`.chezmoiexternal.toml.tmpl`. Refresh them with `chezmoi apply --refresh-externals`.

GPU, Wi-Fi and Bluetooth detection happens when the packages script runs. If you
swap hardware, force the scripts to run again.

## What's not in the repo

Anything secret or generated at runtime stays on the machine and is not
tracked: `~/.pi/agent/{.env,auth.json,mcp-auth.json,cliproxyapi*.json}` and the
pi caches, shell history, Noctalia's generated theme files (niri's
`noctalia.kdl`, the ghostty / tmux / fzf / zed / pi themes), SSH and GPG keys.
The last section of `home/.chezmoiignore` lists them so `chezmoi add` skips them,
and the `.gitignore` is a second safety net. The repo is public, so
if you ever want secrets in it, use chezmoi's
[age or password manager support](https://www.chezmoi.io/user-guide/encryption/),
not plain files. Your name and email aren't in it either, they live in
`~/.config/chezmoi/chezmoi.toml`.

The desktop config assumes Noctalia is installed and running. niri's
`config.kdl` has `include "noctalia.kdl"`, a file Noctalia writes, and niri
reports a config error when an included file is missing. On a fresh machine run
`touch ~/.config/niri/noctalia.kdl` before the first niri login if Noctalia
hasn't created it yet.

## Troubleshooting

- **`chezmoi init` waits forever, or fails without a terminal.** It's waiting for
  an answer. Pass the questions as flags, see
  [Setting up a new machine](#setting-up-a-new-machine). The flag name is the
  exact question text.
- **"config file template has changed".** Run `chezmoi init`. Your answers and
  overrides are kept.
- **chezmoi asks before overwriting a file.** It changed since chezmoi last
  wrote it. Answer no, look at `chezmoi diff`, then take your change into the
  repo with `chezmoi re-add` (or `chezmoi merge` for templates).
- **A script failed.** Read its output, fix the cause, run `chezmoi apply`
  again. If it doesn't run again, clear the script state as described above.
- **Wrong repo found.** `chezmoi init <name>` means `<name>/dotfiles`. Use
  `user/repo` for a repo with another name.
- **Starting over on one machine.** `chezmoi purge` removes chezmoi's source,
  config and state (not the files it wrote). Then run the init command again.

## Development

```sh
./run lint            # shellcheck and ruff
./run chezmoi:check   # render every script for several machine profiles and shellcheck them
./run ci:test
```

`chezmoi:check` needs `chezmoi` and `shellcheck` on your path.

CI (`.github/workflows/ci.yml`) runs `./run ci:test` on pushes to `main`, on pull
requests and on demand from the Actions tab. `./run format` needs a recent
`shfmt`: Fedora's package (3.7) is too old for the `.editorconfig`, so use
`mise exec shfmt@3.14.1 -- ./run format`.

## Credits

This started as a fork of [nickjj/dotfriedrice](https://github.com/nickjj/dotfriedrice)
(MIT, see [LICENSE](LICENSE)). The package lists, many of the scripts and the
layout of the configs come from there. The optional scripts in
`external_scripts` are nickjj's own projects.
