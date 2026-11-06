#!/bin/bash
# Build the apt repository tree in $OUT from the GitHub Release assets of the
# repositories listed in packages.txt. Needs: gh (authenticated, GH_TOKEN),
# dpkg-dev, apt-utils, gpg with the signing key imported.
#
#   scripts/build-repo.sh <out-dir>
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "${1:?out dir}"; OUT="$(cd "$1" && pwd)"   # absolute: the script cds into it
SUITE="${SUITE:-trixie}"; COMPONENT="main"; ARCHES="amd64 arm64 armhf"
ORIGIN="martinmunk"; LABEL="martinmunk packages"
POOL="$OUT/pool/$COMPONENT"; DISTS="$OUT/dists/$SUITE"
mkdir -p "$POOL" "$DISTS"

echo "== downloading release assets"
grep -v -E '^\s*(#|$)' "$HERE/packages.txt" | while read -r repo; do
    mkdir -p "$POOL/$(basename "$repo")"
    gh release list -R "$repo" --limit 200 --json tagName -q '.[].tagName' | while read -r tag; do
        gh release download "$tag" -R "$repo" -p '*.deb' -D "$POOL/$(basename "$repo")" --skip-existing
    done
done
find "$POOL" -name '*.deb' | sort | sed 's/^/  /'

echo "== indexing"
cd "$OUT"
for arch in $ARCHES; do
    d="dists/$SUITE/$COMPONENT/binary-$arch"; mkdir -p "$d"
    # --arch includes Architecture: all packages in every per-arch index.
    dpkg-scanpackages --multiversion --arch "$arch" pool > "$d/Packages"
    gzip -9knf "$d/Packages"
done
cat > /tmp/apt-release.conf <<CONF
APT::FTPArchive::Release {
  Origin "$ORIGIN"; Label "$LABEL"; Suite "$SUITE"; Codename "$SUITE";
  Architectures "$ARCHES"; Components "$COMPONENT";
  Description "Debian packages from github.com/martinmunk, built by GitHub Actions";
};
CONF
apt-ftparchive -c /tmp/apt-release.conf release "dists/$SUITE" > "dists/$SUITE/Release"

echo "== signing"
gpg --batch --yes --armor --detach-sign -o "dists/$SUITE/Release.gpg" "dists/$SUITE/Release"
gpg --batch --yes --clearsign -o "dists/$SUITE/InRelease" "dists/$SUITE/Release"
cp "$HERE/martinmunk-apt.gpg" "$HERE/martinmunk-apt.asc" "$OUT/"
cp "$HERE/site/index.html" "$OUT/index.html"
{ echo "Packages in $SUITE/$COMPONENT:"
  # grep exits 1 on an empty index (no releases yet); that is not an error.
  grep -h -E '^(Package|Version|Architecture): ' "dists/$SUITE/$COMPONENT"/binary-amd64/Packages | paste - - - || true
} > "$OUT/packages.txt"
echo "== done"; find "$OUT" -maxdepth 4 -type f | sort | sed 's/^/  /'
