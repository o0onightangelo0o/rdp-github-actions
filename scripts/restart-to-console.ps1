<#
.SYNOPSIS
    يعيد تشغيل الجهاز (اختياري) لإنشاء جلسة Console تفاعلية.

.DESCRIPTION
    متى تحتاج هذا؟
    ------------------------------------------------------------------
    على GitHub Actions runner يعمل وكيل Actions كخدمة في Session 0
    (جلسة غير تفاعلية). في أغلب الحالات يكفي Auto-Logon للحصول على
    سطح مكتب سليم عبر RDP. لكن إن ظهرت لك:
        • شاشة سوداء بعد تسجيل الدخول
        • نوافذ لا ترسم بشكل صحيح
        • برامج GUI ترفض الإقلاع
    فأعد التشغيل بهذا السكربت ليتم Auto-Logon فعلياً وتُنشأ جلسة Console.

    ⚠️ تنبيه مهم:
    إعادة التشغيل تُنهي وكيل Actions، لذلك ستتوقف الخطوات اللاحقة في
    الـ workflow. لهذا السبب يُستخدم هذا السكربت كـ "خطوة أخيرة اختيارية"
    مع continue-on-error: true، وتُقرأ بيانات الاتصال من الخطوة السابقة.

    💡 البديل الموصى به (بلا إعادة تشغيل):
    استخدم workflow "Windows Desktop in Browser" — يشغّل TightVNC كخدمة
    ويلتقط شاشة جلسة الـ Console مباشرة، فيعمل بشكل موثوق بدون إعادة تشغيل.

.EXAMPLE
    ./scripts/restart-to-console.ps1
    ./scripts/restart-to-console.ps1 -DelaySeconds 20
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][int] $DelaySeconds = 15
)

$ErrorActionPreference = 'SilentlyContinue'

Write-Host ""
Write-Host "==============================================" -ForegroundColor Yellow
Write-Host " سيتم إعادة تشغيل الجهاز بعد $DelaySeconds ثانية" -ForegroundColor Yellow
Write-Host "==============================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "⚠️  سيتوقف وكيل Actions — وهذا متوقع."
Write-Host "📋 انسخ بيانات الاتصال من الخطوة السابقة قبل المتابعة."
Write-Host "🔌 بعد ~90 ثانية سيتصل الجهاز تلقائياً بالجلسة (Auto-Logon)."
Write-Host ""

# طريقة 1: أمر shutdown المباشر (الأبسط)
Start-Process -FilePath "shutdown.exe" -ArgumentList "/r","/t","$DelaySeconds","/f", `
              "/c","GitHub Actions RDP - creating console session" -WindowStyle Hidden

Write-Host "تم جدولة إعادة التشغيل." -ForegroundColor Green

# إعطاء مهلة لطباعة الرسالة قبل انقطاع الوكيل
Start-Sleep -Seconds ([Math]::Min(5, $DelaySeconds))
