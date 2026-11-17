# 红米 K20 Pro (raphael) 内核 GitHub Actions 构建流水线 · Evolution-X 版

> 内核源码换成 `Evolution-X-Devices/kernel_xiaomi_raphael`（默认分支 `cnb`，Linux **4.14.357-openela**），
> 产出 **AnyKernel3 直刷 zip**（未压缩 `Image` + 本次编译的 vendor 模块）。**不再产出 boot.img。**
>
> 两条独立 CI：**CI - SUSFS**（KernelSU Next + SUSFS v2.1.0）与 **CI - KernelSU Next**（只有 KSU Next）。

## 0. 这套流水线实际在编什么

| 项 | 值 | 依据 |
|---|---|---|
| 机型 | Redmi K20 Pro / Mi 9T Pro（`raphael` / `raphaelin`），SM8150，A-only | `ak3/anykernel.sh` 的 `device.name1/2`、`IS_SLOT_DEVICE=0` |
| 内核源码 | `https://github.com/Evolution-X-Devices/kernel_xiaomi_raphael` 分支 `cnb` | 分支默认值；`Makefile` 里 `VERSION=4 PATCHLEVEL=14 SUBLEVEL=357` |
| KernelSU | KernelSU **Next** `v3.4.0-legacy`（树内自带 `drivers/kernelsu`） | `drivers/kernelsu/Kbuild`：`KSU_GIT_VERSION := 3038`、`KSU_GIT_TAG := v3.4.0-legacy`，版本号 `30000+3038+289 = 33327` |
| SUSFS | **不内置**，由 `patches/susfs/` 打进树（SUSFS **v2.1.0**，取自 SOVIET 16.0-SUSFS） | `patches/susfs/{10,11,12}-*.patch`，CI 断言 `CONFIG_KSU_SUSFS=y` |
| 板级配置 | `vendor/sm8150-perf_defconfig` + `vendor/xiaomi/sm8150-common.config` + `vendor/xiaomi/raphael.config` | Evolution-X 设备树 `sm8150-common/BoardConfigCommon.mk:88-92`、`raphael/BoardConfig.mk:24` |
| 镜像格式 | **未压缩 `Image`**（`CONFIG_BUILD_ARM64_UNCOMPRESSED_KERNEL=y`）+ `BOARD_INCLUDE_DTB_IN_BOOTIMG` | 同一 BoardConfig：`BOARD_KERNEL_IMAGE_NAME := Image` |
| 工具链 | AOSP clang `clang-r547379`（crDroid prebuilt 镜像，可换） | `clang_tag` / `clang_branch` 输入 |
| 打包 | `osm0sis/AnyKernel3` + 本仓库的 `ak3/anykernel.sh`（只刷 boot + 覆盖 `/vendor/lib/modules`） | 见第 4 节 |
| 加速 | ccache（`actions/cache` 管 `.ccache`，上限 2G） | 见第 5 节 |

构建命令等价于：

```bash
make LLVM=1 LLVM_IAS=1 O=out ARCH=arm64 vendor/sm8150-perf_defconfig
# 合入 sm8150-common.config / raphael.config，打开 CONFIG_KSU(+SUSFS)，olddefconfig
make LLVM=1 LLVM_IAS=1 O=out ARCH=arm64 CC="ccache clang" -j$(nproc) Image modules
make LLVM=1 LLVM_IAS=1 O=out ARCH=arm64 INSTALL_MOD_PATH=modout INSTALL_MOD_STRIP=1 modules_install
```

## 1. 两条 CI 与文件分工

```
.github/workflows/
  build-evolutionx.yml   # 可复用引擎：workflow_call + workflow_dispatch（所有构建逻辑在这里）
  ci-susfs.yml           # 入口：flavor=susfs   -> KernelSU Next + SUSFS
  ci-ksunext.yml         # 入口：flavor=ksunext -> 只有 KernelSU Next
ak3/anykernel.sh         # 打包时覆盖到 AnyKernel3 仓库里的 anykernel.sh（devicecheck/BLOCK/do.modules）
patches/susfs/           # SUSFS v2.1.0 内核代码 + VFS 钩子 + KSU Next 驱动胶水（10/11/12 号）
patches/legacy-a11/      # 历史存档：PixelExperience eleven（4.14.190）那套 01-08 补丁，CI 不再使用
```

触发方式：

- **自动**：推到 `main` 时，改了引擎 / 入口 / `patches/susfs/**` / `ak3/**` 会分别触发对应 CI（两个入口的 `paths` 各自独立）。
- **手动单跑**：Actions → `CI - SUSFS` / `CI - KernelSU Next` → Run workflow。
- **手动挑 flavor**：Actions → `build-evolutionx` → Run workflow，`flavor` 选 `susfs` 或 `ksunext`，还能改 `kernel_ref` / `defconfig` / `fragments` / `clang_tag` 等。

产物：Actions run 的 artifact，名字形如 `raphael-evox-susfs-4.14.357-<commit8>-<UTC 时间>.zip`。

## 2. 输入参数（引擎 `build-evolutionx.yml`）

