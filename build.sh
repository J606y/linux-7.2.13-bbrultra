#!/bin/bash
# Build Linux 7.2.13 with BBR Ultra.
# Requires curl, tar, sha256sum, python3, and a kernel bindeb-pkg toolchain
# (gcc, make, bc, bison, flex, libssl, libelf, dwarves, rsync, dpkg-dev).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
WORKDIR=${WORKDIR:-"$ROOT/build"}
mkdir -p "$WORKDIR"
cd "$WORKDIR"

TARBALL=linux-7.2.13.tar.xz
EXPECT=08e7b0c4f2dd1971f972da274b5e589a98989390ac56acd7a1a5af922363ea6c
URL=https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.2.13.tar.xz

if [ ! -f "$TARBALL" ] || [ "$(sha256sum "$TARBALL" | awk '{print $1}')" != "$EXPECT" ]; then
  curl -fL --retry 3 --retry-delay 2 -o "$TARBALL.partial" "$URL"
  mv "$TARBALL.partial" "$TARBALL"
fi
GOT=$(sha256sum "$TARBALL" | awk '{print $1}')
if [ "$GOT" != "$EXPECT" ]; then
  echo "sha256 mismatch" >&2
  exit 1
fi

rm -rf linux-7.2.13
tar -xf "$TARBALL"
cd linux-7.2.13
cp -f "$ROOT/tcp_bbrultra.c" net/ipv4/tcp_bbrultra.c

python3 - <<'PY'
from pathlib import Path

mk = Path("net/ipv4/Makefile")
text = mk.read_text()
needle = "obj-$(CONFIG_TCP_CONG_BBR) += tcp_bbr.o\n"
insert = needle + "obj-$(CONFIG_TCP_CONG_BBRULTRA) += tcp_bbrultra.o\n"
if "tcp_bbrultra.o" not in text:
    if needle not in text:
        raise SystemExit("Makefile anchor missing")
    mk.write_text(text.replace(needle, insert, 1))

kc = Path("net/ipv4/Kconfig")
text = kc.read_text()
if "TCP_CONG_BBRULTRA" not in text:
    anchor = "config TCP_CONG_BBR\n"
    if anchor not in text:
        raise SystemExit("Kconfig anchor missing")
    block = (
        "config TCP_CONG_BBRULTRA\n"
        "\ttristate \"BBR Ultra TCP\"\n"
        "\tdefault y\n"
        "\thelp\n"
        "\t  BBR Ultra congestion control. Requires the fq qdisc.\n"
        "\n"
    )
    kc.write_text(text.replace(anchor, block + anchor, 1))
print("tree patched")
PY

cp -f "$ROOT/config-amd64" .config
# LOCALVERSION=-bbrultra is already written once in config-amd64.
# Do not set it again. A make LOCALVERSION= argument would append a second suffix.
grep -q '^CONFIG_LOCALVERSION="-bbrultra"$' .config
unset LOCALVERSION
make -j2 bindeb-pkg
