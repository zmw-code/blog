# 设备管理器说「一切正常」，adb 却说「没有设备」

> 一份会分诊的 adb 排障指南 · 2026-10-13
>
> 这篇不打算教你怎么修电脑。它只帮你**先搞清自己属于哪一种情况**，然后告诉你该往哪走。
> 有些部分我会直接把你送去别人的文章——那里写得比我好，没必要重写一遍。

---

## 开始之前：先确认你的环境（30 秒，别跳过）

| 项目 | 说明 |
|---|---|
| **适用系统** | Windows 10 / Windows 11 |
| **终端** | 本文所有命令都是 **PowerShell**。⚠️ **不要粘到 cmd 里**——`Test-Path`、`Get-PnpDevice` 这些 cmd 根本不认 |
| **权限** | 只有标了「**管理员**」的命令才需要管理员，其余不用 |
| **我的验证环境** | Windows 11 + 荣耀 GT + platform-tools 31.0.3，**就这一台**。适用范围见 §D |

**怎么打开：**

- 普通 PowerShell：`Win + X` → 选「终端」或「Windows PowerShell」
- **管理员** PowerShell：`Win + X` → 选「**终端(管理员)**」或「**Windows PowerShell(管理员)**」

> 本文里 `pnputil` 这个命令比较特殊，它在 cmd 和 PowerShell 里都能跑。但为了省事，统一下面都用 PowerShell。

---

## 第 0 步：先别动手，花 30 秒看看你是哪一种

打开 PowerShell 敲：

```
adb devices
```

对着下面这张表，**直接跳到属于你的那一节**：

| 你看到的东西 | 它真正的意思 | 去哪 |
|---|---|---|
| `List of devices attached` 下面**什么都没有** | adb 根本**没找到**你的手机 | **§A** ← 本文重点 |
| `XXXXXX unauthorized` | 找到了，就等你在手机上点个「允许」 | **§B**（30 秒解决） |
| `XXXXXX offline` | 连上过，但断了 | **§C** |
| `XXXXXX device` | 一切正常 | 不用往下读 |

> 很多人卡在这一步就开始瞎折腾：明明只是没点授权，却在重装驱动。
> **先分清是哪一种，比什么技巧都重要。**

---

# §A 完全空白：adb 找不到手机

## A0. 先花 30 秒排除三个最常见的原因

这三个占了绝大多数情况，而且和「驱动」无关：

1. **线是纯充电线**
2. **手机的 USB 调试没开**，或者连接模式停在「仅充电」
3. **adb 服务卡住了**（`adb kill-server` 再 `adb devices`）

这三条的详细做法，中文写得比我全的在这里，我就不重复了：

