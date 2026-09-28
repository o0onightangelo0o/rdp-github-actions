<#
.SYNOPSIS
    يولّد ملف .rdp جاهزاً للنقر المزدوج (يفتح Remote Desktop Connection مباشرة).

.DESCRIPTION
    أنشئ ملفاً باسم "GitHub-RDP.rdp" على سطح المكتب، ثم انقره نقراً مزدوجاً
    ليفتح mstsc مع كل الإعدادات محضّرة: ملء الشاشة، الصوت، الحافظة، الأقراص.

.PARAMETER RdpHost
    عنوان النفق (مثال: 0.tcp.ngrok.io)

.PARAMETER Port
    المنفذ (مثال: 12345)

.PARAMETER Username
    اسم المستخدم

.PARAMETER OutFile
    مسار ملف الإخراج (افتراضي: سطح المكتب)

.EXAMPLE
    ./scripts/make-rdp-file.ps1 -RdpHost "0.tcp.ngrok.io" -Port 12345 -Username "ghadmin"

.NOTES
    ⚠️ مفاتيح ملف .rdp حساسة لحالة الأحرف (case-sensitive) وتُكتب بصيغة:
       key:type:value   حيث type هي  s=نص ، i=رقم ، b=منطقي
    الملف يُحفظ بترميز Unicode (UTF-16 LE) كما يتوقعه mstsc.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $RdpHost,
    [Parameter(Mandatory = $true)][int]    $Port,
    [Parameter(Mandatory = $true)][string] $Username,
    [Parameter(Mandatory = $false)][string] $OutFile
)

if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $OutFile = Join-Path ([Environment]::GetFolderPath('Desktop')) 'GitHub-RDP.rdp'
}

# مصفوفة الإعدادات - المفاتيح بحالة الأحرف الصحيحة المطلوبة
$lines = @(
    "full address:s:${RdpHost}:${Port}"
    "username:s:$Username"
    "screen mode id:i:2"            # 2 = ملء الشاشة، 1 = نافذة
    "desktopwidth:i:1920"
    "desktopheight:i:1080"
    "session bpp:i:32"
    "compression:i:1"
    "keyboardhook:i:2"              # تطبيق اختصارات Windows داخل الجلسة
    "audiocapturemode:i:1"
    "audiomode:i:0"                 # 0 = تشغيل الصوت من الجهاز البعيد
    "redirectprinters:i:1"
    "redirectclipboard:i:1"         # نسخ/لصق بين الجهازين
    "redirectdrives:i:1"
    "drivestoredirect:s:*"          # مشاركة كل الأقراص المحلية
    "prompt for credentials:i:0"
    "negotiate security layer:i:1"
    "authentication level:i:0"      # 0 = اتصال رغم تحذير الشهادة (مهم مع ngrok)
    "networkautodetect:i:1"
    "bandwidthautodetect:i:1"
    "displayconnectionbar:i:1"
    "enableworkspacereconnect:i:0"
    "videoplaybackmode:i:1"
    "use multimon:i:0"
    "gatewayusagemethod:i:0"
    "promptcredentialonce:i:0"
)

# كتابة بترميز Unicode لأن mstsc يتوقعه مع النصوص غير اللاتينية
Set-Content -Path $OutFile -Value $lines -Encoding Unicode

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host " تم إنشاء ملف الاتصال بنجاح" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host " المسار   : $OutFile"
Write-Host " العنوان  : ${RdpHost}:${Port}"
Write-Host " المستخدم : $Username"
Write-Host ""
Write-Host " انقر الملف نقراً مزدوجاً للاتصال مباشرة." -ForegroundColor Yellow
Write-Host " ستُطلب كلمة المرور عند فتح النافذة." -ForegroundColor Yellow
Write-Host ""
