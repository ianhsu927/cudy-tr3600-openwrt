# Cudy TR3600 v1 OpenWrt Actions

状态：此前版本已通过 GitHub Actions 编译与产物检查；当前版本以对应 Actions 结果为准，尚未进行真机验证。仅适用于 TR3600 v1.0，不适用于 TR3000、WR3600 或其他硬件版本。

## 内容

- OpenWrt `openwrt-25.12` 稳定分支，附加固定版本的设备适配 PR #24596 补丁，以及社区的风扇、LED、MAC 修复；不切换到 PR 分支或 master snapshot。
- 中文 LuCI、HTTPS 管理、OpenClash 插件和 firewall4/nftables 依赖。
- Argon 主题及 Argon 配置插件、SQM 队列管理、nlbwmon 流量统计。
- `luci-app-usb-tethering` USB 手机热点管理插件（网络 → USB 热点）。
- `luci-app-tr3600-manager` 0.2.2 硬件管家（状态 → TR3600 硬件管家），包含硬件状态、灯光开关、风扇设置及散热保护服务；已包含 BusyBox 配置锁兼容修复。
- `luci-app-net-doctor` 0.1.0 断网诊断助手（状态 → 断网诊断），提供只读接口、路由、DNS、ICMP 和 HTTPS 检测。
- 三个自研插件固定到已确认的源码提交，版本记录在 `custom-plugin-sources.txt` 和 `sources.txt`。不加入独立灯光插件，避免与硬件管家的 `tr3600.led` 后端冲突；不加入 mwan3-nft。
- 预装 OpenClash 官方分发的 ARM64 Meta/Mihomo 内核，版本来源及 SHA256 写入 openclash-core.txt。
- 安卓 USB 共享：RNDIS、CDC Ethernet、CDC NCM。
- iPhone USB 共享：ipheth、usbmuxd、libimobiledevice。
- 推送配置时编译，也可在 Actions 手动运行；每周六北京时间 04:00 编译。
- Actions Artifacts 保留固件、校验和、包清单、实际源码版本和日志 30 天。

## 首次构建

将本目录文件提交至 GitHub 仓库 main 分支（保留 .github 目录），打开 Actions → Build Cudy TR3600 v1 OpenWrt → Run workflow。成功后下载 artifact；失败 artifact 可能只有诊断文件。

设备适配尚需 PR 补丁，因此准备阶段会严格检查修复补丁和必选包；上游发生不兼容变更时停止构建，不会生成其他机型固件。系统源码始终使用稳定分支，设备适配补丁固定为 `046aec0dccd90f5a156cb8e9725c121c81955dd3`。稳定分支及其他依赖会跟随各仓库版本，实际分支、提交和补丁版本写入 sources.txt；这并非完全锁定的可复现构建。

## 默认 Wi-Fi

首次生成无线配置时，按硬件检测的频段配置，不依赖 `radio0` / `radio1` 的编号：

- 5 GHz 开启，SSID 为 `TR3600`，密码为 `password`，WPA2/WPA3 Personal 混合模式。
- 5 GHz 请求 160 MHz，保留驱动检测的 EHT / HE 模式（TR3600 通常为 `EHT160`），使用自动信道；不超过硬件报告的最大带宽。
- 2.4 GHz 的 radio 和默认 AP 均关闭。

这是公开的初始密码，任何人都能查看，请首次连接后立即更换。只在首次安装、不保留配置升级、恢复出厂设置或重新生成缺失的无线配置时生效；保留配置的 sysupgrade 不会覆盖已有 Wi-Fi 名称、密码或频段设置。

未写死国家码、发射功率或绕过 DFS。请通过有线 LAN 管理页面设置实际使用国家/地区；160 MHz 能否启用取决于当地法规、可用信道、DFS 检测和客户端能力，在未正确设置国家码时 5 GHz 可能无法启动。5 GHz 处于启用配置状态不保证立即发射或以 160 MHz 连接，仍需真机验证。

## OpenClash

插件和 ARM64 Meta/Mihomo 内核预装，内核路径为 `/etc/openclash/core/clash_meta`。首次使用在服务 → OpenClash 导入自己的订阅或配置并启动；后续可在插件内更新 ARM64 Meta 内核。此仓库不包含订阅、账号或密钥。构建时内核下载或架构检查失败会停止构建。请先验证新版本 OpenClash 在 25.12/apk 环境下的功能。

## USB 手机网络共享

安卓启用 USB 网络共享；iPhone 开启个人热点，通过数据线连接 USB-A 接口并点“信任”。USB-C 接口用于给路由器供电。

可在网络 → USB 热点选择手机网卡并启用，由插件配置 DHCP 接口和防火墙。高级设置中的 metric 控制路由优先级，默认 100，通常作为有线 WAN 的备用线路。

也可手动在网络 → 接口添加 `usbwan`，协议 DHCP 客户端，设备选实际出现的 `usb0` 或 `eth*`，防火墙区域选 `wan`；同一手机网卡只使用一种配置方式。不要把手机接口加入 LAN 网桥。iPhone 如未出现网卡，可通过 SSH 检查 `lsusb`、`logread` 和 `idevicepair pair`。

多 WAN 自动切换未配置；同时使用有线 WAN 时按需求调整路由 metric。驱动预装不代表所有手机型号均已实测。

## 自研插件

| 插件 | 版本 | 固定源码提交 |
| --- | --- | --- |
| USB 热点管理 | 1.1.0 | `a752832a17261a6ccf2474defa6b3e5d7848427b` |
| TR3600 硬件管家 | 0.2.2 | `80d09d8a661bb648158b2ffaade15d929b78efc7` |
| 断网诊断助手 | 0.1.0 | `a95704e1d6b0b6328ee23eec2747d5fc2c04e710` |

硬件管家默认使用系统风扇温控。手动设置表示最低档位，温度升高时仍会自动升档；启用自定义设置前保护服务必须运行。首次启动由 OpenWrt 包安装机制启用 `tr3600-fan` 服务。保留配置升级时沿用已有 `tr3600_fan` 设置。

断网诊断助手只检测路由器默认 IPv4 出口，不自动修复网络，也不代表 USB 或客户端路径已经验证。各插件源码检查和此前实机验证不能替代这版固件的完整编译与刷机验收；以本次 Actions 结果及设备验证为准。

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
- https://github.com/ianhsu927/luci-app-tr3600-manager
- https://github.com/ianhsu927/luci-app-net-doctor

上游补丁和软件保留各自许可与版权；不重新声明其许可证。