| 参数 | 默认 | 说明 |
|---|---|---|
| `flavor` | 必填（手动时可选 `susfs` / `ksunext`） | 决定是否打 `patches/susfs/*.patch`、是否打开 `CONFIG_KSU_SUSFS*` |
| `kernel_repo` | `https://github.com/Evolution-X-Devices/kernel_xiaomi_raphael` | 内核源码仓库 |
| `kernel_ref` | `cnb` | 4.14.357。想要 4.14.353 可以填 `15.0`（注意：那是 4.14.353，KSU/板级配置要自己核对） |
| `defconfig` | `vendor/sm8150-perf_defconfig` | 相对 `arch/arm64/configs` |
| `fragments` | `vendor/xiaomi/sm8150-common.config vendor/xiaomi/raphael.config` | 空格分隔，`merge_config.sh -m` 合入 |
| `localversion` | 空 | 留空 = 保持树的 `-perf`。**改动会让内核 release 变化**，一般不要动（见第 4 节） |
| `clang_tag` | `clang-r547379` | 换 clang 时改这个（比如 `clang-r522817`） |
| `clang_branch` | `15.0` | crDroid prebuilt 镜像的分支 |
| `ccache_enable` | `true` | 关掉直接用 clang |
| `release` | `false` | 构建成功后发 Release（tag `raphael-<flavor>-<run_number>`） |

## 3. 构建流程（引擎里每一步在干什么）

1. **Checkout builder**：本仓库进 `builder/`（补丁与 `ak3/anykernel.sh` 从这里取）。
2. **Free disk space + 装依赖**：删掉 runner 自带的大体积 SDK，装 `bc bison ccache cpio kmod libelf-dev libncurses-dev libssl-dev ...`。
3. **clang**：`actions/cache` 缓存 `toolchain/<clang_tag>`，未命中就从 `gitlab.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_<tag>` 拉（`rm -rf .git` 后进 cache）。
4. **ccache**：`actions/cache` 管 `.ccache`（key 带 flavor + defconfig），并用 `-Wno-error=...` 一串 KCFLAGS 压住 4.14 老代码在新 clang 下的告警（techpack 的 Kbuild 里写死了 `-Werror`）。
5. **clone 内核源码**：`git clone --depth=1 -b cnb ...`，打印 `KERNEL_VERSION` / commit，并断言 `arch/arm64/configs/vendor/sm8150-perf_defconfig` 与 `drivers/kernelsu/Kconfig` 存在。
6. **打补丁（仅 susfs flavor）**：按文件名顺序 `patch -p1 --fuzz=3` 套 `patches/susfs/*.patch`，然后逐项断言（`fs/susfs.c`、`fs/Makefile` 的 `CONFIG_KSU_SUSFS`、`Kconfig` 的 `config KSU_SUSFS`、`supercall.c` 的 `SUSFS_MAGIC`、`selinux.c` 的 `susfs_is_current_ksu_domain`、`core/init.c` 的 `susfs_init`）。ksunext flavor 反过来断言树里**没有** SUSFS。
7. **配置**：defconfig → merge fragments → `scripts/config` 打开 `KSU` + `KSU_MANUAL_HOOK`、关掉 `KSU_KPROBES_HOOK`/`KSU_SYSCALL_TABLE_HOOK` → susfs flavor 再自动把 `Kconfig` 里所有 `KSU_SUSFS*` 选项全开 → `olddefconfig` → 断言 `CONFIG_KSU=y`、`CONFIG_KSU_MANUAL_HOOK=y`、`CONFIG_THREAD_INFO_IN_TASK=y`、（susfs）`CONFIG_KSU_SUSFS=y`。
8. **编译**：`make ... Image modules`（注意 Evolution-X 要的是未压缩 `Image`，不是 `Image.gz-dtb`）。
9. **模块**：`modules_install` 到 `modout/`，再把 `.ko` 摊平成 `modflat/`（设备上的 `/vendor/lib/modules` 是平铺的）。
10. **打包**：clone `osm0sis/AnyKernel3`，覆盖 `ak3/anykernel.sh`，放 `Image` 与 `modules/vendor/lib/modules/*.ko`，`zip -r9` 出包并上传 artifact。

## 4. 为什么 zip 里还要带模块（重要）

只刷 boot 分区**不会**更新 `/vendor/lib/modules`，而模块加载要过两道闸：

- **vermagic**：模块里编着内核 release 串。这棵树 `CONFIG_LOCALVERSION_AUTO=y`，ROM 编出来的 release 是 `4.14.357-perf-g<hash>`，我们的构建只要 git 状态不同，hash 就不一样 → 模块被拒。
- **`CONFIG_MODULE_SIG_FORCE=y`**：模块必须由内核信任的 key 签名，我们自签的模块只有配我们自己的内核才行。

所以：内核和模块必须**同一次构建、一起刷**。CI 用 `INSTALL_MOD_STRIP=1 modules_install` 收集本次的 `.ko`，打进 `modules/vendor/lib/modules/`，`anykernel.sh` 里 `do.modules=1`、`do.systemless=0`，刷机时把 `.ko` 覆盖到 `/vendor/lib/modules`（AK3 会自己 remount rw 并修 SELinux 标签）。

