# 维护约定

- 始终使用简体中文沟通；动手前先读 HANDOFF.md 与 README.md。
- 本项目为个人 OpenWrt USB AirPlay 实验，禁止引入公司资料、路由器凭据、真实配置副本、原始日志或其他项目内容。
- src/libmaru 是已适配的上游源码；device-adaptation.patch 仅记录差异，构建时不要重复应用。
- build.sh 用 Docker ARM64 Alpine 编译，输出 dist/；OpenWrt 服务与配置模板位于 openwrt/，默认名称使用通用名称。
- 当前固定 e5b7:0811、48kHz S16LE 双声道；不得将单设备验证称为通用支持。输入为 44.1kHz S16LE 双声道。
- 本地检查可执行 `sh -n build.sh openwrt/run.sh openwrt/airplay-usb.init`；编译使用 `sh build.sh`。真实音频功能只能在匹配 USB 音箱上验收。
- 用户未明确授权前不要执行部署、重启设备、Git 初始化/提交/推送或创建远程仓库。
- dist/、build/、日志不要纳入源码提交；发布二进制前补全各动态依赖许可证与对应源码交付方式。
- 当前未给本地新增代码单独确定许可证；不得把上游 LGPL 自动解释为所有新增代码已完成授权。
- 改结构、命令或工作流时同步 README.md 和本文件；阶段结束更新 HANDOFF.md，区分已验证、待验证。

- release-tools/ 包含依赖源码收集、发行打包及安装/归档卸载脚本；releases/ 为忽略的发行产物。发布依赖源包与主源码版本必须同时可取。
