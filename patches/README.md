# patches/

把要额外打进内核源码的补丁放在这里，文件名按字典序依次应用：

```
patches/0001-xxx.patch
patches/0002-yyy.patch
```

应用方式是在 `kernel/` 目录里执行 `patch -p1 --forward --batch < 补丁`，
所以补丁必须是 `a/...` / `b/...` 前缀（`git diff` 或 `git format-patch` 的默认格式）。

没有补丁时这个目录可以删掉，workflow 会跳过该步骤。
