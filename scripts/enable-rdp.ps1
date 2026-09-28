<#
.SYNOPSIS
    يفعّل Remote Desktop على جهاز Windows (مصمم ليعمل على GitHub Actions runner).

.DESCRIPTION
    يقوم بما يلي:
      1) إنشاء/تحديث حساب مستخدم محلي وإضافته لمجموعة Remote Desktop Users.
      2) تفعيل RDP في الريجستري (fDenyTSConnections = 0).
      3) تفعيل Network Level Authentication (NLA) - أأمن.
      4) فتح قاعدة جدار الحماية لمنفذ RDP.
      5) ضمان عمل خدمة TermService.

.PARAMETER Username
    اسم المستخدم الذي ستسجل الدخول به.

.PARAMETER Password
    كلمة المرور.

.PARAMETER Port
    منفذ RDP (افتراضي 3389).

.EXAMPLE
    ./scripts/enable-rdp.ps1 -Username "ghadmin" -Password "P@ssw0rd123" -Port 3389
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $Username,
    [Parameter(Mandatory = $true)] [string] $Password,
    [Parameter(Mandatory = $false)][int]   $Port = 3389
)

$ErrorActionPreference = 'Stop'

function Write-Step($msg) { Write-Host "[RDP] $msg" -ForegroundColor Cyan }

# ------------------------------------------------------------------
# 1) التحقق من صلاحيات Administrator
# ------------------------------------------------------------------
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "يجب تشغيل السكربت بصلاحيات Administrator."
}
Write-Step "الصلاحيات: Administrator - تمام"

# ------------------------------------------------------------------
# 2) إنشاء المستخدم المحلي أو تحديث كلمة مروره
# ------------------------------------------------------------------
$securePass = ConvertTo-SecureString $Password -AsPlainText -Force
$existing = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue

if ($null -eq $existing) {
    New-LocalUser -Name $Username -Password $securePass -FullName $Username `
                  -Description "GitHub Actions RDP session user" `
                  -PasswordNeverExpires -UserMayNotChangePassword | Out-Null
    Write-Step "تم إنشاء المستخدم: $Username"
} else {
    Set-LocalUser -Name $Username -Password $securePass
    Write-Step "تم تحديث كلمة مرور المستخدم الموجود: $Username"
}

# إزالة أي حظر على الحساب وتفعيله
Set-LocalUser -Name $Username -PasswordNeverExpires $true
Enable-LocalUser -Name $Username

# ------------------------------------------------------------------
# 3) إضافة المستخدم إلى مجموعة Remote Desktop Users
# ------------------------------------------------------------------
$rdGroup = "Remote Desktop Users"
try {
    Add-LocalGroupMember -Group $rdGroup -Member $Username -ErrorAction Stop
    Write-Step "تمت إضافة $Username إلى '$rdGroup'"
} catch {
    if ($_.Exception.Message -match 'already a member') {
        Write-Step "$Username موجود مسبقاً في '$rdGroup'"
    } else { throw }
}

# ------------------------------------------------------------------
# 4) تفعيل RDP + NLA في الريجستري
# ------------------------------------------------------------------
$tsKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
Set-ItemProperty -Path $tsKey -Name 'fDenyTSConnections' -Value 0 -Type DWord
Write-Step "fDenyTSConnections = 0 (RDP مفعّل)"

$winStations = "$tsKey\WinStations\RDP-Tcp"
if (-not (Test-Path $winStations)) { New-Item -Path $winStations -Force | Out-Null }
Set-ItemProperty -Path $winStations -Name 'UserAuthentication' -Value 1 -Type DWord
Set-ItemProperty -Path $winStations -Name 'SecurityLayer'       -Value 2 -Type DWord
Set-ItemProperty -Path $winStations -Name 'PortNumber'          -Value $Port -Type DWord
Write-Step "NLA مفعّل | المنفذ = $Port"

# ------------------------------------------------------------------
# 5) جدار الحماية
# ------------------------------------------------------------------
try {
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction Stop
    Write-Step "تم تفعيل قواعد جدار الحماية لـ Remote Desktop"
} catch {
    # احتياط لأنظمة لا تحتوي موديول NetSecurity
    netsh advfirewall firewall set rule group="remote desktop" new enable=Yes | Out-Null
    Write-Step "تم تفعيل مجموعة جدار الحماية عبر netsh"
}