如果 `/vendor` 写不进去（例如只在 KernelSU 管理器里刷 zip、没有 recovery），把 `ak3/anykernel.sh` 改成 `do.systemless=1`：AK3 会把这批模块做成一个 `ak3-helper` 的 KernelSU/Magisk 模块做 bind-mount 覆盖（前提是设备上已装 KSU/Magisk 管理器）。

**结论：不要单独拿一个 `Image` 去换 ROM 里的内核，也不要只刷 zip 里的 boot 部分。**

## 5. 刷写与回滚

raphael 是 A-only、无 `_a/_b`，boot header v2，dtb 在 boot.img 里、dtbo 单独一个分区：

- zip **只动两处**：`boot` 分区的 kernel（换成我们的 `Image`）与 `/vendor/lib/modules/*.ko`。
- **不动 dtbo**：`anykernel.sh` 里没有 `flash_dtbo`，`BOARD_INCLUDE_DTB_IN_BOOTIMG` 让 dtb 跟着 boot header 走，沿用 ROM 自带的即可。
- 刷法：TWRP / OrangeFox → 安装 zip → 重启。首次开机会比较久（模块与 KSU 初始化）。
- 回滚：刷 ROM 原包里的 `boot.img`（或者重刷 ROM 全量包）就能回到原内核；再进 `/vendor/lib/modules` 换回原模块（重刷 ROM 全量包最快）。
- KernelSU 管理器：内核是 **KernelSU Next v3.4.0-legacy**（版本号 33327，构建日志里 `-- KernelSU-Next version: 33327`），管理器装 `KernelSU-Next` 对应 `v3.4.0-legacy` 的 APK。

## 6. 常见问题

**`Image` 找不到 / 打出来的是 `Image.gz-dtb`**：Evolution-X 的 `BOARD_KERNEL_IMAGE_NAME := Image`（`CONFIG_BUILD_ARM64_UNCOMPRESSED_KERNEL=y`），`Image` 才是对的；`Image.gz-dtb` 是 SOVIET 那套树的格式，别混。

**susfs flavor 报「树里没有 KSU_SUSFS」**：说明补丁没套上（看前一步 `patch` 的 `Hunk FAILED`）。补丁是针对 `cnb`（4.14.357）做的，换 `kernel_ref` 到 `15.0` 之类要重新做补丁。

**`CONFIG_KSU_SUSFS` 没生效**：`KSU_SUSFS` 在 Kconfig 里 `depends on KSU && THREAD_INFO_IN_TASK`。这棵树 `arch/arm64/Kconfig:153` 已 `select THREAD_INFO_IN_TASK`，正常不会缺；缺了就是源码被换过。

**clang 版本不合**：`clang-r547379` 是 AOSP clang 19；4.14 老代码在更高版本上可能报新的 error（我们只用 `-Wno-error=...` 压告警，压不住真错误）。换 `clang_tag`（如 `clang-r522817` / `clang-r487747c`）与对应 `clang_branch` 试。

**ccache 命中率低**：key 是 `ccache-<flavor>-<defconfig>-<sha>`，restore 前缀按 `flavor + defconfig` 回退；换 defconfig / 换 `clang_tag` / 换 `kernel_ref` 后会重新建缓存。要清理就去 Actions → Caches 删 `ccache-*`。

**构建超时**：`timeout-minutes: 300`。空缓存 + LTO 首次通常 60–100 分钟；ccache 命中后 15–25 分钟。

**刷完没 Wi-Fi / 模块加载失败**：几乎一定是「内核与模块不是同一次构建」——检查 zip 里 `modules/vendor/lib/modules/` 是否有本次的 `.ko`，以及刷机日志里 `do_modules` 有没有真的把这些文件 push 进 `/vendor/lib/modules`。

## 7. 本仓库做过的静态校验（没有在本机编译）

```
$ python3 -c "import yaml; ..."            # 三个 workflow 都能 yaml.safe_load
bash -n                                    # 引擎里 15 个 run 块全部通过
patch -p1 --dry-run                        # patches/susfs 三个补丁在 cnb 的 20 个受影响文件上 rc=0（无 fuzz 报错）
make ARCH=arm64 O=... vendor/sm8150-perf_defconfig + merge_config + scripts/config + olddefconfig
#   -> CONFIG_KSU=y / CONFIG_KSU_MANUAL_HOOK=y / CONFIG_KSU_SUSFS=y / CONFIG_THREAD_INFO_IN_TASK=y
```

事实来源可复核：`Evolution-X-Devices/kernel_xiaomi_raphael@cnb`、`Evolution-X-Devices/device_xiaomi_raphael@cnb`、
`KernelSU-Next/KernelSU-Next`（legacy 分支）、`SOVIET-ANDROID/kernel_xiaomi_raphael@16.0-SUSFS`（SUSFS v2.1.0 来源）、
`osm0sis/AnyKernel3`、crDroid 的 clang prebuilt 镜像。
