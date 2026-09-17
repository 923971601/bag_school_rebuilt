# =============================================================================
# run_on_pc.ps1 —— 在本机跑这个重建工程的几种方式
#
#   用法:
#     .\run_on_pc.ps1 web        在 Chrome 里打开（最快，不需要 Android SDK）
#     .\run_on_pc.ps1 web-live   带热重载的 Chrome 调试（改代码即时刷新）
#     .\run_on_pc.ps1 emu        启动 Android 模拟器并安装运行
#     .\run_on_pc.ps1 phone      用 USB 连的真机安装运行
#     .\run_on_pc.ps1 apk        只构建 release APK
#     .\run_on_pc.ps1 analyze    静态分析 + 单元测试
#
# 工具链都在 D:\apkwork 下，不污染系统 PATH。
# =============================================================================
param([Parameter(Position = 0)][string]$Action = 'help')

$ErrorActionPreference = 'Stop'

# ---- 工具链路径 ----
$Flutter  = 'D:\apkwork\tools\flutter\flutter'
$Jdk17    = 'D:\apkwork\tools\jdk17'
$Sdk      = 'D:\apkwork\android-sdk'
$Project  = $PSScriptRoot

# ---- 环境变量（每次都要设，因为是本机私有路径）----
$env:Path = "$Flutter\bin;$Jdk17\bin;$Sdk\platform-tools;$Sdk\emulator;$env:Path"
$env:JAVA_HOME = $Jdk17
$env:ANDROID_HOME = $Sdk
$env:ANDROID_SDK_ROOT = $Sdk
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'

Set-Location $Project

switch ($Action) {
  'web' {
    # 构建静态站点，用本地 http 服务器打开 Chrome
    # （--web-renderer html 避免依赖 gstatic 的 CanvasKit CDN）
    flutter build web --release --web-renderer html
    Start-Process -FilePath 'python' -ArgumentList '-m', 'http.server', '8080', '--bind', '127.0.0.1' `
      -WorkingDirectory "$Project\build\web" -WindowStyle Hidden
    Start-Sleep 3
    Start-Process 'C:\Program Files\Google\Chrome\Application\chrome.exe' `
      -ArgumentList '--new-window', '--window-size=430,900', 'http://127.0.0.1:8080/'
    Write-Host '已打开 http://127.0.0.1:8080/' -ForegroundColor Green
  }

  'web-live' {
    # 热重载：改 lib/*.dart 后按 r 热重载，R 热重启
    flutter run -d chrome --web-renderer html
  }

  'emu' {
    # 1) 缺啥装啥（模拟器包 / 系统镜像）
    $need = @()
    if (-not (Test-Path "$Sdk\emulator\emulator.exe")) { $need += 'emulator' }
    if (-not (Get-ChildItem "$Sdk\system-images" -Recurse -Filter 'system.img' -ErrorAction SilentlyContinue)) {
      $need += 'system-images;android-34;google_apis;x86_64'
    }
    if ($need.Count -gt 0) {
      Write-Host "需要补装：$($need -join '  ')（大约 1.5GB，耐心等）" -ForegroundColor Yellow
      & "$Sdk\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root=$Sdk @need
      if ($LASTEXITCODE -ne 0) { Write-Host 'sdkmanager 失败，先看上面的错误' -ForegroundColor Red; exit 1 }
    }

    # 2) 没有 AVD 就建一个
    $avds = & "$Sdk\emulator\emulator.exe" -list-avds
    if ($avds -notcontains 'bag_school') {
      Write-Host '创建 AVD: bag_school' -ForegroundColor Cyan
      'no' | & "$Sdk\cmdline-tools\latest\bin\avdmanager.bat" create avd `
        -n bag_school -k 'system-images;android-34;google_apis;x86_64' -d pixel_6 --force
    }

    # 3) 启动（已经在跑就不重复开）
    if (-not (adb devices | Select-String 'emulator-\d+')) {
      Start-Process "$Sdk\emulator\emulator.exe" `
        -ArgumentList '-avd', 'bag_school', '-gpu', 'auto'
      Write-Host '模拟器启动中…' -ForegroundColor Yellow
    } else {
      Write-Host '模拟器已在运行' -ForegroundColor Green
    }

    adb wait-for-device
    do {
      Start-Sleep 3
      $b = adb shell getprop sys.boot_completed 2>$null
    } until ($b -match '1')
    Write-Host '开机完成，开始安装运行…' -ForegroundColor Green
    flutter run
  }

  'phone' {
    adb devices
    flutter run
  }

  'apk' {
    flutter build apk --release
    Write-Host "产物: $Project\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
  }

  'analyze' {
    flutter analyze
    flutter test
  }

  default {
    Write-Host '用法: .\run_on_pc.ps1 [web|web-live|emu|phone|apk|analyze]' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  web       在 Chrome 里打开（最快）'
    Write-Host '  web-live  带热重载的 Chrome 调试'
    Write-Host '  emu       Android 模拟器'
    Write-Host '  phone     USB 真机'
    Write-Host '  apk       只构建 release APK'
    Write-Host '  analyze   analyze + test'
  }
}
