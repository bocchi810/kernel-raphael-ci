# patches/

两套完全不同的补丁，别混用：

## susfs/ —— Evolution-X cnb（4.14.357）用，CI 现在只打这一套

Evolution-X 的 cnb 内核树**自带** drivers/kernelsu（KernelSU-Next v3.4.0-legacy 快照），但没有 SUSFS。
这三个补丁把 SUSFS v2.1.0（取自 SOVIET-ANDROID/kernel_xiaomi_raphael 的 16.0-SUSFS 分支，同为 4.14.357）
搬进这棵树，并给树内自带的 KSU Next 驱动补上 SUSFS 需要的胶水。

| 文件 | 作用 | 触达文件 |
|---|---|---|
| `10-susfs-core.patch` | 放入 SUSFS 内核实现本体 | 新增 `fs/susfs.c`、`include/linux/susfs.h`、`include/linux/susfs_def.h`；`fs/Makefile` 加 `obj-$(CONFIG_KSU_SUSFS) += susfs.o` |
| `11-susfs-vfs-hooks.patch` | 在 VFS 各路入口插 SUSFS 钩子 | `fs/open.c`、`fs/stat.c`、`fs/namei.c`、`fs/namespace.c`、`fs/readdir.c`、`fs/statfs.c`、`fs/notify/fdinfo.c`、`fs/proc/{base,task_mmu,cmdline,fd}.c`、`fs/proc_namespace.c`、`include/linux/sched.h`、`include/linux/mount.h` |
| `12-susfs-ksu-driver.patch` | 给树内 KSU Next v3.4 驱动补胶水 | `drivers/kernelsu/Kconfig`（新增 `KSU_SUSFS*` 菜单）、`selinux/selinux.c`（`susfs_is_current_ksu_domain()`）、`core/init.c`（`susfs_init()`）、`supercall/dispatch.c`（boot completed 后 `susfs_start_sdcard_monitor_fn()`）、`supercall/supercall.c`（`ksu_handle_sys_reboot` 里按 `SUSFS_MAGIC` 分发 `CMD_SUSFS_*`） |

应用顺序必须是 10 → 11 → 12（workflow 里用 glob 按文件名排序，`patches/susfs/*.patch`，数字前缀保证顺序）。
套完之后 CI 会断言：`fs/susfs.c` / `include/linux/susfs.h` / `fs/Makefile` 里的 `CONFIG_KSU_SUSFS` /
`drivers/kernelsu/Kconfig` 里的 `config KSU_SUSFS` / `supercall.c` 里的 `SUSFS_MAGIC` 全部存在。

SUSFS 用户态侧（`ksu_susfs`）走的是 `syscall(SYS_reboot, 0xFAFAFAFA, CMD_SUSFS_*, arg)`，
由 `supercall.c` 里的分发块处理；`SUSFS_VERSION` 是 `v2.1.0`，`ksu_susfs show version` 可以核对。

## legacy-a11/ —— 已下线，只作历史存档

这是给 PixelExperience `eleven`（Linux 4.14.190，非 GKI）那棵树用的 01-08 号补丁：往一棵
**没有** KernelSU/SUSFS 的树里完整移植 KernelSU Next + SUSFS，还要修 RTIC 遗留的 `.bss` 段与
`susfs_ksu_sid` 符号。Evolution-X cnb 树既自带 KSU Next、又是 4.14.357，所以这些补丁全部不需要。
CI 不会再应用它们（引擎只 glob `patches/susfs/*.patch`）。