# قاعدة صريحة للمنفذ المحدد (في حال تغييره عن 3389)
$ruleName = "GH Actions RDP TCP $Port"
if (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue) {
    Remove-NetFirewallRule -DisplayName $ruleName
}
New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP `
                    -LocalPort $Port -Action Allow -Profile Any | Out-Null
Write-Step "قاعدة جدار حماية جديدة: $ruleName"

# ------------------------------------------------------------------
# 6) التأكد من عمل خدمة Remote Desktop Services
# ------------------------------------------------------------------
foreach ($svc in @('TermService','UmRdpService','SessionEnv','RpcSs')) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($null -ne $s) {
        Set-Service -Name $svc -StartupType Automatic -ErrorAction SilentlyContinue
        if ($s.Status -ne 'Running') { Start-Service -Name $svc -ErrorAction SilentlyContinue }
    }
}
Write-Step "خدمات RDP تعمل"

# ------------------------------------------------------------------
# 7) ⭐ الأهم: تسجيل الدخول التلقائي (Auto-Logon)
#    ---------------------------------------------------------
#    لماذا هذه الخطوة حاسمة؟
#    على GitHub Actions runner يعمل الوكيل كخدمة بدون جلسة سطح مكتب
#    تفاعلية. عند الاتصال عبر RDP قد تحصل على شاشة سوداء أو يتوقف
#    الوكيل. تفعيل Auto-Logon ينشئ جلسة Console تفاعلية حقيقية،
#    وعندما تتصل عبر RDP تستلم تلك الجلسة نفسها (لا تُنشأ جلسة جديدة).
# ------------------------------------------------------------------
$wlKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty -Path $wlKey -Name 'AutoAdminLogon'    -Value '1'       -Type String
Set-ItemProperty -Path $wlKey -Name 'DefaultUserName'   -Value $Username -Type String
Set-ItemProperty -Path $wlKey -Name 'DefaultPassword'   -Value $Password -Type String
Set-ItemProperty -Path $wlKey -Name 'DefaultDomainName' -Value '.'       -Type String
Set-ItemProperty -Path $wlKey -Name 'AutoLogonCount'    -Value 999       -Type DWord -ErrorAction SilentlyContinue
Write-Step "تم تفعيل Auto-Logon للمستخدم $Username (يمنع الشاشة السوداء)"

# إلغاء شاشة الترحيب/الإشعارات القانونية التي قد تحجب الجلسة
$sysKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
if (Test-Path $sysKey) {
    Set-ItemProperty -Path $sysKey -Name 'legalnoticecaption' -Value '' -Type String -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $sysKey -Name 'legalnoticetext'    -Value '' -Type String -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $sysKey -Name 'EnableLUA'          -Value 1  -Type DWord  -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------------
# 8) منع القفل التلقائي للشاشة وإيقاف شاشة التوقف
# ------------------------------------------------------------------
$polKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'
if (-not (Test-Path $polKey)) { New-Item -Path $polKey -Force | Out-Null }
Set-ItemProperty -Path $polKey -Name 'NoLockScreen' -Value 1 -Type DWord -ErrorAction SilentlyContinue

# تعطيل شاشة التوقف عبر سياسة المجموعة
$ctrlKey = 'HKCU:\Control Panel\Desktop'
Set-ItemProperty -Path $ctrlKey -Name 'ScreenSaveActive'     -Value '0' -Type String -ErrorAction SilentlyContinue
Set-ItemProperty -Path $ctrlKey -Name 'ScreenSaveTimeOut'    -Value '0' -Type String -ErrorAction SilentlyContinue

# منع قفل الجلسة عند الخمول (بالدقائق -> 0 = أبداً)
$powerKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings'
if (-not (Test-Path $powerKey)) { New-Item -Path $powerKey -Force | Out-Null }
Write-Step "تم تعطيل قفل الشاشة وشاشة التوقف"

# ------------------------------------------------------------------
# 8) ملخص
# ------------------------------------------------------------------
Write-Host ""
Write-Host "================= RDP READY =================" -ForegroundColor Green
Write-Host " Username : $Username"
Write-Host " Port     : $Port"
Write-Host " NLA      : Enabled"
Write-Host " Computer : $env:COMPUTERNAME"
Write-Host "================================================" -ForegroundColor Green
