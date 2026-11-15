# 红米 K20 Pro (raphael) 内核 GitHub Actions 构建流水线

> KernelSU Next + SUSFS + ccache，产出 AnyKernel3 直刷 zip（boot + dtbo）。
> 默认源码是已经内置 KernelSU Next 与 SUSFS 的 `SOVIET-ANDROID/kernel_xiaomi_raphael@16.0-SUSFS`（Linux 4.14.357）。

## 1. 这套流水线实际在编什么

| 项 | 值 | 依据 |
|---|---|---|
| 机型 | Redmi K20 Pro / Mi 9T Pro（`raphael` / `raphaelin`），SM8150 | AnyKernel3 `device.name1=raphael` / `device.name2=raphaelin` |
| 内核 | 4.14.357 | 分支 `16.0-SUSFS` 的 `Makefile`：`VERSION=4 PATCHLEVEL=14 SUBLEVEL=357` |
| 源码 | `https://github.com/SOVIET-ANDROID/kernel_xiaomi_raphael` 分支 `16.0-SUSFS` | 仓库内 `drivers/kernelsu/` 与 `fs/susfs.c` 均已存在 |
| KernelSU | KernelSU **Next**（driver 内置） | `drivers/kernelsu/setup.sh` 里 `OWNER="KernelSU-Next"`；`Kbuild` 里 `KSU_GIT_VERSION := 2980`，按 `30000+git+150` 算出版本约 `33130` |
| SUSFS | 内核树内置（`CONFIG_KSU_SUSFS*`） | `drivers/kernelsu/Kconfig` 第 62 行起 `menu "KernelSU - SUSFS"` |
| 工具链 | AOSP clang `r547379`（crDroid prebuilt 镜像） | 上游 `.github/workflows/main.yml` 用的同一份 |
| 打包 | `SOVIET-ANDROID/AnyKernel3`（A-only，刷 boot + dtbo） | `anykernel.sh`：`IS_SLOT_DEVICE=0`、`flash_boot; flash_dtbo` |
| 加速 | ccache（`hendrikmuhs/ccache-action`，默认上限 2G） | 见第 4 节 |

上游同款构建命令（本流水线保持一致）：

```bash
make LLVM=1 LLVM_IAS=1 CC="ccache clang" raphael_defconfig
make LLVM=1 LLVM_IAS=1 CC="ccache clang" -j$(nproc)
```

## 2. 两种用法

### A. 直接放进内核仓库（最简单）

把 `.github/workflows/build-raphael.yml` 提交到你的 K20 Pro 内核仓库（例如 Soviet 树的分支），
然后 Actions → **Build Kernel · raphael** → Run workflow，**`kernel_repo` 留空**即可构建当前仓库。

### B. 独立 builder 仓库（本目录的形态）

本目录就是一个 builder 仓库：workflow 只放流水线，构建时去 clone 内核源码。

```bash
git init kernel-raphael-gha && cd kernel-raphael-gha
cp -r /path/to/this/repo/. .
git add -A && git commit -m "ci: raphael kernel build"
git remote add origin git@github.com:<你的用户名>/kernel-raphael-gha.git
git push -u origin main
```

触发时填 `kernel_repo`（如 `https://github.com/SOVIET-ANDROID/kernel_xiaomi_raphael`）与 `kernel_branch`（`16.0-SUSFS`）。

### 选哪个源码分支

| 你的 ROM | 分支 | 说明 |
|---|---|---|
| Android 16 类原生（Soviet Star 等） | `16.0-SUSFS` | 默认值，4.14.357，KSU-Next + SUSFS 都在树里 |
| Android 15 类原生 | `15-susfs` | 4.14.353，同样已集成 |
| 只想要原版内核 | `16.0` / `15.0` | 把 `ksu_enable` 设为 `false` |
| LineageOS 官方 22.2 / 23.2 | `lineage-22.2` / `lineage-23.2` | 不带 KSU/SUSFS，且原版 4.14 不支持 `LLVM=1`，需要自己改 make 参数 |

内核必须和 ROM 的 vendor 分区配套，跨 ROM 刷会不开机或没 Wi-Fi（见第 6 节）。

## 3. 输入参数

| 参数 | 默认 | 说明 |
|---|---|---|
| `kernel_repo` | 空 | 留空 = 构建本仓库；填 URL = clone 该仓库 |
| `kernel_branch` | `16.0-SUSFS` | 仅在填了 `kernel_repo` 时生效 |
| `defconfig` | `raphael_defconfig` | 支持 `arch/arm64/configs/vendor/xxx_defconfig` 子目录写法 |
| `localversion` | 空 | 覆盖 `CONFIG_LOCALVERSION`，例如 `SOVIET-STAR`；留空保持源码默认 |
| `ksu_enable` | `true` | 关掉则 `CONFIG_KSU` 置 n；树里必须有 `drivers/kernelsu`，否则直接报错 |
| `susfs_enable` | `true` | 关掉则 `CONFIG_KSU_SUSFS*` 全部置 n |
| `hook_mode` | `manual` | **4.14 必须 manual**；`kprobe` 只给 5.10+ 的树用 |
| `ccache_enable` | `true` | 关掉后直接用 clang，不挂 ccache |
| `release` | `false` | 构建成功后发 GitHub Release（需要 `contents: write`，workflow 里已声明） |
| `release_tag` | 空 | 留空自动用 `raphael-<run_number>` |