- [人人代码：adb devices 空空如也？手机连不上电脑的分层排查手册](https://www.renrendaima.com/wap/article/2892.html) —— 它的「物理层 → 手机设置层 → 驱动层 → ADB 服务层」四层框架挺清楚
- [Google 官方：adb 文档](https://developer.android.com/studio/command-line/adb)

**如果这三条都试了还是空**，那你大概率掉进了本文真正想讲的那个坑 ↓

### 顺便说下第 1 条：怎么买到「能传数据的线」

这事比想象中坑人：**能充电 ≠ 能传数据**。充电只要 2 根线芯，传数据至少要 4 根。所以一条线插上能充电，也完全可能不认设备。

**直接去电商平台搜这些词：**

```
USB3.0 数据线 Type-C 高速传输
USB-IF 认证 数据线
绿联 Type-C 数据线 3A
```

**四条判据（按可靠度排）：**

1. **手机原装线** —— 100% 可以，先拿它排除问题
2. 商品**标题写「数据线」而不是「充电线」**
3. 参数里标了**传输速率**（480Mbps / 5Gbps / 10Gbps）—— 纯充电线不会标这个
4. ⚠️ **9.9 包邮、只写「快充线」的，基本是纯充电线**

## A1. 关键分岔：你的设备管理器里，手机长什么样？

打开设备管理器（`Win + X` → 设备管理器），插着手机找它。

**情况一：手机正常显示着，没有黄叹号**（一般在「便携设备」或「Android Phone」下）
→ 恭喜，你遇到的就是本文重点。**请继续看 A2**。

**情况二：有个带黄叹号的「未知设备」**
→ 那是驱动真的没装。这种情况一大堆教程写了，随便找一篇跟着做就行。比如：
[CSDN：解决 ADB 连接手机失败的问题](https://blog.csdn.net/qq_45657541/article/details/159502311)

> ⚠️ 这里插一句：**手机上那个叫「HDB Interface」的黄叹号，很可能跟你没关系。**
> HDB 是华为/荣耀私有的另一条调试通道。我实测过：**它一直带着黄叹号，adb 照样正常工作。**
> 不少文章把它当病根，但至少在我这台机器上不是。

## A2. 原理：为什么「设备管理器正常」和「adb 能用」是两件事

这一段是全文最想讲清楚的东西。搞懂了，你以后遇到同类问题会自己判断，不用再猜。

### 手机插上电脑，其实是「一个 USB 口挂了 4 个虚拟设备」

Android 手机为了同时提供多种功能，会在一个 USB 连接里拆出好几个**接口（Interface）**。我这台荣耀 GT 拆了 4 个：

| 接口 | 干什么的 |
|---|---|
| `MI_00` | MTP 文件传输（就是你能在「此电脑」里看到手机存储的那个） |
| `MI_01` | 大容量存储（有些手机用它挂一个虚拟光驱） |
| `MI_02` | **ADB 调试** ← adb 要用的就是它 |
| `MI_03` | HDB（华为/荣耀私有的，跟 adb 无关） |

**「设备管理器正常」说的是**：这些接口都装上能用的驱动了，所以传文件、看照片都没问题。
**它完全没说**：adb 要的那个接口，adb 自己能不能找到。**这是两件互不相干的事。**

### 关键概念：驱动程序会给设备挂一块「门牌号」

应用程序要找到某个设备，靠的不是名字，而是一个叫**设备接口 GUID** 的编号（你可以理解成门牌号）。

流程是这样：

1. 驱动安装时，顺便在系统里登记一句：「我这个设备，门牌号是 XXX」
2. Windows 就在注册表的 `DeviceClasses\{XXX}\` 下面建一个条目
3. 程序想知道「有哪些设备挂了 XXX 门牌」，就按这个编号去查

### 而 adb 只认一个固定的门牌号

`adb.exe` 在 Windows 上找设备时，**只会查这一个编号**：

```
{F72FE0D4-CBCB-407D-8814-9ED673D0DD6B}
```

这个号码是 Google 在它官方的 `android_winusb.inf` 驱动里登记的。

**所以：如果没人给你的手机挂上这块牌子，adb 就跟没插一样——它不会报错，也不会说「拒绝连接」，它只是压根不知道你存在。**

### 那我这台机器为什么没挂上？

因为我**从来没在这台电脑上装过任何 Android 驱动**。

手机固件会主动跟 Windows 说一句「请给我装通用的 WinUSB 驱动」，Windows 就用了系统自带的 `winusb.inf` 兜底。这个通用驱动是能用的，但它只登记了另外两个门牌号：一个是微软通用的 WinUSB，一个是手机厂商自己上报的。

**唯独没有 adb 要的那块。**

> 顺带解开一个玄学：网上很多教程说「装个手机助手就好了」「装豌豆荚就好了」「装 360 手机助手就好了」——
> **它们本质上是同一件事**：这些软件带的驱动会把手机厂商那套 INF 装上，而厂商 INF 里恰好也写了 `{F72FE0D4-...}`。
> 它们**碰对了结果，但基本没人说破在干什么**。这就是为什么会出现「装什么乱七八糟的都能好」这种现象。

## A3. 一条命令，判断你是不是这个问题

**PowerShell，不需要管理员**，粘这一条：

```powershell
Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceClasses\{f72fe0d4-cbcb-407d-8814-9ed673d0dd6b}'
```

- 返回 **`False`** → 这块门牌在你系统里从没注册过。**你几乎肯定就是这个问题。**
- 返回 **`True`** → 那你得往别处找，本文这部分帮不上你。

## A4. 方案：把缺的那块门牌补上

思路很简单：**不换驱动、不装任何全家桶，只给手机那个 ADB 接口补一块门牌。**

### 第 1 步：找到你手机的 ADB 接口

**PowerShell，不需要管理员：**

```powershell
Get-PnpDevice -PresentOnly | Where-Object { $_.FriendlyName -match 'ADB' } |
  Select-Object Status, FriendlyName, InstanceId
```

拿到那行 `InstanceId`，长得像这样：

```
USB\VID_339B&PID_107D&MI_02\6&15E2BCA7&0&0002
```

> 如果你的手机接口名不带 "ADB"，可以改用按接口类别找（`Class_ff&SubClass_42&Prot_01`，这是 ADB 的标准类别，任何品牌都一样）：
> ```powershell
> Get-PnpDevice -PresentOnly -Class USBDevice |
>   Where-Object { (Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName DEVPKEY_Device_CompatibleIds).Data -contains 'USB\Class_ff&SubClass_42&Prot_01' }
> ```
> ⚠️ 这条会慢一些——我这台机器上单次属性查询要 2 秒左右。

### 第 2 步：以**管理员**身份开 PowerShell，补上门牌号

```powershell
$inst = '把上一步拿到的 InstanceId 粘这里'
$key  = "HKLM:\SYSTEM\CurrentControlSet\Enum\$inst\Device Parameters"

# 先读出这个接口原本登记的门牌号（手机厂商自己上报的），保留它
$vendor = (Get-ItemProperty -Path $key -Name 'DeviceInterfaceGUID' -ErrorAction SilentlyContinue).DeviceInterfaceGUID

# 厂商的 + Google 的，一起写进去（只追加，不删原来的）
$list = @()
if ($vendor) { $list += $vendor }
$list += '{f72fe0d4-cbcb-407d-8814-9ed673d0dd6b}'

New-ItemProperty -Path $key -Name 'DeviceInterfaceGUIDs' -PropertyType MultiString -Value $list -Force
```

### 第 3 步：让设备重新登记一次（**不用拔线**）

**管理员 PowerShell：**

```powershell
pnputil /restart-device "$inst"
```

### 第 4 步：验证

```powershell
adb devices
```

### 或者直接用一键脚本

上面四步我写成了脚本，在文末**附录**里（完整可复制）。它会自动找接口、自己弹 UAC 提权、跑完自己验证。

### 预期结果

- **看到 `XXXXXX unauthorized`** → 🎉 成了。这就是 §B 的情况，手机解锁点「允许」即可。
- **看到 `XXXXXX device`** → 完全好了。
- **还是空** → 拔插一次线再试；仍然不行，走 A5。

### 这个方案的两个实话

1. **它绑在 USB 端口上**。因为门牌号是记在「设备实例路径」里的，而路径包含端口信息。
   **换个 USB 口就得重跑一次**。想彻底免维护，看 A5 第一条。
2. **改注册表听着吓人，但这里改的东西是可逆的**：删掉写入的那个值，再 `pnputil /restart-device` 一次就恢复原状。
   脚本跑完会把要删的位置打印出来。

## A5. 不想碰注册表的替代方案

**① 装官方驱动（最正统，换个口也不用重做）**

Google 的 USB 驱动下载：`https://dl.google.com/android/repository/usb_driver_r13-windows.zip`

装的时候有个坑：**Google 的 INF 里只列了自家设备的 ID，不会自动匹配你的手机**。所以必须：
设备管理器 → 右键那个 ADB 接口 → 更新驱动程序 → **浏览我的电脑** → **让我从可用列表中选取** → 选 **Android ADB Interface** → 忽略「硬件 ID 不匹配」的警告。

这个流程 Stack Overflow 上有个写得很清楚的答案：
[ADB device list is empty](https://stackoverflow.com/questions/41792867/adb-device-list-is-empty)

**② 无线调试（完全绕开 USB 驱动）**

Android 11 以上都支持：手机开发者选项 → 无线调试 → 用配对码配对 → `adb pair` + `adb connect`。

⚠️ 但有个坑：**校园网、公司网、酒店网经常开了 AP 隔离**（同一个 WiFi 下设备互相看不见）。真遇到就改手机热点。

**③ 装手机厂商的官方助手**

最省事，代价是一整套服务都会装进来。华为/荣耀插上后会在「此电脑」里自动弹出一个虚拟光驱，里面就是官方安装包。

---

# §B `unauthorized`：恭喜，你只差一步

**这是好消息。** 它说明前面所有的坑你都过了——adb 已经能找到手机、通道已经建立，只是手机端还没给你授权。

做法：

1. **解锁手机屏幕**（锁着的话弹窗不显示）
2. 屏幕上会有一个「**是否允许 USB 调试**」的对话框
3. 勾上「**始终允许使用这台计算机进行调试**」，点允许
4. 再跑 `adb devices`，应该就变成 `device` 了

没弹窗？手机开发者选项里找「**撤销 USB 调试授权**」，撤销后重新插线。

> 这里最关键的一点是：**看到 `unauthorized` 千万别去重装驱动。** 那是完全不同的一种病。

---

# §C `offline`

设备出现过，但连接断了。按这个顺序试：

1. `adb reconnect offline`
2. 重插数据线，解锁屏幕
3. 还是不行 → 多半是 adb 版本太旧，[升级 platform-tools](https://developer.android.com/studio/command-line/adb)
   （老版本 adb 对新机型经常 `offline`）

---

# §D 这份指南的边界（说点实在的）

我不想写得跟有些教程一样，好像什么问题都手到擒来。以下是实话：

- 上面的分析**只在我一台机器上完整验证过**：Windows 11 + 荣耀 GT（`AMG-AN00`）+ platform-tools 31.0.3。
- 「门牌号没挂」这个根因**在很多机器上成立**，但**不排除你的情况是别的原因**。A3 那条命令就是给你自查的——如果它返回 `True`，说明你不在这个坑里，别硬套。
- 我**没有**在 Windows 10、其他品牌手机上验证过这套流程。原理上是通用的，但**你要是器材不同，请把 A3 当作第一步**。

**区分一下哪些是实测、哪些是我的推断**：

| 内容 | 性质 |
|---|---|
| 我手机 4 个接口的构成、驱动分别是谁 | 实测 |
| 补门牌号之后 adb 立刻能看到设备 | 实测（修复前后对照） |
| 「所有装助手的偏方本质是同一件事」 | **推断**（原理上说得通，我没逐个数过每个软件的 INF） |
| 「HDB 黄叹号与 adb 无关」 | 实测（我这台机器上黄叹号始终存在，adb 正常工作） |
| 「能充电不等于能传数据」 | 常识 + 符合 USB 规范 |

---

# §E 参考

排查时我用到的、以及写这篇时觉得别人写得好的：

- [人人代码：adb devices 空空如也？手机连不上电脑的分层排查手册](https://www.renrendaima.com/wap/article/2892.html) —— 四层排查框架
- [Stack Overflow: ADB device list is empty](https://stackoverflow.com/questions/41792867/adb-device-list-is-empty) —— 「从列表选取驱动」的标准流程
- [Stack Overflow: My Android device does not appear in the list of adb devices](https://stackoverflow.com/a/53241398) —— 症状和本文几乎一样，可以看到大家的答案有多五花八门
- [Google 官方：Android Debug Bridge (adb)](https://developer.android.com/studio/command-line/adb)

---

## 附：命令速查

| 命令 | 终端 | 权限 |
|---|---|---|
| `adb devices` | cmd / PowerShell | 不需要 |
| `Test-Path '...{f72fe0d4-...}'` | **仅 PowerShell** | 不需要 |
| `Get-PnpDevice ...` | **仅 PowerShell** | 不需要 |
| `Get-PnpDeviceProperty ...` | **仅 PowerShell** | 不需要 |
| `New-ItemProperty ...`（补门牌） | **仅 PowerShell** | **需要管理员** |
| `pnputil /restart-device ...` | cmd / PowerShell | **需要管理员** |

```powershell
# 判断是否缺门牌（不用管理员）
Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceClasses\{f72fe0d4-cbcb-407d-8814-9ed673d0dd6b}'

# 找手机的 ADB 接口
Get-PnpDevice -PresentOnly | ? FriendlyName -match 'ADB'

# 看接口类别（应该是 Class_ff&SubClass_42&Prot_01）
Get-PnpDeviceProperty -InstanceId <你的实例ID> -KeyName DEVPKEY_Device_CompatibleIds

# 看这个接口用的什么驱动、有没有报错（28=驱动未安装，45=设备未连接）
Get-PnpDeviceProperty -InstanceId <你的实例ID> -KeyName DEVPKEY_Device_DriverInfPath
Get-PnpDeviceProperty -InstanceId <你的实例ID> -KeyName DEVPKEY_Device_ProblemCode

# 让设备重新登记（免拔插）
pnputil /restart-device "<你的实例ID>"
```

---

# 附录：一键脚本（fix-adb-guid.ps1）

> 把下面的内容**全部复制**，保存成 `fix-adb-guid.ps1`，然后在文件所在目录开 PowerShell 执行：
>
> ```
> powershell -ExecutionPolicy Bypass -File .\fix-adb-guid.ps1
> ```
>
> 脚本会**自己弹 UAC 提权**，不用你手动开管理员窗口。如果 `adb.exe` 不在 PATH 里，加参数指定：
> `-AdbPath "C:\你的\platform-tools\adb.exe"`
>
> 它就是上面 A4 那四步的自动化版本：自动找 ADB 接口 → 补门牌号 → 重启设备 → 验证。

```powershell
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
```
