# BiliTV 📺

一款专为 Android TV 设计的第三方哔哩哔哩客户端，使用 Flutter 开发。本仓库是基于上游项目继续维护的 fork 版本，目标是优先保证 `登录可用`、`点播可看`、`直播可进`、`遥控器可操作`，并尽量降低网页 API 漂移带来的失效风险。

当前仓库包含我在 fork 后做的一轮中短期稳定性修复，已经补上登录兼容、播放链路、直播重连、启动瘦身和 TV 设备适配相关修改。

## 📌 Fork 版本说明

这个 fork 版本相对拉取时的原仓库，主要做了这些调整：

- **登录兼容修复** - 补齐网页登录和 TV 扫码登录请求头，增强登录态检测和 Cookie/WBI 兼容逻辑
- **网页 API 稳定性修复** - 调整 WBI key 获取、播放签名、搜索结果解析和匿名态回退逻辑
- **播放链路加固** - 保留 DASH 播放方案，收敛播放器初始化流程，降低启动阶段和切流阶段的失败概率
- **直播功能加固** - 增加直播弹幕 WebSocket 重连、host failover、线路失败自动切换和房间切换竞态保护
- **启动瘦身** - 启动视频改为更轻的静态启动页，本地服务和插件注册改成按需启动，减少冷启动负担
- **缓存策略调整** - 图片缓存和首屏预加载收紧，降低 Android TV 设备上的内存压力
- **TV 遥控器体验整理** - 统一返回键、方向键、确认键的焦点和播放器行为，优化电视遥控器操作体验
- **设备兼容修复** - 补充 ABI/设备信息获取和更新链路兼容，优先适配 Google TV Streamer 一类新设备
- **发布产物整理** - 已提供 `v1.2.3` 的 release/debug 安装包，便于直接安装和回退验证

## ✅ 当前状态

- **点播** - 已验证可播放、可切画质、可倍速、可快进快退、可开关弹幕、可接收弹幕
- **直播** - 已验证可进入直播、可播放、可开关直播弹幕、可接收直播弹幕、可切线路和画质
- **登录** - 已验证扫码登录可用，后续仍需持续跟踪 Bilibili 登录态和网页登录策略变化
- **遥控器操作** - 首页、详情页、播放器和直播页都按 Android TV 焦点模式优化过

## ⚠️ 当前已知缺口

- **字幕/CC** - 还没有完整实现独立字幕轨和字幕渲染
- **部分竖屏直播间** - 个别房间还存在布局和渲染兼容问题
- **Bilibili API 漂移** - 第三方客户端兼容策略会持续变化，后续维护重点仍然是保住稳定观看能力
- **设备差异** - 不同 Android TV 盒子/电视在编解码器、渲染后端和音量链路上仍可能表现不同

## 📦 安装包

已发布版本见这里：

