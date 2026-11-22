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

| What                                                              | Where                                                                                        |
| :---------------------------------------------------------------- | :------------------------------------------------------------------------------------------- |
| **Source**: this repo, the desired state                          | `~/.local/share/chezmoi` (chezmoi's own files are in its `home/` folder, see `.chezmoiroot`) |
| **Destination**: the real thing                                   | your home directory, `~`                                                                     |
| **Config**: this machine's answers and overrides, never in git    | `~/.config/chezmoi/chezmoi.toml`                                                             |
| **State**: which scripts already ran, and what chezmoi last wrote | `~/.config/chezmoi/chezmoistate.boltdb`                                                      |
| **Cache**: downloaded externals (tpm, ...)                        | `~/.cache/chezmoi`                                                                           |

`chezmoi apply` makes the destination match the source. It never copies in the
other direction by itself. When you change something in `~` (or an app does),
you take it into the repo yourself with `chezmoi re-add` or `chezmoi add`.

Source file names say what a file becomes. The ones this repo uses:

| In the repo                | In `~`                                                |
| :------------------------- | :---------------------------------------------------- |
| `dot_config/git/config`    | `~/.config/git/config` (`dot_` becomes `.`)           |
| `executable_foo`           | `foo`, mode 755                                       |
| `dot_config/private_gnupg` | `~/.config/gnupg`, mode 700 (files 600)               |
| `create_config.local.tmpl` | created once if missing, never overwritten afterwards |
| `symlink_foo.tmpl`         | a symlink, the file's content is the link target      |
| `foo.tmpl`                 | `foo`, after the Go template inside is rendered       |

Prefixes can be combined, in a fixed order (see the
[naming reference](https://www.chezmoi.io/reference/source-state-attributes/)).
`chezmoi source-path ~/.zshenv` and `chezmoi target-path <source file>` convert
between the two names.

Templates see your machine's facts. Print them with `chezmoi data`:
`.distro` (`arch`, `debian`, `fedora`, `darwin`, `unsupported`), `.gui`, `.wsl`,
`.container`, `.name`, `.email`, plus everything in `home/.chezmoidata/`.

## Day to day workflow

**The loop.** Change something, look at it, save it in git:

1. Edit. Either `chezmoi edit --apply ~/.config/kitty/kitty.conf` (opens the
   repo's copy and applies when you quit), or `chezmoi cd` and edit there, then
   `chezmoi apply`. The `dfr` alias opens the repo in Kate.
2. Check with `chezmoi diff`.
3. Save: `chezmoi git -- add -A`, `chezmoi git -- commit -m "..."`,
   `chezmoi git -- push`. Or `chezmoi cd` and use git as usual.

**An app changed its own config** (the pi agent, ...). Run `chezmoi diff`,
then `chezmoi re-add` to take the new version into the repo, then commit.
`re-add` skips templates, so use `chezmoi merge <target>` for those. A few files
are only created, never overwritten, so edit them freely on a machine:
`~/.config/mise/config.toml`, `~/.config/git/config.local`,
`~/.config/kitty/kitty.conf.local`, `~/.config/niri/config.kdl.local`,
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

| Command                             | What it does                                              |
| :---------------------------------- | :-------------------------------------------------------- |
| `chezmoi init <user/repo>`          | Clone the repo, ask the questions, write the config       |
| `chezmoi init --apply <user/repo>`  | The same, then apply                                      |
| `chezmoi init --prompt`             | Ask the questions again, with the current config in place |
| `chezmoi apply`                     | Make `~` match the repo                                   |
| `chezmoi apply -n -v`               | Dry run, shows what it would do                           |
| `chezmoi apply --exclude scripts`   | Write files only, skip the install scripts                |
| `chezmoi apply <target>`            | Apply one file or directory                               |
| `chezmoi apply --refresh-externals` | Download tpm and other externals again                    |
| `chezmoi update`                    | `git pull --rebase`, then apply                           |
| `chezmoi upgrade`                   | Upgrade chezmoi itself (when installed with the script)   |

Look:

| Command                        | What it does                                         |
| :----------------------------- | :--------------------------------------------------- |
| `chezmoi status`               | One line per file that differs, like `git status`    |
| `chezmoi diff`                 | The differences, and the scripts that would run      |
| `chezmoi verify`               | Exit code 0 when `~` matches the repo                |
| `chezmoi managed`              | Everything chezmoi manages (`-i files` to narrow it) |
| `chezmoi unmanaged [dir]`      | Files in `~` that aren't tracked                     |
| `chezmoi ignored`              | Targets this machine skips (`.chezmoiignore`)        |
| `chezmoi cat <target>`         | A file as chezmoi would write it                     |
| `chezmoi data`                 | The template data for this machine                   |
| `chezmoi source-path [target]` | Where the repo (or a file's source) is               |
| `chezmoi doctor`               | Checks the setup                                     |

Change:

| Command                                            | What it does                                                                    |
| :------------------------------------------------- | :------------------------------------------------------------------------------ |
| `chezmoi edit <target>`                            | Edit the repo's copy of a file (`--apply`, `--watch`)                           |
| `chezmoi edit-config`                              | Edit `~/.config/chezmoi/chezmoi.toml`                                           |
| `chezmoi cd`                                       | A shell inside the repo (`exit` to leave)                                       |
| `chezmoi git -- <args>`                            | Run git in the repo                                                             |
| `chezmoi add <path>`                               | Start tracking a file or directory (`--template`)                               |
| `chezmoi re-add`                                   | Take changed files from `~` into the repo, not templates                        |
| `chezmoi merge <target>`                           | Merge the file in `~` with the repo's version in your merge tool, for templates |
| `chezmoi forget <target>`                          | Stop tracking, keep the file                                                    |
| `chezmoi execute-template '{{ .distro }}'`         | Try a template expression                                                       |
| `chezmoi state delete-bucket --bucket=scriptState` | Make every script run again at the next apply                                   |

Handy flags: `-n` dry run, `-v` verbose, `--force` no prompts, `-i` / `-x`
include or exclude entry types (`files`, `dirs`, `symlinks`, `scripts`,
`externals`, ...).

## Symlinks

Most files are real files now, including the ones outside of `~` (`/etc/dnf/dnf.conf`,
keyd's config, ...). Nothing links into the repo. Symlinks are still used where
a link is the point:

| Link                                      | Points to                                         | Why                                                                                            |
| :---------------------------------------- | :------------------------------------------------ | :--------------------------------------------------------------------------------------------- |
| `~/.XCompose`                             | `~/.config/XCompose`                              | Programs look in `~/.XCompose`, the file is kept in `~/.config`                                |
| `~/.local/bin/local/{node,npm,pnpm,yarn}` | `~/.local/share/mise/installs/bun/latest/bin/bun` | bun stands in for node and its package managers                                                |
| `~/.local/bin/local/npx`                  | `.../bun/latest/bin/bunx`                         | Same, for `npx`                                                                                |
| `/etc/resolv.conf`                        | `/run/systemd/resolve/stub-resolv.conf`           | systemd-resolved. Made by a script, with `sudo`, on Arch and Fedora outside WSL and containers |

The bun links are chezmoi `symlink_` entries. They show up as dangling until
the mise script has installed bun, which is fine. `~/.XCompose` is one too.
`resolv.conf` is created by `run_onchange_after_11-system-settings`, because chezmoi
only manages `~`.

## Files an app rewrites

Some apps change their own config every time they run, pi's
`lastChangelogVersion` and the extension versions it keeps, or the window
position that xarchiver saves in `mainwindow=`. chezmoi would show those files as modified all the time. For
them the repo keeps the wanted content in a hidden file, and a `modify_`
template puts the machine's own text back in just those lines:

| File on the machine               | Wanted content, in the repo              | Left alone on the machine                                             |
| :-------------------------------- | :--------------------------------------- | :-------------------------------------------------------------------- |
| `~/.pi/agent/settings.json`       | `home/dot_pi/agent/.settings.json`       | `"lastChangelogVersion"` and the `"extensionChangelogVersions"` block |
| `~/.config/xarchiver/xarchiverrc` | `home/dot_config/xarchiver/.xarchiverrc` | the `mainwindow=` line                                                |

`chezmoi status` is clean while only those parts moved and `chezmoi apply` keeps
them. The rest of the file is still managed, so any other change shows up and
is reverted as usual. It's copied byte for byte (pi writes no newline at the end
of its file, and neither does the copy), and a new machine gets the repo's
values until the app writes its own. The files and what is left alone are in
`home/.chezmoidata/keep.yaml`.

**Take changes from the app with `chezmoi re-add`**, as for any other file, all
of them or just one (`chezmoi re-add ~/.pi/agent/settings.json`). chezmoi
skips these files on its own, since their source is a template and not a copy of
the file, and it can't run a template backwards. So `chezmoi re-add` has a hook
(`home/.system/keep-readd.sh`) that does it: it copies the file of the machine
into the hidden file of the repo, except for the parts that the app rewrites by
itself, which stay as the repo has them, so git doesn't see them change. It
prints a line for each file it updated, then you commit.

The hooks are in `chezmoi.toml`, which `chezmoi init` writes, so run
`chezmoi init` once on each machine after you pull this. (It writes the whole
file again and only keeps `[data]`, so a section you added to it by hand,
outside of `[data]`, is gone.) `chezmoi add` on one of these files is refused by
the same script:
chezmoi would delete the `modify_` file and put a plain copy in its place, with
the lines that change on their own. Use `chezmoi re-add`. Without the hooks you
can do the same with `home/.system/keep-readd.sh [file...]`.

- To change the settings edit the hidden file next to the `modify_` file.
  `chezmoi edit` opens the `modify_` file, which only says where to look.
- To do the same for another file: rename its repo copy to a hidden name (chezmoi
  ignores those), add an entry to `home/.chezmoidata/keep.yaml` with that name
  and the regexes of what should be left alone, and add a `modify_` file next to
  it, copy one of the two. `chezmoi re-add` handles it from then on. The
  `modify_` file has no `.tmpl` ending, the `chezmoi:modify-template` line in it
  is what makes it a template that gets the current file as `.chezmoi.stdin`.
  `home/.chezmoitemplates/modify-keep` is the part that does the work.

## System files

chezmoi only manages `~`, so files such as `/etc/greetd/config.toml` live in
`home/.system/` (chezmoi ignores that folder) and the `after_10-system-files`
script copies them with `sudo`. Everything in `home/.system/files/<scope>/` is
installed to the same path under `/`:

| Folder                                                      | Installed on                             |
| :---------------------------------------------------------- | :--------------------------------------- |
| `files/all/`                                                | every Linux machine                      |
| `files/gui/`                                                | machines with the desktop (`gui = true`) |
| `files/fedora/`, `files/arch/`, `files/debian/`             | that distro                              |
| `files/fedora-gui/`, `files/arch-gui/`, `files/debian-gui/` | that distro, with the desktop            |

So `home/.system/files/fedora-gui/etc/greetd/config.toml` ends up as
`/etc/greetd/config.toml` on a Fedora desktop. A file that is executable in the
repo is installed with mode 755, the others with 644.

**Add a file**, from the repo (`chezmoi cd`):

```sh
./run sys:add --scope fedora-gui /etc/greetd/config.toml
```

That copies it to the right folder (`sudo` is only used for a file you can't
read), commit it and the next `chezmoi apply` installs it on the machines where
it differs. This is for a new file. After you changed one that is already in the
repo, `chezmoi re-add` takes the change, see below. Files that aren't world
readable are refused unless you add `--force`, since they may hold secrets and
the repo is public.

**`chezmoi status` and `chezmoi apply` look at `/etc` too.** chezmoi can't see
outside of `~`, so the script does it: while chezmoi reads the repo,
`home/.system/files-state.sh` compares each system file of this machine with
the installed one (without `sudo`). If they all match, the script renders to
nothing and chezmoi skips it, so `chezmoi status` is clean and `chezmoi apply`
doesn't ask for your password. If a file is missing, has other content or is a
symlink left over from the old setup, the script shows up in `chezmoi status`
as `R`, and `chezmoi apply` installs those files. chezmoi doesn't manage `/etc`,
so it can't diff those files. `chezmoi diff` leaves scripts out (`[diff]` in the
config, see [Settings](#settings)), and a hook (`home/.system/system-diff.sh`)
prints what would change after its own diff: a diff for each system file that is
out of date, the whole file for one that is missing, and nothing when they all
match. Without a hook, the top of the script has the same text. That covers a
file you deleted, one you edited in `/etc`, and one that changed in the repo
after a `chezmoi update`.

The repo wins. A change you made directly in `/etc` is replaced at the next
`chezmoi apply`: the difference is printed, and the first time a real file gets
replaced a `.bak` copy is kept next to it. Run `chezmoi re-add` first to keep
the edit.

**Take changes from `/etc` with `chezmoi re-add`**, as for the files in `~`.
chezmoi only knows `~`, so its `re-add` has a hook (`home/.system/keep-readd.sh`,
the one of [Files an app rewrites](#files-an-app-rewrites), nothing more to set
up) that copies the system files you changed into the repo, what `sys:add` does.
It prints a line for each file, then you commit. Some limits:

- It's the plain `chezmoi re-add`, with no path. chezmoi itself refuses a path
  outside of `~` (`not in destination directory`) before the hook gets to run,
  and a path in `~` such as `chezmoi re-add ~/.zshrc` means only that file. To
  take one system file, run the script by hand:
  `home/.system/keep-readd.sh /etc/kanata/config.kbd`.
- Only files that are in the list below. A new file is for `./run sys:add`.
- A file that changed in the repo since it was installed, say after a
  `git pull`, isn't overwritten with the old copy in `/etc`, you get a line
  that says so and `chezmoi apply` installs it. It's the same when it changed
  in both places, `./run sys:diff` shows the two. The script knows from the hash
  of what it installed last, which it keeps in `~/.local/state/dfr/system-files/`.
  Without one (a file that was never installed by it) the file is taken over, as
  chezmoi does for the files in `~`.
- A file that isn't world readable is left alone, it may hold secrets and the
  repo is public, `./run sys:add --force` does it.

**Compare** by hand: `./run sys:diff` shows what differs between the repo and
`/` on this machine and exits with 1 if anything does. It checks the same list
of files as `chezmoi apply`, and only uses `sudo` for a file you can't read. It
only looks, `chezmoi re-add` is what takes the changes.

Things to know:

- A file you remove from the repo stays on the machines that already have it.
- The list of files, with the conditions (kanata when it's one of your packages,
  `dnf.conf` on Fedora, the niri session, WSL), is
  `home/.chezmoitemplates/system-files`. Only the files of that list are checked.
- A file this user can't read (mode 600, or in a folder it can't enter) can't be
  compared without `sudo`. For those the script keeps the hash of the repo copy
  it installed last in `~/.local/state/dfr/system-files/`, and installs again when
  the repo copy changes. An edit made in `/etc` to such a file isn't noticed,
  `./run sys:diff` does see it.
- To go over every file, in sync or not: `DFR_SYSTEM_FILES_FORCE=1 chezmoi apply`.
- Not a copy of a file, so not part of this: `resolv.conf`, masked units and the
  Windows Terminal settings. `after_11-system-settings` does those, it's a
  normal `run_onchange_` script.

## What's in the repo

| Path                                                     | What it is                                                                                                                              |
| :------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------- |
| `home/`                                                  | The chezmoi source (`.chezmoiroot` points here)                                                                                         |
| `home/dot_*`, `home/private_*`, `home/executable_*`, ... | Files for `~`, with chezmoi's [naming](https://www.chezmoi.io/reference/source-state-attributes/)                                       |
| `home/.chezmoi.toml.tmpl`                                | Detects the machine and asks the `init` questions, and writes the hooks and `[diff]` settings of `chezmoi.toml`                         |
| `home/.chezmoidata/`                                     | Settings: packages, mise, fonts, services, skip lists                                                                                   |
| `home/.chezmoiignore`                                    | Which targets a machine doesn't get (desktop-less, skipped, ...)                                                                        |
| `home/.chezmoiexternal.toml.tmpl`                        | Things chezmoi downloads (tpm, scripts from GitHub)                                                                                     |
| `home/.chezmoiscripts/`                                  | The install scripts                                                                                                                     |
| `home/.chezmoitemplates/`                                | Shared bits for the scripts and files (shell prelude, package lists, the list of system files, `modify-keep`)                           |
| `home/.system/`                                          | Files that go outside of `~`, copied by a script. `files/<scope>/` is installed to `/` automatically, see [System files](#system-files) |
| `_docs/`                                                 | Notes on the package lists and the optional scripts, plus a one-off helper that moved a machine off an old symlink based setup          |
| `run`                                                    | Lint and format helper (also what CI runs), `sys:add` and `sys:diff` for the system files                                               |

Only `dot_config/zsh/dot_xdg.local.tmpl` and a few other `*.tmpl` configs that
need your home directory or your machine's facts are templates, apart from the
`modify_` files of [Files an app rewrites](#files-an-app-rewrites). Everything else
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

`[data]` is the only part of that file that is yours to edit. `chezmoi init`
writes the whole file again from `home/.chezmoi.toml.tmpl`, and the rest of it
comes from there: `[hooks]` (the ones of `chezmoi re-add`, `chezmoi add` and
`chezmoi diff`) and `[diff]`, which leaves scripts out of `chezmoi diff` and
pages it with `delta`. Any other section you add by hand, `[diff]` or `[git]`
for example, is gone at the next `chezmoi init`. To change one for every
machine, edit it in the template and run `chezmoi init` (chezmoi says "config
file template has changed" when you have to).

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
[Day to day workflow](#day-to-day-workflow). `after_10-system-files` is the
exception: it checks `/etc` itself, see [System files](#system-files).

| Script                       | Does                                                                                                                          |
| :--------------------------- | :---------------------------------------------------------------------------------------------------------------------------- |
| `before_00-create-dirs`      | Creates the directories programs expect                                                                                       |
| `before_10-install-packages` | Packages for Fedora, Arch (pacman + AUR), Debian and macOS, GPU / Wi-Fi / Bluetooth detection, RPM Fusion, Terra, COPRs, mise |
| `after_10-system-files`      | `/etc` and `/usr/share` files from `home/.system/` (all of `files/<scope>/`), only when one is missing or differs             |
| `after_11-system-settings`   | resolv.conf, masked units, the Windows Terminal settings on WSL                                                               |
| `after_20-sudoers-udev`      | sudoers.d entries (checked with `visudo`) and udev rules, if any are set                                                      |
| `after_21-services-groups`   | Enables services and adds you to `docker` / `libvirt` (desktop only)                                                          |
| `after_22-docker-desktop`    | `pass init` for Docker Desktop, only if you added that package                                                                |
| `after_30-mise`              | Languages (and Debian CLI tools) with `mise use --global`                                                                     |
| `after_31-fonts`             | Downloads the fonts from `fonts.*`                                                                                            |
| `after_32-tmux-plugins`      | `tpm` plugins, runs when `tmux.conf` changes                                                                                  |
| `after_33-zsh-plugins`       | antidote and the zsh plugins, runs when `.zsh_plugins.txt` changes                                                            |
| `after_40-default-shell`     | Adds zsh to `/etc/shells` and runs `chsh`                                                                                     |
| `once_after_41` / `42`       | SSH key and GPG key, only if you don't have them                                                                              |

chezmoi downloads `tpm` and the scripts in `external_scripts` itself, see
`.chezmoiexternal.toml.tmpl`. Refresh them with `chezmoi apply --refresh-externals`.

GPU, Wi-Fi and Bluetooth detection happens when the packages script runs. If you
swap hardware, force the scripts to run again.

## What's not in the repo

Anything secret or generated at runtime stays on the machine and is not
tracked: `~/.pi/agent/{.env,auth.json,mcp-auth.json,cliproxyapi*.json}` and the
pi caches, shell history, Noctalia's generated theme files (niri's
`noctalia.kdl`, the kitty / tmux / fzf / pi themes), SSH and GPG keys.
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
`shfmt`: on Fedora (where `shfmt` was retired in Fedora 45) and Debian, it is
installed via `mise` (`mise use --global shfmt`).

## Credits

This started as a fork of [nickjj/dotfriedrice](https://github.com/nickjj/dotfriedrice)
(MIT, see [LICENSE](LICENSE)). The package lists, many of the scripts and the
layout of the configs come from there. The optional scripts in
`external_scripts` are nickjj's own projects.
