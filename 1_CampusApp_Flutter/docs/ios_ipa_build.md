# iOS IPA 构建说明

这个 Flutter App 已经包含 iOS Runner 工程。要真正导出 IPA，本机还需要 Flutter、CocoaPods、Xcode 命令行工具，以及 Apple 签名账号/证书。

## 前置条件

- 已安装 Xcode，并且 `xcode-select -p` 指向当前 Xcode。
- Flutter SDK 版本满足 `pubspec.lock` 要求：`Flutter >= 3.38.0`、`Dart >= 3.12.0`。
- 已安装 CocoaPods，可以运行 `pod --version`。
- Xcode 中已登录 Apple Developer 账号，并配置可用 Team。
- Bundle Identifier 已归属于你的 Apple Developer Team。

## 准备依赖

在 `1_CampusApp_Flutter` 目录运行：

```sh
flutter pub get
cd ios
pod install
cd ..
```

`flutter pub get` 会生成 `ios/Flutter/Generated.xcconfig` 和 `ios/Flutter/ephemeral/` 下的文件。这些是构建产物，不应该提交到 Git。

## 配置签名

打开 Xcode 工作区：

```sh
open ios/Runner.xcworkspace
```

在 Xcode 中选择 `Runner` target，然后配置：

- Team：你的 Apple Developer Team。
- Bundle Identifier：一个属于该 Team 的唯一标识。
- Signing：本地开发构建建议先用 Automatic。

也可以先复制 CLI 模板：

```sh
cp ios/Signing.xcconfig.example ios/Signing.xcconfig
```

然后填写 `DEVELOPMENT_TEAM` 和 `PRODUCT_BUNDLE_IDENTIFIER`。如果后续把它接入 Xcode Build Settings，填写后的 `ios/Signing.xcconfig` 不要提交到 Git。

## 构建 IPA

普通签名构建：

```sh
flutter build ipa --release
```

如果 iOS 包需要连接指定后端地址，可以在构建时注入：

```sh
flutter build ipa --release --dart-define=API_BASE_URL=https://api.example.com
```

如果需要自定义导出方式：

```sh
cp ios/ExportOptions.plist.example ios/ExportOptions.plist
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist --dart-define=API_BASE_URL=https://api.example.com
```

也可以使用项目内脚本：

```sh
API_BASE_URL=https://api.example.com scripts/build_ios_ipa.sh
```

## 后端地址

`lib/core/network/network_client.dart` 默认后端地址是 `http://10.0.2.2:8080`，这个地址只适用于 Android 模拟器访问宿主机。iOS 构建时请用 `--dart-define=API_BASE_URL=...` 覆盖。iOS 模拟器访问本机后端可用 `http://127.0.0.1:8080`；真机安装则需要填写手机能访问到的局域网地址或公网 HTTPS 地址。

`ios/Runner/Info.plist` 已允许本地 HTTP 网络访问，方便开发调试。正式发布或 TestFlight 建议使用 HTTPS。

## 构建前检查

运行：

```sh
scripts/check_ios_build_ready.sh
```

脚本会检查本机工具链、Flutter 生成文件和签名配置提示。全部通过后，再执行 IPA 构建。