- [GitHub Releases](https://github.com/gongyu0918-debug/BiliTV/releases)

`v1.2.3` 当前同时提供：

- `BiliTV-v1.2.3-release.apk`
- `BiliTV-v1.2.3-debug.apk`

`debug` 包已经覆盖过完整冒烟验证，适合兼容性回退和问题排查。`release` 包适合正式安装使用。

## ✨ 功能特色


### 截图展示
<img width="189" height="139" alt="image" src="https://github.com/user-attachments/assets/52b04c2a-85b6-4e35-bc3b-10e6bd588a4e" />
<img width="1193" height="666" alt="image" src="https://github.com/user-attachments/assets/7d779704-6709-49a3-957a-4253403bd71e" />
<img width="1203" height="668" alt="image" src="https://github.com/user-attachments/assets/b6784e77-96c5-40da-b567-9e8c6574b704" />
<img width="1069" height="569" alt="image" src="https://github.com/user-attachments/assets/209de939-bc94-4dc3-a8fd-1d9c57c4378d" />
<img width="1080" height="558" alt="image" src="https://github.com/user-attachments/assets/aeb84e09-7388-4ab6-b9be-b0da0340ddde" />






### 🎬 视频播放
- **多编解码器支持** - H.264 / H.265 / AV1 硬件解码，自动选择最优编码
- **DASH 视频流** - 高质量视频 + 独立音轨播放
- **多画质切换** - 支持 4K/1080P+/1080P/720P/480P 等多种画质
- **实时弹幕** - 完整弹幕体验，支持开关、透明度、字体大小、显示区域调节
- **弹幕倍速同步** - 弹幕飞行速度随播放倍速自动调整
- **播放进度记忆** - 自动保存播放进度，下次打开自动续播
- **自动连播** - 支持多P视频自动播放下一集，播完自动播放推荐
- **快进预览** - 拖动进度条时实时预览画面（雪碧图预览）
- **多P雪碧图支持** - 切换分P时自动加载对应预览图

### 📱 用户功能
- **二维码登录** - 使用手机扫码快速登录
- **动态页面** - 查看关注UP主的最新动态
- **观看历史** - 自动记录并同步云端历史，显示"已看完"状态
- **搜索功能** - 支持关键词搜索，保存搜索历史（最多10条）
- **推荐视频** - 首页展示个性化推荐内容
- **分区浏览** - 动画、游戏、音乐、科技等多分区内容
- **分区管理** - 自定义首页分区顺序和启用状态
- **直播浏览** - 支持直播推荐、直播播放、直播线路和画质切换

### 🎮 TV 遥控器优化
- **完整遥控器支持** - 方向键导航、确认键选择、返回键退出
- **焦点系统** - 清晰的焦点高亮，便于遥控器操作
- **快速切换** - 侧边栏一键切换首页/动态/搜索/历史/用户
- **播放器快捷键** - 左右快进快退、上下调节音量、确认暂停

### 🔌 插件系统
- **空降助手** - 基于 SponsorBlock 数据库自动跳过广告、赞助、片头片尾
- **视频过滤** - 按关键词/UP主屏蔽不想看的视频，过滤低质量内容
- **弹幕屏蔽** - 按关键词屏蔽弹幕，支持精确匹配和模糊匹配
- **插件中心** - 统一管理插件开关和配置

### ⚙️ 设置选项

#### 播放设置
- **首选编解码器** - 选择 H.264/H.265/AV1 或自动
- **自动连播开关** - 可选择是否自动播放下一个视频
- **快进预览** - 开启/关闭拖动进度条时的预览
- **弹幕设置** - 透明度、字号、速度、显示区域等参数调节

#### 界面设置
- **启动动画** - 开启/关闭应用启动动画
- **迷你进度条** - 播放器底部常驻进度条
- **默认隐藏控制栏** - 播放时自动隐藏控制条
- **播放器时间显示** - 右上角常驻时间
- **分区排序** - 自定义首页分区顺序

#### 存储设置
- **清除缓存** - 清除图片缓存和搜索记录
- **清除播放记录** - 清除本地播放进度

## 🛠️ 技术栈
- **Flutter 3.10+** - 跨平台 UI 框架
- **video_player + ExoPlayer** - 视频播放引擎，支持 DASH 格式
- **canvas_danmaku** - 弹幕渲染引擎
- **cached_network_image** - 图片缓存，已按 TV 设备场景收紧缓存和预加载策略
- **shared_preferences** - 本地数据存储
- **keframe** - 列表渲染性能优化
- **http** - 网络请求

## 📦 编译

```bash
# 获取依赖
flutter pub get

# 调试包
flutter build apk --debug

# 发布包
flutter build apk --release
```

## 🙏 致谢

本项目基于以下开源项目开发，特此感谢：

### 原始项目
- **[BiliPai](https://github.com/jay3-yy/BiliPai)** - 本项目的基础，感谢原作者的工作

### 参考项目
- **[BBLL](https://github.com/xiaye13579/BBLL)** - B 站 TV 第三方客户端实现参考
- **[BV](https://github.com/aaa1115910/bv)** - TV 端交互和播放链路参考

### 依赖库
| 库名 | 用途 |
|------|------|
| [video_player](https://pub.dev/packages/video_player) | 视频播放引擎 |
| [canvas_danmaku](https://pub.dev/packages/canvas_danmaku) | 弹幕渲染 |
| [cached_network_image](https://pub.dev/packages/cached_network_image) | 图片缓存 |
| [flutter_cache_manager](https://pub.dev/packages/flutter_cache_manager) | 缓存管理 |
| [shared_preferences](https://pub.dev/packages/shared_preferences) | 本地存储 |
| [http](https://pub.dev/packages/http) | 网络请求 |
| [qr_flutter](https://pub.dev/packages/qr_flutter) | 二维码生成 |
| [crypto](https://pub.dev/packages/crypto) | MD5 签名 |
| [keframe](https://pub.dev/packages/keframe) | 列表性能优化 |
| [fluttertoast](https://pub.dev/packages/fluttertoast) | Toast 提示 |
| [flutter_svg](https://pub.dev/packages/flutter_svg) | SVG 图标 |
| [marquee](https://pub.dev/packages/marquee) | 滚动文字 |
| [wakelock_plus](https://pub.dev/packages/wakelock_plus) | 屏幕常亮 |
| [path_provider](https://pub.dev/packages/path_provider) | 文件路径 |
| [package_info_plus](https://pub.dev/packages/package_info_plus) | 应用信息 |
| [permission_handler](https://pub.dev/packages/permission_handler) | 权限管理 |

## ⚠️ 免责声明

本项目仅供学习交流使用，请勿用于商业用途。视频内容版权归哔哩哔哩及原作者所有。

## 📄 许可证

GPLV3 License
