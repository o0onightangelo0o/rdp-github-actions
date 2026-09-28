# 🩺 حل المشكلات الشائعة

مرتب حسب مرحلة المشكلة. ابحث عن الرسالة التي تراها.

---

## المرحلة 1: الـ Workflow لا يظهر أو لا يعمل

### المشكلة: لا أرى تبويب Actions أصلاً
**السبب:** المستودع فارغ.
**الحل:** ارفع الملفات. يجب أن يظهر مجلد `.github` داخل المستودع.

---

### المشكلة: مجلد `.github` لا يظهر عند الرفع
**السبب:** Windows/المتصفح يخفي المجلدات التي تبدأ بنقطة، أو رفعت الملفات بدون مجلداتها.
**الحل:**
1. افتح **File Explorer** ← **View** ← ✅ **Hidden items**
2. أو استخدم Git بدلاً من الرفع اليدوي (الطريقة B في SETUP.md)
3. للتحقق: افتح <https://github.com/اسمك/مستودعك/tree/main/.github/workflows>
   يجب أن ترى ملفات `.yml`

---

### المشكلة: "Workflows aren't being run on this repository"
**السبب:** GitHub يعطّل الـ workflows في المستودعات الجديدة لأسباب أمنية.
**الحل:** اضغط الزر الأخضر داخل الرسالة:
**I understand my workflows, go ahead and run them**

---

### المشكلة: زر "Run workflow" غير موجود
**السبب:** خطأ في صياغة YAML.
**الحل:**
1. افتح الملف على GitHub ← انظر هل تظهر رسالة خطأ حمراء أعلى الملف
2. تحقق من المسافة البادئة (YAML حساس للمسافات — **ممنوع استخدام Tab**)
3. انسخ الملف من جديد كما هو بدون تعديل

---

### المشكلة: `Resource not accessible by integration`
**السبب:** صلاحيات الـ workflow للقراءة فقط.
**الحل:**
**Settings → Actions → General → Workflow permissions → ✅ Read and write permissions → Save**

---

## المرحلة 2: فشل خطوة Enable Remote Desktop

### الرسالة: `The term './scripts/enable-rdp.ps1' is not recognized`
**السبب:** لم تُرفع ملفات `scripts/` أو لم تُنفَّذ خطوة Checkout.
**الحل:** تأكد أن `- uses: actions/checkout@v4` هي **الخطوة الأولى** في الـ job.

---

### الرسالة: `running scripts is disabled on this system`
**السبب:** سياسة تنفيذ PowerShell.
**الحل:** أضف في بداية الخطوة:
```yaml
- name: Enable Remote Desktop
  shell: pwsh
  run: |
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    ./scripts/enable-rdp.ps1 -Username ... -Password ...
```

---

### الرسالة: `Add-LocalGroupMember : Failed to compare two elements in the array`
**السبب:** مشكلة معروفة في بعض صور runners مع أسماء المجموعات المعرّبة.
**الحل:** استخدم SID بدلاً من الاسم:
```powershell
$group = Get-LocalGroup | Where-Object { $_.SID -like 'S-1-5-32-555' }
Add-LocalGroupMember -Group $group.Name -Member $Username
```

---

### الرسالة: `No service was found`
**السبب:** خدمات RDP غير مثبتة في صورة الـ runner.
**الحل:** مثبّتة عملياً دائماً في `windows-latest`. إن حدث، نفّذ:
```powershell
Install-WindowsFeature RDS-RD-Server -IncludeAllSubFeature
Restart-Service TermService -Force
```

---

## المرحلة 3: مشاكل ngrok

### الرسالة: `ERR_NGROK_105` أو `invalid authtoken`
**السبب:** التوكن خاطئ أو منسوخ ناقصاً.
**الحل:**
1. اذهب إلى <https://dashboard.ngrok.com/get-started/your-authtoken>
2. انسخه كاملاً (يبدأ بـ `2`)
3. احذف الـ Secret القديم وأضفه من جديد
4. ⚠️ تأكد أنك أضفته في **Secrets** وليس **Variables**

---

### الرسالة: `ERR_NGROK_4011` أو `too many connections`
**السبب:** الخطة المجانية تسمح بنفق واحد فقط، ولديك نفق آخر نشط.
**الحل:**
```powershell
# في لوحة ngrok: Tunnels → أوقف أي نفق آخر
# أو على جهازك
ngrok api -m GET https://api.ngrok.com/tunnels
```
انتظر دقيقتين بعد إنهاء أي جلسة سابقة ثم أعد التشغيل.

---

### الرسالة: `account requires email verification`
**السبب:** لم تفعّل حساب ngrok.
**الحل:** افتح رسالة التفعيل في بريدك واضغط الرابط.

---

### المشكلة: خطوة `Show RDP connection info` تفشل بـ "تعذّر الحصول على عنوان النفق"
**السبب:** ngrok لم يبدأ بعد، أو أن المنفذ 4040 محجوز.
**الحل:**
1. زد زمن الانتظار: غيّر `Start-Sleep -Seconds 8` إلى `20`
2. شخّص بقراءة سجل ngrok:
```yaml
- name: Debug ngrok
  if: failure()
  shell: pwsh
  run: Get-Content "$env:RUNNER_TEMP\ngrok.log" -ErrorAction SilentlyContinue
```

---

## المرحلة 4: مشاكل الاتصال من جهازك

### الرسالة: `Your computer can't connect to the remote computer`
**أسباب محتملة وحلولها:**

