<#
  fix-adb-guid.ps1

  作用：让 adb 能在 Windows 上找到你插着的 Android 手机。

  一句话原理：
    Windows 只给手机的 ADB 接口挂了"门牌号"，而 adb 只认
      {F72FE0D4-CBCB-407D-8814-9ED673D0DD6B}
    这一个。这个脚本就是把缺的那块门牌补上去 —— 不换驱动、不装任何手机助手。

  适用：Windows 10 / 11，PowerShell 5.1 及以上
  权限：需要管理员（脚本会自己弹 UAC，不用手动开管理员窗口）
  可逆：见脚本结尾打印的还原方法

  用法：
    1) 用数据线连上手机，并打开开发者选项里的「USB 调试」
    2) 在这个文件所在目录打开 PowerShell，执行：
         powershell -ExecutionPolicy Bypass -File .\fix-adb-guid.ps1
    3) 如果 adb.exe 不在 PATH 里，加参数指定：
         powershell -ExecutionPolicy Bypass -File .\fix-adb-guid.ps1 -AdbPath "C:\你的\platform-tools\adb.exe"
#>

[CmdletBinding()]
param(
    [string]$AdbPath = ''
)

$ErrorActionPreference = 'Stop'

# adb 唯一认的设备接口 GUID（Google 在 android_winusb.inf 里登记的就是它）
$GOOGLE_GUID = '{f72fe0d4-cbcb-407d-8814-9ed673d0dd6b}'
# ADB 接口的标准 USB 类别，任何品牌的手机都一样
$ADB_CLASS_ID = 'USB\Class_ff&SubClass_42&Prot_01'

function Say([string]$msg, [string]$color = 'Gray') { Write-Host $msg -ForegroundColor $color }

# ---------- 0. 提权 ----------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Say ''
    Say '  需要管理员权限，正在请求提权...' 'Yellow'
    Say '  → 请在 UAC 弹窗上点「是」，新的窗口会继续执行。' 'Yellow'
    Say ''
    try {
        $self = (Get-Process -Id $PID).Path
        $argl = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
        if ($AdbPath) { $argl += @('-AdbPath', $AdbPath) }
        Start-Process -FilePath $self -ArgumentList $argl -Verb RunAs | Out-Null
    } catch {
        Say '  [X] 提权被拒绝了。请自己开一个管理员 PowerShell，再运行本脚本。' 'Red'
        exit 1
    }
    exit 0
}

# ---------- 1. 找到手机的 ADB 接口 ----------
Say ''
Say '=== 1/4  查找手机的 ADB 接口 ===' 'Cyan'

# 快路径：ADB 接口的设备名几乎一定带 "ADB"（"ADB Interface" / "Android ADB Interface"）。
# 这一步不查任何设备属性，瞬间完成。
$found = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
           Where-Object { $_.FriendlyName -match 'ADB' })

# 慢路径：只有名字没匹配上时，才按设备类别缩小范围、逐个核对接口类别。
# （某些系统上单次属性查询要 1~2 秒，所以尽量别走这条路）
if ($found.Count -eq 0) {
    Say '  设备名没匹配上，正在逐个核对 USB 设备（可能要十几秒，请等）...' 'DarkGray'
    $cands = @()
    $cands += Get-PnpDevice -PresentOnly -Class USBDevice            -ErrorAction SilentlyContinue
    $cands += Get-PnpDevice -PresentOnly -Class AndroidUsbDeviceClass -ErrorAction SilentlyContinue
    foreach ($d in $cands) {
        $ci = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_CompatibleIds' -ErrorAction SilentlyContinue).Data
        if ($ci -and ($ci -contains $ADB_CLASS_ID)) { $found += $d }
    }
}

if ($found.Count -eq 0) {
    Say '  [X] 没找到任何 ADB 接口。' 'Red'
    Say '      请先确认这三件事：' 'Yellow'
    Say '        1. 数据线是能传数据的（不是纯充电线）' 'Yellow'
    Say '        2. 手机上「开发者选项 → USB 调试」已打开' 'Yellow'
    Say '        3. 手机通知栏的 USB 模式选的是「传输文件」，不是「仅充电」' 'Yellow'
    exit 1
}

