<#
.SYNOPSIS
    يرفع المشروع إلى مستودع GitHub جديد بأمر واحد.

.DESCRIPTION
    ماذا يفعل هذا السكربت؟
      1) يتحقق من تثبيت Git
      2) يطلب اسم مستخدم GitHub و Personal Access Token
      3) ينشئ مستودعاً جديداً Public عبر GitHub API (إن لم يكن موجوداً)
      4) يضيف الـ remote ويدفع الفرع main

    كل ما تحتاجه: Personal Access Token بصلاحية repo
      → أنشئه من: https://github.com/settings/tokens/new
      → ✅ فعّل صلاحية repo فقط
      → انسخه (يظهر مرة واحدة)

.NOTES
    ⚠️ التوكن لا يُحفظ في أي ملف — يُقرأ في الذاكرة فقط وينتهي مع السكربت.
    ⚠️ لا تشارك التوكن مع أحد، واحذفه من GitHub بعد الاستخدام إن أردت.

.EXAMPLE
    ./push-to-github.ps1
    ./push-to-github.ps1 -RepoName "my-windows-rdp" -Private
#>
[CmdletBinding()]
param(
    [string] $RepoName = "rdp-github-actions",
    [switch] $Private,
    [string] $Description = "Windows RDP environment via GitHub Actions (for CI/CD, testing and development)"
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Step($n, $msg) { Write-Host "`n[$n] $msg" -ForegroundColor Cyan }
function Done($msg)     { Write-Host "    ✅ $msg" -ForegroundColor Green }
function Fail($msg)     { Write-Host "    ❌ $msg" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------
# 1) التحقق من Git
# ---------------------------------------------------------------
Step 1 "التحقق من تثبيت Git..."
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Write-Host "    Git غير مثبّت." -ForegroundColor Yellow
    Write-Host "    حمّله من: https://git-scm.com/download/win" -ForegroundColor Yellow
    Write-Host "    ثم أعد تشغيل PowerShell وشغّل السكربت مرة أخرى." -ForegroundColor Yellow
    exit 1
}
Done "Git موجود: $($git.Source)"

# ---------------------------------------------------------------
# 2) التحقق من وجود commits
# ---------------------------------------------------------------
Step 2 "التحقق من المستودع المحلي..."
Push-Location $PSScriptRoot
try {
    git rev-parse --git-dir 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    تهيئة مستودع Git جديد..."
        git init -b main | Out-Null
        git add -A
        git commit -m "Initial commit: Windows RDP via GitHub Actions" | Out-Null
    }
    $commits = (git rev-list --count HEAD 2>$null)
    if (-not $commits -or $commits -eq 0) { Fail "لا توجد commits للدفع." }
    Done "عدد الـ commits: $commits"

    # ---------------------------------------------------------------
    # 3) طلب بيانات الدخول
    # ---------------------------------------------------------------
    Step 3 "بيانات GitHub..."
    Write-Host ""
    Write-Host "    🔑 تحتاج Personal Access Token بصلاحية repo" -ForegroundColor Yellow
    Write-Host "    أنشئه من: https://github.com/settings/tokens/new" -ForegroundColor Yellow
    Write-Host ""

    $ghUser  = Read-Host "    اسم مستخدم GitHub"
    if ([string]::IsNullOrWhiteSpace($ghUser)) { Fail "اسم المستخدم مطلوب." }

    $sec = Read-Host "    Personal Access Token (سيُخفى أثناء الكتابة)" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    $ghToken = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    if ([string]::IsNullOrWhiteSpace($ghToken)) { Fail "التوكن مطلوب." }
    Done "تم استلام البيانات"

    $headers = @{
        Authorization = "Bearer $ghToken"
        Accept        = "application/vnd.github+json"
        'User-Agent'  = 'rdp-setup-script'
    }

    # ---------------------------------------------------------------
    # 4) التحقق من التوكن وجلب اسم المستخدم الحقيقي
    # ---------------------------------------------------------------
    Step 4 "التحقق من صلاحية التوكن..."
    try {
        $me = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers -Method Get
        Done "مرحباً $($me.login) — التوكن صالح"
        $ghUser = $me.login
    } catch {
        Fail "التوكن مرفوض. تأكد من صلاحيته ومن تفعيل صلاحية repo.`n$($_.Exception.Message)"
    }

    # ---------------------------------------------------------------
    # 5) إنشاء المستودع
    # ---------------------------------------------------------------
    Step 5 "إنشاء المستودع '$RepoName'..."
    $visibility = if ($Private) { "Private" } else { "Public" }
    Write-Host "    النوع: $visibility"

    $body = @{
        name        = $RepoName
        description = $Description
        private     = [bool]$Private
        auto_init   = $false
    } | ConvertTo-Json

    try {
        $repo = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Headers $headers `
                                  -Method Post -Body $body -ContentType "application/json"
        Done "تم إنشاء المستودع: $($repo.html_url)"
    } catch {
        $resp = $_.ErrorDetails.Message
        if ($resp -match 'already exists') {
            Write-Host "    المستودع موجود مسبقاً — سأتابع الدفع إليه." -ForegroundColor Yellow
            $repo = Invoke-RestMethod -Uri "https://api.github.com/repos/$ghUser/$RepoName" -Headers $headers
        } else {
            Fail "فشل إنشاء المستودع:`n$resp"
        }
    }

    if (-not $Private) {
        Write-Host "    ⚠️  المستودع Public = دقائق Actions غير محدودة مجاناً (هذا ما تريده)." -ForegroundColor Yellow
    } else {
        Write-Host "    ⚠️  المستودع Private = 2000 دقيقة/شهر ومعامل ×2 لساعات Windows." -ForegroundColor Yellow
    }

    # ---------------------------------------------------------------
    # 6) إضافة الـ remote والدفع
    # ---------------------------------------------------------------
    Step 6 "دفع الملفات إلى GitHub..."
    $remoteUrl = "https://${ghUser}:${ghToken}@github.com/$ghUser/$RepoName.git"

    git remote remove origin 2>$null | Out-Null
    git remote add origin $remoteUrl
    git branch -M main
    git push -u origin main 2>&1 | ForEach-Object { Write-Host "    $_" }

    if ($LASTEXITCODE -ne 0) { Fail "فشل الدفع. راجع الرسائل أعلاه." }

    # إزالة التوكن من الـ remote المحفوظ محلياً (أمان)
    git remote set-url origin "https://github.com/$ghUser/$RepoName.git"
    Done "تم الدفع بنجاح"

    # ---------------------------------------------------------------
    # 7) تفعيل صلاحيات Actions عبر API
    # ---------------------------------------------------------------
    Step 7 "تفعيل صلاحيات الكتابة لـ Actions..."
    try {
        $permBody = @{ permission = "write" } | ConvertTo-Json
        Invoke-RestMethod -Uri "https://api.github.com/repos/$ghUser/$RepoName/actions/permissions/workflow" `
                          -Headers $headers -Method Put -Body $permBody -ContentType "application/json" | Out-Null
        Done "Workflow permissions = Read and write"
    } catch {
        Write-Host "    ⚠️  تعذّر ضبطها تلقائياً — اضبطها يدوياً:" -ForegroundColor Yellow
        Write-Host "    Settings → Actions → General → Read and write permissions" -ForegroundColor Yellow
    }

    # ---------------------------------------------------------------
    # 8) الخطوات التالية
    # ---------------------------------------------------------------
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  🎉 اكتمل الرفع!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "  المستودع : https://github.com/$ghUser/$RepoName" -ForegroundColor Cyan
    Write-Host "  Actions  : https://github.com/$ghUser/$RepoName/actions" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  الخطوات المتبقية (3):" -ForegroundColor Yellow
    Write-Host "   1. سجّل في https://dashboard.ngrok.com/signup وانسخ الـ Authtoken"
    Write-Host "   2. أضفه Secret باسم NGROK_AUTHTOKEN في:"
    Write-Host "      https://github.com/$ghUser/$RepoName/settings/secrets/actions/new"
    Write-Host "   3. افتح تبويب Actions → اختر «RDP - Windows + ngrok» → Run workflow"
    Write-Host "      (إن ظهرت رسالة تعطيل، اضغط الزر الأخضر للتفعيل)"
    Write-Host ""
    Write-Host "  🖤 بديل بلا حساب ngrok:" -ForegroundColor Yellow
    Write-Host "     Actions → «Windows Desktop in Browser (بدون حساب)» → Run workflow"
    Write-Host ""
    Write-Host "  🔒 نصيحة: احذف التوكن بعد الانتهاء من:" -ForegroundColor Yellow
    Write-Host "     https://github.com/settings/tokens" -ForegroundColor Yellow
    Write-Host ""
}
finally {
    Pop-Location
}
