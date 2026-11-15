<div align="center">

# 🎵 OpenWrt USB AirPlay

### 路由器已经会翻山越岭了，顺便让它唱首歌。

**一台 OpenWrt 路由器 · 一个 USB 音箱 · 苹果设备点一下 AirPlay**

![ARM64](https://img.shields.io/badge/ARM64-musl-009688?style=for-the-badge)
![AirPlay](https://img.shields.io/badge/AirPlay-Classic-111111?style=for-the-badge&logo=apple)
![USB Audio](https://img.shields.io/badge/USB_Audio-Userspace-7C3AED?style=for-the-badge)
![Status](https://img.shields.io/badge/STATUS-实验项目-FF6B35?style=for-the-badge)

**没有声卡内核模块？那就试试从用户态把声音送过去。**

[为什么做](#-起因就想让这个音箱响起来) · [怎么做到](#-破局从用户态直达-usb) · [快速上手](#-让你的路由器也开口) · [边界说明](#-先把牛皮吹到这里)

</div>

---

## 🍎 起因：就想让这个音箱响起来

需求朴素得很：**USB 音箱已经插在路由器上，能不能让 iPhone、iPad、Mac 直接通过 AirPlay 播音乐？**

不想为了一个现成音箱，再添一台常开电脑。路由器天天在线，USB 口也在，怎么看都该轮到它打第二份工了。

于是先看了 [AirConnect](https://github.com/philippe44/AirConnect)。名字挺对味，但它实际做的是 **AirPlay → UPnP / Sonos / Chromecast 网络播放器** 的桥接，不能直接驱动路由器上的 USB 音箱。

真正适合接收 AirPlay 的是 [Shairport Sync](https://github.com/mikebrady/shairport-sync)。不过，把它接上音箱之前，还有一堵墙。

## 🧱 卡点：USB 看见了，声卡却不存在

实机检查发现：

| 检查项 | 结果 |
| --- | --- |
| USB 枚举 | 能看到 `HIFI MINI HD SOUND` |
| 音频接口 | 标准 UAC1，确实能传音频 |
| `/dev/snd` | 没有 |
| 声卡内核模块 | 没有 |
| 当前软件源 | 没找到匹配定制内核的音频模块 |

这台路由器跑的是定制 ImmortalWRT，内核 `6.12.80`。普通安装方案需要 ALSA 和 `kmod-usb-audio`，但现有固件没带，软件源也没提供匹配包。

**USB 能识别，不代表系统已经会播放。** 抓一个其他内核的模块硬塞进去，也不是靠谱的解决办法。

所以，我们转去 GitHub 找另一条路：有没有能直接使用 USB、绕过声卡内核模块的播放器？

## 🔓 破局：从用户态直达 USB

找到了一个 2012 年的老项目：[Themaister/libmaru](https://github.com/Themaister/libmaru)。

它用 **libusb 在用户态实现 USB Audio 播放**，可以不经过 ALSA 和 `snd` 内核模块。另一个查到的 libuac 项目只支持音频输入，所以没有采用。

接下来没有直接照搬示例，而是先读取音箱的 USB 描述符，确认这台设备的实际要求：

- VID / PID：`e5b7:0811`。
- UAC1、full-speed USB。
- 双声道、16 位 PCM、固定 **48 kHz**。
- 播放端点 `0x02`，未声明采样率控制能力。

然后做了几件具体的事：

1. **修正接口占用。** 原 libmaru 在没有内核驱动时，遗漏了控制接口的显式 claim；补上这一步。
2. **尊重设备能力。** 音箱固定 48 kHz，且未声明频率控制，跳过它不支持的 `SET_CUR` 采样率请求。
3. **先听一声。** 在 ARM64 Alpine 容器中构建小播放器，上传路由器，发送一秒低音量测试音。程序正常返回，现场确认听到了。
4. **接上苹果设备。** 编译 Shairport Sync 4.3.6，使用 stdout 输出 PCM；libsoxr 将 44.1 kHz 转为音箱需要的 48 kHz，再交给 libmaru。
5. **让它能被发现。** 复用路由器已有的 Avahi，绑定 LAN 接口，通过 mDNS 广播 AirPlay 名称。
6. **收成一个服务。** 程序放入持久目录，交给 OpenWrt procd 管理；两端成对启停，异常后自动重启。

苹果设备选中音箱，音乐真的响了。路由器的副业，正式开张。🎉

```mermaid
flowchart LR
    A[🍎 iPhone / iPad / Mac] -->|Classic AirPlay| B[Shairport Sync]
    B -->|44.1 kHz · S16LE · 双声道| C[libsoxr 重采样]
    C -->|48 kHz · S16LE · 双声道| D[libmaru + libusb]
    D -->|USB 等时传输| E[🔊 USB 音箱]
```

> 这套方案用的是 libmaru 核心播放库，不使用它的 CUSE / OSS 桥接层，因此不需要 FUSE / CUSE。

## 🧪 牛有没有吹过头？看验收记录

| 项目 | 状态 |
| --- | --- |
| USB 低音量测试音 | ✅ 实际听到 |
| 苹果设备 AirPlay 音乐播放 | ✅ 用户确认 |
| 自定义中文设备名 | ✅ mDNS 发现通过 |
| 持久目录与开机启动注册 | ✅ 已配置 |
| 服务停止 / 启动、清理播放器 | ✅ 已验证 |
| 播放器被终止后自动恢复 | ✅ 已验证 |
| 整机重启后的冷启动播放 | ⏳ 未实测 |
| USB 拔插恢复 | ⏳ 脚本已实现等待与检测，未实测 |
| 长时间连续播放与影音同步 | ⏳ 未完整验收 |

已验证环境：**ImmortalWRT r0-33de2be / Linux 6.12.80 / ARM64 musl**，音箱为杰理 `HIFI MINI HD SOUND`。

## 🚀 让你的路由器也开口

### 1. 先确认硬件

当前播放器与服务检测逻辑固定适配 `e5b7:0811` 音箱及上述格式。**其他 USB 音箱需要先检查描述符并适配，不能直接承诺通用支持。**

路由器需要 ARM64 musl 环境、可访问的 `/dev/bus/usb`、已运行的 Avahi，以及对应的 Avahi 运行库。默认 LAN 接口为 `br-lan`。

### 2. 构建

宿主安装并启动 Docker，然后运行：

```sh
sh build.sh
```

构建在 ARM64 Alpine 容器里完成，生成 `dist/`。Shairport Sync 固定源码提交；Alpine 依赖尚未锁定内容摘要，构建结果不保证逐字节相同。

> 构建会覆盖 `dist/`。本地已验证程序留档需要保留时，请先备份。仓库不提供预编译二进制。

### 3. 部署文件

先停止旧播放实例，避免两个播放器争抢 USB 接口。将文件按下表放到路由器：

| 本地文件 | 路由器路径 |
| --- | --- |
| `dist/shairport-sync`、`dist/maru-player` | `/opt/airplay-usb/` |
| `dist/lib/*` | `/opt/airplay-usb/lib/` |
| `openwrt/run.sh`、`openwrt/airplay.conf` | `/opt/airplay-usb/` |
| `openwrt/airplay-usb.init` | `/etc/init.d/airplay-usb` |

在路由器执行：

```sh
chmod 700 /opt/airplay-usb/run.sh /opt/airplay-usb/maru-player /opt/airplay-usb/shairport-sync /etc/init.d/airplay-usb
/etc/init.d/airplay-usb enable
/etc/init.d/airplay-usb start
/etc/init.d/airplay-usb status
```

苹果设备连接同一局域网，播放音乐，在 AirPlay 列表选择 **OpenWrt USB Speaker**。

### 4. 给音箱起个名字

修改 `/opt/airplay-usb/airplay.conf`：

```conf
general = {
 name = "客厅的快乐源泉";
 output_backend = "stdout";
 mdns_backend = "avahi";
 interface = "br-lan";
 port = 5000;
 volume_range_db = 45;
 default_airplay_volume = -20;
};
```

保留文件中其他需要的配置，然后执行：

```sh
/etc/init.d/airplay-usb restart
```

中文可以，正经名字可以，骚名字也可以。先把手机音量放低一点。🔈

## 🛠️ 日常运维

```sh
/etc/init.d/airplay-usb status   # 查看状态
/etc/init.d/airplay-usb restart  # 重启音频服务
/etc/init.d/airplay-usb stop     # 停止
/etc/init.d/airplay-usb disable  # 取消开机启动
logread | grep -E 'run.sh|shairport|USB audio'
```

- procd 监管接收器和 USB 播放器，任一退出后清理另一端，再重新启动。
- FIFO 和锁放在 `/var/run/airplay-usb`；日志进入系统环形日志，避免持续增长的日志文件。
- 不需要重启网络，也不需要为它开放 WAN 端口。
- 固件升级若需保留文件，将 `/opt/airplay-usb/` 和 `/etc/init.d/airplay-usb` 加入 `/etc/sysupgrade.conf`。升级后仍需核对 ABI 和 Avahi 依赖。

## 🚧 先把牛皮吹到这里

- **这是特定设备上验证过的实验项目。** 不是通用 USB Audio 驱动，也不是成熟音频发行版。
- 使用 **Classic AirPlay / AirPlay 1**，未实现 AirPlay 2 多房间功能。
- AirPlay 本身有缓冲，用户实测存在少许延迟；不适合游戏或实时通话。
- libmaru 是老代码，描述符边界检查、错误处理、资源清理与更多设备兼容性仍需改进。
- 当前无自动安装器；需要理解部署路径、进程和依赖后再安装。

## 📦 代码在哪儿

```text
src/player.c                      PCM 接入、重采样与测试音
src/libmaru/                      已适配的上游核心库
src/libmaru/device-adaptation.patch  相对上游的差异记录
openwrt/                          procd 服务、运行脚本与配置模板
build.sh                          ARM64 Docker 构建入口
licenses/                         上游版权与许可证
HANDOFF.md                        验收记录与后续工作
```

补丁已经应用在源码中，**不要重复应用**。

## 🙏 站在老项目的肩膀上

| 项目 | 用途 / 来源 |
| --- | --- |
| [Shairport Sync](https://github.com/mikebrady/shairport-sync) | AirPlay 接收；固定提交 `046b59851315f706d8e449fb9305e9f029811a71` |
| [libmaru](https://github.com/Themaister/libmaru) | 用户态 USB 播放；基于 `9a2ac0635f12485f15d68b90eed3f60ab9a86123` |
| [libusb](https://libusb.info/) | 用户态 USB 访问 |
| [libsoxr](https://sourceforge.net/projects/soxr/) | 采样率转换 |
| [Avahi](https://avahi.org/) | 局域网服务发现 |

本项目由作者与 AI 协作完成排查、适配及部署；实际播放由现场验证。核心能力来自上述开源项目，感谢原作者。

### 许可证说明

libmaru 源码及其修改遵循 **LGPL-2.1-or-later**，保留原始版权声明；Shairport Sync 的版权与许可见 `licenses/` 及其源码。**本项目新增播放器、脚本与文档尚未单独授予开源许可证，公开源码不代表无限制授权。**

仓库不分发构建生成的依赖库。未来若发布二进制，应补齐各依赖许可证及对应源码获取方式。

---

<div align="center">

**一个插在 USB 口上的音箱，终于等到了自己的 AirPlay 名字。**

🎶 让闲着的接口，干点快乐的事。

</div>
