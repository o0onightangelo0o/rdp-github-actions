<#
.SYNOPSIS
    يغلق Remote Desktop وينظّف آثار الجلسة (يُستدعى تلقائياً في نهاية الـ workflow).

.DESCRIPTION
    1) يعطّل RDP (fDenyTSConnections = 1).
    2) يوقف عمليات ngrok / cloudflared إن وُجدت.
    3) يحذف حساب المستخدم المؤقت.
    4) يزيل قواعد جدار الحماية المضافة.

.PARAMETER Port
    منفذ RDP الذي تم فتحه.

.PARAMETER Username
    اسم المستخدم المؤقت المراد حذفه (اختياري).

.EXAMPLE
    ./scripts/disable-rdp.ps1 -Port 3389 -Username "ghadmin"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][int]    $Port = 3389,
    [Parameter(Mandatory = $false)][string] $Username = ""
)

$ErrorActionPreference = 'SilentlyContinue'

function Write-Step($msg) { Write-Host "[CLEANUP] $msg" -ForegroundColor Yellow }

# 1) تعطيل RDP
$tsKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
Set-ItemProperty -Path $tsKey -Name 'fDenyTSConnections' -Value 1 -Type DWord
Write-Step "تم تعطيل RDP (fDenyTSConnections = 1)"

# 1b) إزالة بيانات تسجيل الدخول التلقائي (مهم جداً أمنياً)
$wlKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty -Path $wlKey -Name 'AutoAdminLogon'  -Value '0' -Type String
Remove-ItemProperty -Path $wlKey -Name 'DefaultPassword'   -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $wlKey -Name 'DefaultUserName'   -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $wlKey -Name 'DefaultDomainName' -ErrorAction SilentlyContinue
Write-Step "تمت إزالة بيانات Auto-Logon من الريجستري"

# 2) إيقاف عمليات الأنفاق
foreach ($proc in @('ngrok','cloudflared')) {
    Get-Process -Name $proc -ErrorAction SilentlyContinue | Stop-Process -Force
    Write-Step "تم إنهاء عمليات: $proc"
}

# 3) حذف المستخدم المؤقت
if ($Username -ne "") {
    Remove-LocalUser -Name $Username -ErrorAction SilentlyContinue
    Write-Step "تم حذف المستخدم المؤقت: $Username"
}

# 4) إزالة قواعد جدار الحماية
$ruleName = "GH Actions RDP TCP $Port"
Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
Write-Step "تمت إزالة قاعدة جدار الحماية: $ruleName"

# 5) إقفال الشاشة
Write-Step "اكتمل التنظيف."