另外：仓库根目录或 `kernel/` 下若有 `patches/*.patch`，会在编译前按文件名顺序 `patch -p1` 打进源码。

## 4. ccache 说明

- 缓存 key：`ccache-raphael-<defconfig>-<branch>-<commit>`，restore 前缀两级回退，跨 commit 也能命中。
- 上限 `2G`（`max-size`），命中率在 job 的 **ccache statistics** 步骤与 Summary 里都能看到。
- 稳定性设置：`CCACHE_COMPILERCHECK=string:clang-r547379`、`CCACHE_NOHASHDIR=true`、`CCACHE_HARDLINK=true`。
- 上游同一套配置的实测：`SOVIET-ANDROID/kernel_xiaomi_raphael` 的 CI job 稳定在 15–16 分钟（ccache 持续命中）；空缓存首次大约 45–70 分钟。
- 换 defconfig / 换分支 / 升级内核大版本后，建议在 Actions → Caches 里删掉 `ccache-raphael-*` 再跑，避免失效对象占额度。

## 5. 为什么 4.14 必须用 manual hook

树里的 `drivers/kernelsu/Kconfig` 写得很清楚：

```
config KSU_KPROBES_HOOK
    bool "KernelSU tracepoint+kretprobe hook"
    ...
    help
      ... This should not be used on kernel below 5.10.
```

而 `KSU_MANUAL_HOOK` 的默认值只在 `!KPROBES` 时才为 y。K20 Pro 的 defconfig 里 KPROBES 是否打开并不由我们控制，
所以流水线显式写 `CONFIG_KSU_MANUAL_HOOK=y` + `CONFIG_KSU_KPROBES_HOOK=n`，并在 `olddefconfig` 之后断言它真的生效。
对应的手工 hook 代码在这个源码树里已经打好：

```
fs/exec.c:1926        ksu_handle_execveat((int *)AT_FDCWD, &filename, &argv, &envp, 0);
fs/open.c:382         ksu_handle_faccessat(&dfd, &filename, &mode, NULL);
fs/read_write.c:584   ksu_handle_sys_read(fd, &buf, &count);
```

## 6. 常见问题

**`CONFIG_KSU_SUSFS` 没有生效**：先看日志里打印的 `CONFIG_THREAD_INFO_IN_TASK`。`KSU_SUSFS` 在 Kconfig 里 `depends on THREAD_INFO_IN_TASK`，
arm64 的 4.14 在 `arch/arm64/Kconfig:159` 已经 `select THREAD_INFO_IN_TASK`，正常不会缺；缺了说明你换成了别的源码树。

**`该源码树没有内置 KernelSU Next`**：本流水线不负责把 KSU 打进普通内核树（KSU-Next 对非 GKI 只保留内置 driver 形态，SUSFS 还需要内核侧代码）。
换用 `16.0-SUSFS` / `15-susfs` 这类已集成的树，或把 `ksu_enable` 设为 false 只编原版内核。

**`LLVM=1` 编不过 / 找不到 `ld.lld`**：`LLVM=1` 需要源码树支持（Soviet 树 backport 过），原版 LineageOS 4.14 树不支持。
这类树要把 make 参数改成 `CC=clang CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu-` 并自己装 binutils。

**刷完开不了机 / 没 Wi-Fi**：内核必须和 ROM 的 vendor 分区匹配。K20 Pro 的 vendor 模块（wlan 等）是按原厂内核 vermagic 编的，
换了内核版本串（`CONFIG_LOCALVERSION`）后模块可能拒绝加载；要么用与 ROM 配套的内核树，要么把模块一起重编进包。

**构建超时**：`timeout-minutes: 180`。4 核 + 空缓存 + 全量 LTO 偶尔会顶到 90 分钟以上，属正常。

## 7. 本仓库做过的静态校验（没有在本机编译）

```
$ python3 -c "import yaml; yaml.safe_load(open('.github/workflows/build-raphael.yml'))"
yaml: OK, steps=19, run_blocks=13, bash_n_failures=0
$ actionlint .github/workflows/build-raphael.yml   # v1.7.7
(无输出，exit 0)
$ grep -nE "TODO|FIXME|<soc>|<branch>|占位" .github/workflows/build-raphael.yml
(空)
```

也就是说：YAML 解析、GitHub Actions 表达式/上下文校验、13 个 `run:` 块的 `bash -n` 全部通过；
构建命令本身来自上游仓库自己的 CI（`SOVIET-ANDROID/kernel_xiaomi_raphael` 的 Actions 里 `16.0-SUSFS` 分支最近 10 次运行全部成功，单 job 15–16 分钟）。
**本机没有跑过一次真实编译**，第一次在 GitHub 上跑仍建议先按默认参数验证。

事实来源都在 GitHub / GitLab 上可复核：`SOVIET-ANDROID/kernel_xiaomi_raphael` 的 `16.0-SUSFS` 分支、`SOVIET-ANDROID/AnyKernel3`、
`KernelSU-Next/KernelSU-Next`、`simonpunk/susfs4ksu`（GitLab）与 crDroid 的 clang r547379 镜像。

