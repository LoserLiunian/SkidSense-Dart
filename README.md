# SkidSense Mobile（Flutter）

在手機上操作電腦端的 SkidSense：查看與發起工作階段、批准工具呼叫、瀏覽檔案、Git、終端機、加密歷史。Android 與 iOS 共用一份程式碼，介面提供 **Material 3** 與 **Material 3 Expressive** 兩套風格，可在設定中即時切換；語言支援英文、簡體中文、繁體中文（台灣用語）。

協定規格以電腦端倉庫的 `docs/remote-control.md`（skidsense-rc/1）為準，`remote-vectors.json` 兩端一致。

## 結構

```
packages/skidsense_core/   純 Dart：協定（握手、AES-GCM 幀、配對、歷史加密）、
                           傳輸（區網 / 中繼、重連）、後端 API、App 狀態機
  lib/testing.dart         FakeHost：記憶體內、說真協定的假電腦端，供測試使用
app/                       Flutter App（com.skidsense.app）
  lib/ui/material.dart     全 App 只從這裡匯入 Material（material_ui 套件）
  lib/ui/kit/              元件層：同一個 API，依風格畫成 M3 或 M3 Expressive
  lib/ui/theme/            色彩、形狀、動態（彈簧）、字體 token
  lib/ui/screens/          畫面
  lib/l10n/                ARB 字串（app_en / app_zh / app_zh_Hant）與產生的程式碼
  test/                    單元、截圖比對、無障礙、大字體測試
  tool/icons_test.dart     以程式繪製啟動圖示
```

## 開發

需要 Flutter 3.47（stable）。在倉庫根目錄：

```sh
flutter pub get                                   # 工作區：core 與 app 一起
cd packages/skidsense_core && dart test           # 核心：175 個測試
cd app && flutter analyze && flutter test         # App：分析、單元、截圖、無障礙、大字體
cd app && flutter run                             # 在模擬器或手機上執行
```

- **截圖比對**（`test/goldens/`）只在 macOS 上產生與比對（字型依系統而異）。不同 macOS 版本的字形反鋸齒略有差異，比對時忽略：差異超過 64/255 的像素不得多於 0.002%，任何差異的像素不得多於 1%（見 `test/flutter_test_config.dart`）。改了外觀後用 `flutter test --update-goldens` 重繪，**先看過圖再提交**。
- **無障礙**：`test/accessibility_test.dart` 以 Android 48dp、iOS 44pt 觸控目標、可點擊元素須有標籤、WCAG 文字對比檢查每個畫面的兩種風格與深淺色。
- **大字體**：`test/large_text_test.dart` 在 360dp 寬的手機上以 2 倍字體、三種語言渲染每個畫面，任何溢出即失敗。
- **連線後的畫面**用 `test/support/demo_host.dart`（FakeHost＋示範資料）在假時鐘上走真協定，不需要真的電腦。
- **字串**：改 `lib/l10n/*.arb`（三個檔案的鍵必須一致），`flutter pub get` 或 `flutter gen-l10n` 重新產生。繁體中文用台灣用語。
- **圖示**：`flutter test tool/icons_test.dart`（macOS）重繪 Android 舊版 PNG 與 iOS 1024px 圖示；Android 8+ 用的是 `res/drawable/ic_launcher_foreground.xml` 向量圖，幾何相同。

## 平台

- **iOS** 透過 Swift Package Manager 取得外掛（`app/pubspec.yaml` 的 `flutter.config`），不需要 CocoaPods。
- **Android** 區網連線是 `ws://`，在 `network_security_config.xml` 中刻意允許明文：機密性與完整性由協定本身（X25519 握手＋AES-256-GCM）保證。安全儲存與 App 私有檔案排除於備份與裝置轉移之外（金鑰綁定本機 Keystore）。
- **正式簽章**：建立 `app/android/key.properties`（已被 git 忽略）：

  ```properties
  storeFile=/path/to/skidsense.jks
  storePassword=…
  keyAlias=skidsense
  keyPassword=…
  ```

  沒有這個檔案時，release 建置用 debug 金鑰簽章，僅供測試。
- 若 Gradle 下載依賴時 TLS 連線被中斷（例如經由本機代理上網），可為單次建置加上代理參數：
  `./gradlew assembleDebug -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=<port>`。

## CI

`.github/workflows/ci.yml`：核心分析與測試（Linux）；App 分析、測試與截圖比對（macOS，失敗時上傳差異圖）；Android debug APK 與 iOS 模擬器建置。
