# Linux 7.2.13 BBR Ultra

这是 Linux 7.2.13 加上 BBR Ultra 拥塞控制。

基础源码在 kernel.org，文件是 `linux-7.2.13.tar.xz`，sha256 为 `08e7b0c4f2dd1971f972da274b5e589a98989390ac56acd7a1a5af922363ea6c`。本仓库只放改动和构建方法，不包含完整 Linux 源码树。

amd64 包在 Release v7.2.13-4：

- `linux-image-7.2.13-bbrultra_7.2.13-4_amd64.deb`
- `linux-headers-7.2.13-bbrultra_7.2.13-4_amd64.deb`
- `linux-libc-dev_7.2.13-4_amd64.deb`

aarch64 包还没有。

拥塞控制名是 `bbrultra`，需要 `fq`。随仓的 `config-amd64` 已内置 `bbrultra`，并把默认队列规则设为 `fq`。这份配置的默认拥塞控制仍是 `bbr`，使用前要显式切换：

```sh
sysctl net.ipv4.tcp_congestion_control=bbrultra
sysctl net.core.default_qdisc=fq
```

构建见 `build.sh`。它从 kernel.org 下载 7.2.13，校验上面的 sha256，把 `tcp_bbrultra.c` 放进 `net/ipv4/`，改 `net/ipv4/Makefile` 和 `net/ipv4/Kconfig`，使用随仓的 `config-amd64`，然后执行 `make -j2 bindeb-pkg`。`LOCALVERSION=-bbrultra` 已经写在 `config-amd64` 里，脚本不会再写一次。