| السبب | الحل |
|---|---|
| كتبت العنوان بدون المنفذ | الصيغة الصحيحة: `0.tcp.ngrok.io:12345` |
| مسافة قبل أو بعد النقطتين | احذف أي مسافة |
| الـ Run انتهى | تحقق أن الـ Run ما زال بدائرة صفراء |
| نفق ngrok سقط | أعد تشغيل الـ workflow |
| جدار حمايتك أنت يحجب | جرّب شبكة أخرى أو هاتفك (Hotspot) |

**اختبار سريع للاتصال** من PowerShell على جهازك:
```powershell
Test-NetConnection -ComputerName "0.tcp.ngrok.io" -Port 12345
```
إذا كانت `TcpTestSucceeded : False` فالمشكلة في النفق، لا في جهازك.

---

### الرسالة: `The remote computer requires Network Level Authentication`
**السبب:** تطبيق mstsc لديك قديم.
**الحل:**
1. حدّث **Windows App** / **Microsoft Remote Desktop** من Microsoft Store
2. أو عطّل NLA مؤقتاً في السكربت (غير مستحسن):
```powershell
Set-ItemProperty -Path "$tsKey\WinStations\RDP-Tcp" -Name 'UserAuthentication' -Value 0
```

---

### الرسالة: `The credentials that were used to connect... did not match`
**السبب:** mstsc يحفظ بيانات قديمة.
**الحل:**
1. في نافذة mstsc اضغط **Show Options** ← تبويب **Advanced**
2. أو امسح البيانات المحفوظة:
```cmd
cmdkey /list
cmdkey /delete:LegacyGeneric:target=TERMSRV/0.tcp.ngrok.io
```

---

### المشكلة: الشاشة سوداء بعد تسجيل الدخول
**الحل بالترتيب:**
1. انتظر 20-30 ثانية (أول جلسة بطيئة)
2. اضغط `Ctrl + Alt + End` (بديل Ctrl+Alt+Del داخل RDP)
3. حرك الماوس واضغط `Esc`
4. سجّل الخروج وادخل مجدداً
5. جرّب دقة أقل: في mstsc ← Display ← حرّك المؤشر إلى 1280×720

---

### المشكلة: لوحة المفاتيح تكتب رموزاً خاطئة
**السبب:** اختلاف تخطيط لوحة المفاتيح (العربية/الإنجليزية).
**الحل:** داخل الجهاز البعيد: **Settings → Time & Language → Language** ←
أضف **English (United States)** واجعله الافتراضي، أو اضغط `Alt + Shift` للتبديل.

---

### المشكلة: الاتصال بطيء جداً / الصورة متقطعة
**الحلول بالترتيب:**
1. في mstsc ← تبويب **Experience** ← اختر **Modem (56 kbps)** لتقليل المؤثرات
2. في تبويب **Display** ← قلّل الدقة إلى 1280×720 و 16-bit color
3. أغلق البرامج المستهلكة للشبكة داخل الجهاز البعيد
4. جرّب الاتصال بسلك بدل الواي فاي
5. تحقق من سرعة خطك: تحتاج 5 Mbps على الأقل

---

## المرحلة 5: مشاكل الوقت والحصص

### الرسالة: `The job has exceeded the maximum job execution time of 360 minutes`
**السبب:** وصلت الحد الأقصى المسموح من GitHub (6 ساعات).
**الحل:** لا يوجد — شغّل workflow جديد. احفظ ملفاتك قبل الدقيقة 350.

---

### المشكلة: الدقائق تُستهلك بسرعة في مستودع خاص
**السبب:** ساعات Windows تُحسب بمعامل ×2 في المستودعات الخاصة.
**الحل:** اجعل المستودع **Public** ← Settings ← انزل لآخر الصفحة ←
**Change repository visibility → Public**

---

### المشكلة: `The request was aborted: Could not create SSL/TLS secure channel`
**السبب:** TLS قديم في pwsh.
**الحل:** أضف في بداية الخطوة:
```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

---

## المرحلة 6: تشخيص شامل

### أضف هذه الخطوة لأي workflow لفهم ما يحدث
```yaml
      - name: "🔍 Diagnostics"
        if: always()
        shell: pwsh
        run: |
          Write-Host "=== System Info ==="
          systeminfo | Select-Object -First 12
          Write-Host "`n=== RDP Registry ==="
          Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' |
            Select-Object fDenyTSConnections
          Write-Host "`n=== Listening Ports ==="
          Get-NetTCPConnection -State Listen |
            Select-Object LocalAddress,LocalPort,OwningProcess | Sort-Object LocalPort
          Write-Host "`n=== Users ==="
          Get-LocalUser | Select-Object Name,Enabled,LastLogon
          Write-Host "`n=== ngrok process ==="
          Get-Process ngrok -ErrorAction SilentlyContinue
          Write-Host "`n=== ngrok log (last 30) ==="
          Get-Content "$env:RUNNER_TEMP\ngrok.log" -Tail 30 -ErrorAction SilentlyContinue
          Write-Host "`n=== Firewall RDP rules ==="
          Get-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue |
            Select-Object DisplayName,Enabled,Direction,Action
```

### طريقة عرض سجل ngrok المحلي أثناء الجلسة
بعد الاتصال بالجهاز، افتح متصفحاً داخله واذهب إلى:
```
http://127.0.0.1:4040
```
سترى كل الاتصالات والطلبات الحية عبر النفق.

---

## ❓ لم تجد حلّك؟

1. افتح الـ Run الفاشل ← اضغط على الخطوة الحمراء ← انسخ آخر 20 سطراً
2. ابحث عن نص الخطأ في <https://github.com/search?q=الخطأ&type=discussions>
3. وثائق GitHub Actions: <https://docs.github.com/en/actions>
4. وثائق ngrok: <https://ngrok.com/docs/errors>
