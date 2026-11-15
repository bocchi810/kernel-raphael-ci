# donors

把你的 ROM 里的 boot.img 放到这里并命名为 boot.img，workflow 就会用它当底包，
把编译出来的 kernel 换进去、重打包成可 fastboot 刷的 boot-*.img。

- 文件必须是 Android boot image（前 8 字节是 ANDROID!）。
- 必须来自你要刷的那个 ROM 版本；换 ROM 就要换底包。
- 不想提交二进制的话，触发 workflow 时填 boot_img_url 直链也一样。
