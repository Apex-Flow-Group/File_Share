#!/usr/bin/env bash
# Builds the Fedora package from this checkout: bash packaging/fedora/build_rpm.sh <version> <build>
# The RPM lands in build/rpm/. Nothing is installed.
set -euo pipefail
version="${1:?version, e.g. 2.0.4}"
build="${2:?build number, e.g. 2015}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

flutter build linux --release --build-name="$version" --build-number="$build"
bundle="$root/build/linux/x64/release/bundle"
cp LICENSE "$bundle/LICENSE"

top="$root/build/rpm/rpmbuild"
rm -rf "$top"
mkdir -p "$top"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
rpmbuild -bb packaging/fedora/apexsender.spec \
  --define "_topdir $top" \
  --define "app_version $version" \
  --define "app_build $build" \
  --define "bundle $bundle" \
  --define "pkgdir $root/packaging/fedora" \
  --define "icon $root/assets/images/ico.png"
cp "$top"/RPMS/x86_64/apexsender-*.rpm "$root/build/rpm/"
ls -l "$root"/build/rpm/apexsender-*.rpm
