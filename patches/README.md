# patches/

两套完全不同的补丁，别混用：

## susfs/ —— Evolution-X cnb（4.14.357）用，CI 现在只打这一套

Evolution-X 的 cnb 内核树**自带** drivers/kernelsu（KernelSU-Next v3.4.0-legacy 快照），但没有 SUSFS。
这四个补丁把 SUSFS v2.1.0（取自 SOVIET-ANDROID/kernel_xiaomi_raphael 的 16.0-SUSFS 分支，同为 4.14.357）
搬进这棵树，并给树内自带的 KSU Next 驱动补上 SUSFS 需要的胶水。

| 文件 | 作用 | 触达文件 |
|---|---|---|
| `10-susfs-core.patch` | 放入 SUSFS 内核实现本体 | 新增 `fs/susfs.c`、`include/linux/susfs.h`、`include/linux/susfs_def.h`；`fs/Makefile` 加 `obj-$(CONFIG_KSU_SUSFS) += susfs.o` |
| `11-susfs-vfs-hooks.patch` | 在 VFS 各路入口插 SUSFS 钩子 | `fs/open.c`、`fs/stat.c`、`fs/namei.c`、`fs/namespace.c`、`fs/readdir.c`、`fs/statfs.c`、`fs/notify/fdinfo.c`、`fs/proc/{base,task_mmu,cmdline,fd}.c`、`fs/proc_namespace.c`、`include/linux/sched.h`、`include/linux/mount.h` |
| `12-susfs-ksu-driver.patch` | 给树内 KSU Next v3.4 驱动补胶水 | `drivers/kernelsu/Kconfig`（新增 `KSU_SUSFS*` 菜单，**不含** `KSU_SUSFS_TRY_UMOUNT`）、`selinux/selinux.c`（`susfs_is_current_ksu_domain()`，外加 `susfs_is_avc_log_spoofing_enabled` 符号兜底）、`core/init.c`（`susfs_init()`）、`supercall/dispatch.c`（boot completed 后 `susfs_start_sdcard_monitor_fn()`）、`supercall/supercall.c`（`ksu_handle_sys_reboot` 里按 `SUSFS_MAGIC` 分发 `CMD_SUSFS_*`） |
| `13-susfs-kallsyms-hide.patch` | 让 `KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS` 真正生效（在此之前只是被 `susfs_get_enabled_features` 报出去，没有实现） | `kernel/kallsyms.c`：`s_show()` 里按符号名过滤 `ksu_*` / `__ksu_*` / `susfs_*` / `ksud*` / `kernelsu*` / `is_zygote` 等 18 个前缀（SOVIET 同款列表），`/proc/kallsyms` 不再露出这些名字 |

### 两项「登记了但没实现」的功能（自己心里有数，别在设备上踩坑）

| 功能 | 现状 | 原因 |
|---|---|---|
| `CMD_SUSFS_ADD_TRY_UMOUNT`（SUSFS 版 umount 列表） | 未启用；`ksu_susfs add_try_umount` 被 `supercall.c` 的 `#ifdef` 拦掉，落到未知命令返回 `-EINVAL` | 这棵树的 `try_umount()` 是 `drivers/kernelsu/feature/kernel_umount.c:82` 里的 **static** 函数，`fs/susfs.c` 链接不到它；SOVIET 的做法是把它改成全局**并且整块编掉** KSU 自己的 `umount_tw_func`/`ksu_handle_umount`，与 KSU Next v3.4 的 setuid hook 强耦合，代价大。所以直接把 `KSU_SUSFS_TRY_UMOUNT` 从 Kconfig 菜单里删掉，编译期让 `fs/susfs.c` 那段 `#ifdef` 整段消失（否则 vmlinux 链接报 `undefined symbol: try_umount`） |
| `CMD_SUSFS_SET_AVC_LOG_SPOOFING`（伪造 avc denied 日志） | 命令能设，但**没有任何内核钩子消费**，等于不生效；`susfs_get_enabled_features` 也不宣称支持它 | 真正实现在 `security/selinux/avc.c` 的 `avc_log()` 里（把 `tsid == susfs_ksu_sid` 的 tcontext 改写成 priv_app），还依赖 `susfs_ksu_sid`/`susfs_priv_app_sid` 两个 SID 变量 —— KSU Next v3.4 不提供，需要自己在 selinux 初始化里算；这里只补了 `bool susfs_is_avc_log_spoofing_enabled` 定义兜住链接 |

应用顺序必须是 10 → 11 → 12 → 13（workflow 里用 glob 按文件名排序，`patches/susfs/*.patch`，数字前缀保证顺序）。
套完之后 CI 会断言：`fs/susfs.c` / `include/linux/susfs.h` / `fs/Makefile` 里的 `CONFIG_KSU_SUSFS` /
`drivers/kernelsu/Kconfig` 里的 `config KSU_SUSFS` / `supercall.c` 里的 `SUSFS_MAGIC` 全部存在。

SUSFS 用户态侧（`ksu_susfs`）走的是 `syscall(SYS_reboot, 0xFAFAFAFA, CMD_SUSFS_*, arg)`，
由 `supercall.c` 里的分发块处理；`SUSFS_VERSION` 是 `v2.1.0`，`ksu_susfs show version` 可以核对。

## legacy-a11/ —— 已下线，只作历史存档

这是给 PixelExperience `eleven`（Linux 4.14.190，非 GKI）那棵树用的 01-08 号补丁：往一棵
**没有** KernelSU/SUSFS 的树里完整移植 KernelSU Next + SUSFS，还要修 RTIC 遗留的 `.bss` 段与
`susfs_ksu_sid` 符号。Evolution-X cnb 树既自带 KSU Next、又是 4.14.357，所以这些补丁全部不需要。
CI 不会再应用它们（引擎只 glob `patches/susfs/*.patch`）。