if ($found.Count -eq 1) {
    $dev = $found[0]
} else {
    Say '  找到多个 ADB 接口（可能同时插了设备/模拟器），请选择：' 'Yellow'
    for ($i = 0; $i -lt $found.Count; $i++) {
        Say ('   [' + ($i + 1) + '] ' + $found[$i].FriendlyName + '   ' + $found[$i].InstanceId)
    }
    $sel = Read-Host '  输入序号'
    $idx = 0
    if (-not [int]::TryParse($sel, [ref]$idx)) { Say '  输入无效。' 'Red'; exit 1 }
    $idx = $idx - 1
    if ($idx -lt 0 -or $idx -ge $found.Count) { Say '  序号超出范围。' 'Red'; exit 1 }
    $dev = $found[$idx]
}

$inst = $dev.InstanceId
Say "  设备 : $($dev.FriendlyName)"
Say "  实例 : $inst"
Say "  状态 : $($dev.Status)"

# ---------- 2. 补门牌号 ----------
Say ''
Say '=== 2/4  补上缺失的门牌号 ===' 'Cyan'

$key = "HKLM:\SYSTEM\CurrentControlSet\Enum\$inst\Device Parameters"
if (-not (Test-Path $key)) { Say "  [X] 找不到注册表位置：$key" 'Red'; exit 1 }

# 手机厂商自己上报的门牌号（如果有）保留不删
$vendorGuid = (Get-ItemProperty -Path $key -Name 'DeviceInterfaceGUID' -ErrorAction SilentlyContinue).DeviceInterfaceGUID
$newList = @()
if ($vendorGuid) {
    $newList += $vendorGuid
    Say "  保留原有 : $vendorGuid"
} else {
    Say '  原有     : （没有）—— 这正是问题所在' 'Yellow'
}
$newList += $GOOGLE_GUID

New-ItemProperty -Path $key -Name 'DeviceInterfaceGUIDs' -PropertyType MultiString -Value $newList -Force | Out-Null
Say "  已写入   : $($newList -join '  ,  ')" 'Green'

# ---------- 3. 让设备重新登记 ----------
Say ''
Say '=== 3/4  让设备重新登记一次（不用拔线）===' 'Cyan'
pnputil /restart-device "$inst"
Start-Sleep -Seconds 6

# ---------- 4. 验证 ----------
Say ''
Say '=== 4/4  验证 ===' 'Cyan'

# adb 会往 stderr 写一些无害信息（比如 daemon not running），
# 在 'Stop' 策略下会被当成致命错误，所以这里放开
$ErrorActionPreference = 'Continue'

if (-not $AdbPath) { $AdbPath = (Get-Command adb -ErrorAction SilentlyContinue).Source }

if (-not $AdbPath -or -not (Test-Path $AdbPath)) {
    Say '  没找到 adb.exe，跳过自动验证。' 'Yellow'
    Say '  请手动执行：  adb devices' 'Yellow'
} else {
    & $AdbPath kill-server 2>&1 | Out-Null
    $res = (& $AdbPath devices -l 2>&1 | Out-String)
    foreach ($line in ($res -split "`n")) { if ($line.Trim()) { Say "  $line" } }
    Say ''
    if ($res -match 'unauthorized') {
        Say '  [成功了一半] adb 已经能看到手机了。' 'Yellow'
        Say '  现在解锁手机，点弹窗里的「允许 USB 调试」（建议勾上「始终允许」）。' 'Yellow'
    } elseif ($res -match '\sdevice\b') {
        Say '  [完成] adb 可以正常使用你的手机了。' 'Green'
    } else {
        Say '  [仍然是空的] 拔插一次数据线，再执行 adb devices 看看。' 'Yellow'
        Say '  还不行的话，试文章里的备选方案（装 Google 官方 USB 驱动）。' 'Gray'
    }
}

Say ''
Say '--- 怎么还原 ---' 'DarkGray'
Say '删掉下面这个注册表位置里的 DeviceInterfaceGUIDs 值：' 'DarkGray'
Say "  $key" 'DarkGray'
Say "然后执行： pnputil /restart-device `"$inst`"" 'DarkGray'
Say ''
if ($Host.Name -eq 'ConsoleHost') {
    Say '按回车关闭...' 'DarkGray'
    [void](Read-Host)
}
