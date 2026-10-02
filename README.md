# Cudy TR3600 v1 OpenWrt Actions

状态：工作流草稿；尚未在 GitHub 执行编译或真机验证。仅适用于 TR3600 v1.0，不适用于 TR3000、WR3600 或其他硬件版本。

## 内容

- OpenWrt `openwrt-25.12` 稳定分支，附加固定版本的设备适配 PR #24596 补丁，以及社区的风扇、LED、MAC 修复；不切换到 PR 分支或 master snapshot。
- 中文 LuCI、HTTPS 管理、OpenClash 插件和 firewall4/nftables 依赖。
- Argon 主题及 Argon 配置插件、SQM 队列管理、nlbwmon 流量统计。
- `luci-app-usb-tethering` USB 手机热点管理插件（网络 → USB 热点）。
- 预装 OpenClash 官方分发的 ARM64 Meta/Mihomo 内核，版本来源及 SHA256 写入 openclash-core.txt。
- 安卓 USB 共享：RNDIS、CDC Ethernet、CDC NCM。
- iPhone USB 共享：ipheth、usbmuxd、libimobiledevice。
- 推送配置时编译，也可在 Actions 手动运行；每周六北京时间 04:00 编译。
- Actions Artifacts 保留固件、校验和、包清单、实际源码版本和日志 30 天。

## 首次构建

将本目录文件提交至 GitHub 仓库 main 分支（保留 .github 目录），打开 Actions → Build Cudy TR3600 v1 OpenWrt → Run workflow。成功后下载 artifact；失败 artifact 可能只有诊断文件。

设备适配尚需 PR 补丁，因此准备阶段会严格检查修复补丁和必选包；上游发生不兼容变更时停止构建，不会生成其他机型固件。系统源码始终使用稳定分支，设备适配补丁固定为 `046aec0dccd90f5a156cb8e9725c121c81955dd3`。稳定分支及其他依赖会跟随各仓库版本，实际分支、提交和补丁版本写入 sources.txt；这并非完全锁定的可复现构建。

## OpenClash

插件和 ARM64 Meta/Mihomo 内核预装，内核路径为 `/etc/openclash/core/clash_meta`。首次使用在服务 → OpenClash 导入自己的订阅或配置并启动；后续可在插件内更新 ARM64 Meta 内核。此仓库不包含订阅、账号或密钥。构建时内核下载或架构检查失败会停止构建。请先验证新版本 OpenClash 在 25.12/apk 环境下的功能。

## USB 手机网络共享

安卓启用 USB 网络共享；iPhone 开启个人热点，通过数据线连接 USB-A 接口并点“信任”。USB-C 接口用于给路由器供电。

可在网络 → USB 热点选择手机网卡并启用，由插件配置 DHCP 接口和防火墙。高级设置中的 metric 控制路由优先级，默认 100，通常作为有线 WAN 的备用线路。

也可手动在网络 → 接口添加 `usbwan`，协议 DHCP 客户端，设备选实际出现的 `usb0` 或 `eth*`，防火墙区域选 `wan`；同一手机网卡只使用一种配置方式。不要把手机接口加入 LAN 网桥。iPhone 如未出现网卡，可通过 SSH 检查 `lsusb`、`logread` 和 `idevicepair pair`。

多 WAN 自动切换未配置；同时使用有线 WAN 时按需求调整路由 metric。驱动预装不代表所有手机型号均已实测。

## 刷机

首次从原厂迁移先阅读 Cudy 官方 TR3600 v1 下载页的中间固件 Readme：
https://www.cudy.com/zh-cn/pages/download-center/tr3600-1-0

不要把 sysupgrade 镜像直接当作原厂升级镜像。已经进入兼容 OpenWrt 时才按该机型说明使用 sysupgrade；跨原厂/社区固件不保留配置。initramfs 用于内存启动/恢复。先确认硬件版本、备份及恢复方式，再校验 sha256sums。此工作流未进行实际刷机验证。

## 来源

- https://github.com/openwrt/openwrt/pull/24596
- https://github.com/hyqhyq3/openwrt-cudy-tr3600
- https://github.com/vernesong/OpenClash
- https://github.com/jerrykuku/luci-theme-argon
- https://github.com/jerrykuku/luci-app-argon-config
- https://github.com/ianhsu927/luci-app-usb-tethering

上游补丁和软件保留各自许可与版权；不重新声明其许可证。
