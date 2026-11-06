# apt

The public apt repository for the Debian packages built from
[github.com/martinmunk](https://github.com/martinmunk), served by GitHub Pages at
<https://martinmunk.github.io/apt>.

## How it works

- Each package repository publishes its `.deb` as a **GitHub Release asset** on a
  `release/X.Y.Z` tag (built by that repo's own GitHub workflow, which the Forgejo
  push mirror triggers).
- `packages.txt` lists the repositories whose release assets are indexed here. It is
  opt-in: nothing is published until it is listed.
- `.github/workflows/pages.yml` downloads every `.deb` from those releases, runs
  `dpkg-scanpackages` / `apt-ftparchive`, signs `Release` with the repository key and
  deploys the tree to Pages. It runs every 6 hours, on every push to `main`, on
  demand, and immediately when a package repo sends a `package-released`
  `repository_dispatch` (the release workflows do that when they have an
  `APT_DISPATCH_TOKEN` secret).
- One suite, `trixie`, component `main`, architectures amd64/arm64/armhf;
  `Architecture: all` packages appear in every per-arch index.

## Using the repository

```
curl -fsSL https://martinmunk.github.io/apt/martinmunk-apt.gpg | sudo tee /usr/share/keyrings/martinmunk-apt.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/martinmunk-apt.gpg] https://martinmunk.github.io/apt trixie main" | sudo tee /etc/apt/sources.list.d/martinmunk.list
sudo apt update
```

## Signing key

`martinmunk-apt.gpg` (binary) and `martinmunk-apt.asc` (armored) are the public
part of the repository signing key (ed25519, "martinmunk apt repository"). The
private key exists only as the `GPG_PRIVATE_KEY` secret of the GitHub repo and in
the maintainer's offline backup; it is never committed.

## Adding a package

1. Give the package repo a `.github/workflows/release.yml` that builds the `.deb`
   and attaches it to a GitHub Release on `release/*` tags (copy
   avr-controld's).
2. Add the repo to `packages.txt` here.
3. The next run (or a manual **Run workflow**) publishes it.

## Local build

```
GH_TOKEN=... scripts/build-repo.sh /tmp/apt-out      # needs gh, dpkg-dev, apt-utils, and the key in gpg
```
