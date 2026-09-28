# 📖 دليل الإعداد التفصيلي خطوة بخطوة

هذا الدليل يأخذك من الصفر حتى الاتصال الأول بجهاز Windows عبر GitHub Actions.

---

## الجزء الأول: إنشاء حساب GitHub (إن لم يكن لديك)

1. اذهب إلى <https://github.com/signup>
2. أدخل بريدك الإلكتروني واختر اسم مستخدم وكلمة مرور
3. **أكمل التحقق (CAPTCHA)** ثم فعّل الحساب من بريدك
4. اختر الخطة المجانية **Free** — هي كل ما تحتاجه

> 💡 حساب GitHub مجاني واحد يكفي. لا تحتاج GitHub Pro.

---

## الجزء الثاني: إنشاء المستودع

1. بعد تسجيل الدخول اضغط زر **+** أعلى اليمين ← **New repository**
   أو اذهب مباشرة إلى <https://github.com/new>

2. املأ الحقول:

   | الحقل | القيمة |
   |---|---|
   | Repository template | No template |
   | Owner | اسمك |
   | **Repository name** | `rdp-github-actions` |
   | Description | `Windows RDP environment via GitHub Actions` |
   | **Public / Private** | ⚠️ **Public** (مهم جداً — انظر السبب أدناه) |
   | Add README | ✅ مفعّل |
   | .gitignore | None |
   | License | None |

3. اضغط **Create repository**

### لماذا Public وليس Private؟

| | Public | Private |
|---|---|---|
| دقائق Actions | **غير محدودة مجاناً** | 2000 دقيقة/شهر |
| معامل Windows | 1× (دقيقة = دقيقة) | **2×** (دقيقة = دقيقتان) |
| جلسات 6 ساعات متكررة | ✅ ممكنة | ❌ تستنفد حصتك بسرعة |
| من يرى الكود | الجميع | أنت فقط |

**الخلاصة:** اختر Public. الكود ليس سرياً (كل الأسرار في Secrets مشفّرة).

---

## الجزء الثالث: رفع ملفات المشروع

### الطريقة A — من المتصفح (الأسهل، بلا أدوات)

1. حمّل مجلد `rdp-github-actions` من مساحة العمل إلى جهازك
2. داخل مستودعك على GitHub اضغط **Add file** ← **Upload files**
3. **اسحب المجلدات** (`.github`، `scripts`، `docs`) إلى المنطقة المخصصة
   ⚠️ تأكد أن GitHub يحافظ على هيكل المجلدات — يجب أن ترى:
   ```
   .github/workflows/rdp-ngrok.yml
   .github/workflows/desktop-browser.yml
   .github/workflows/rustdesk-no-account.yml
   .github/workflows/rdp-hardened.yml
   scripts/enable-rdp.ps1
   scripts/disable-rdp.ps1
   scripts/restart-to-console.ps1
   scripts/make-rdp-file.ps1
   docs/SETUP.md
   docs/SECURITY.md
   docs/TROUBLESHOOTING.md
   ```
4. انزل لأسفل الصفحة واكتب رسالة الـ Commit ← **Commit changes**

> ❗ **الخطأ الأكثر شيوعاً:** رفع الملفات بدون المجلدات. إن لم يظهر مجلد
> `.github` بالضبط بهذا الاسم (مع النقطة في البداية)، لن يعمل أي شيء.

### الطريقة B — عبر Git من جهازك

```bash
# 1) ثبّت Git من https://git-scm.com/download/win

# 2) افتح PowerShell داخل مجلد المشروع
cd C:\path\to\rdp-github-actions

# 3) هيّئ المستودع
git init
git add .
git commit -m "Initial commit: Windows RDP via GitHub Actions"
git branch -M main

# 4) اربطه بمستودعك على GitHub
git remote add origin https://github.com/اسمك/rdp-github-actions.git

# 5) ارفع
git push -u origin main
```

عند الطلب أدخل اسم مستخدم GitHub وكلمة المرور... **لا!** GitHub ألغى كلمات
المرور لـ Git. تحتاج **Personal Access Token**:
1. اذهب إلى <https://github.com/settings/tokens>
2. **Generate new token (classic)**
3. الصلاحيات: ✅ `repo`
4. انسخ التوكن واستخدمه **مكان كلمة المرور** عند الدفع

---

## الجزء الرابع: إعداد صلاحيات Actions

خطوة كثير من الناس ينساها فتفشل الـ workflows:

1. داخل مستودعك: **Settings** ← **Actions** ← **General**
2. انزل إلى قسم **Workflow permissions**
3. اختر: ✅ **Read and write permissions**
4. ✅ فعّل **Allow GitHub Actions to create and approve pull requests** (اختياري)
5. اضغط **Save**

---

## الجزء الخامس: الحصول على ngrok Authtoken

1. اذهب إلى <https://dashboard.ngrok.com/signup>
2. الأسهل: اضغط **Sign up with GitHub** (لا حاجة لكلمة مرور جديدة)
3. أكمل التسجيل وفعّل الحساب
4. من القائمة الجانبية: **Your Authtoken**
   أو مباشرة: <https://dashboard.ngrok.com/get-started/your-authtoken>
5. انسخ التوكن (يبدأ بـ `2abc...` — نص طويل)

### إضافة التوكن إلى المستودع كـ Secret

1. في مستودعك: **Settings** ← **Secrets and variables** ← **Actions**
2. تأكد أنك في تبويب **Secrets** (وليس Variables)
3. اضغط **New repository secret**
4. املأ:
   - **Name:** `NGROK_AUTHTOKEN` ← ⚠️ بالضبط بهذا الاسم، أحرف كبيرة
   - **Secret:** الصق التوكن
5. اضغط **Add secret**

> 🔐 الـ Secrets مشفّرة ولا يمكن قراءتها مرة أخرى بعد حفظها — هذا مقصود.

---

## الجزء السادس: التشغيل والاتصال

### 1) تفعيل الـ Workflows
- اذهب إلى تبويب **Actions** في مستودعك
- إن رأيت رسالة "Workflows aren't being run on this repository"
  ← اضغط الزر **I understand my workflows, go ahead and run them**

### 2) شغّل الجلسة
- من القائمة اليسرى اختر **RDP - Windows + ngrok**
- أعلى اليمين اضغط **Run workflow** ← اختر الفرع `main`
- اختر:
  - `session_minutes`: المدة (جرّب `60` في أول مرة)
  - `rdp_user`: اتركه `ghadmin`
  - `rdp_port`: اتركه `3389`
- اضغط الزر الأخضر **Run workflow**

### 3) انتظر التحضير (~2-4 دقائق)
سيظهر run جديد بلون أصفر. اضغط عليه وراقب الخطوات:

| الخطوة | الوقت التقريبي |
|---|---|
| Set up job | ~15 ثانية |
| Checkout repository | ~5 ثوانٍ |
| Generate session credentials | فوري |
| Enable Remote Desktop | ~10 ثوانٍ |
| Install ngrok | ~15 ثانية |
| Start ngrok tunnel | ~10 ثوانٍ |
| **Show RDP connection info** | ← **هنا تظهر البيانات** |
| Keep session alive | يستمر حتى النهاية |

### 4) اقرأ بيانات الاتصال
- ارجع لأعلى صفحة الـ Run
- ستجد صندوق **Summary** يحتوي جدولاً بالـ Host و Port و User و Pass
- إن لم يظهر، اضغط على خطوة **Show RDP connection info** واقرأ اللوج

### 5) اتصل من Windows
```
1. اضغط Win + R
2. اكتب: mstsc
3. Enter
4. في حقل "Computer" اكتب: 0.tcp.ngrok.io:12345
   (استبدل بالقيم من الـ Summary)
5. Connect
6. تحذير الشهادة → ✅ "Don't ask me again" → Yes
7. Username: ghadmin
8. Password: (من الـ Summary)
9. OK
```

🎉 **أنت الآن داخل جهاز Windows يعمل على خوادم GitHub!**

> 🖤 **إن رأيت شاشة سوداء:** انتظر 20 ثانية، حرّك الماوس، اضغط `Ctrl+Alt+End`.
> إن استمرت المشكلة فالحل المضمون هو تشغيل workflow
> **"Windows Desktop in Browser (بدون حساب)"** — يستخدم TightVNC الذي يلتقط
> شاشة جلسة الـ Console مباشرة ويعمل بلا إعادة تشغيل وبلا حساب ngrok.
>
> 🔁 **إعادة التشغيل كحل بديل:** شغّل `rdp-ngrok.yml` مرة أخرى مع
> `restart_machine = true`. سيعيد تشغيل الجهاز لينشئ جلسة Console تفاعلية.
> ⚠️ ستُقطع خطوات الـ workflow بعد إعادة التشغيل (متوقع) — انسخ بيانات
> الاتصال من الخطوة السابقة أولاً، وانتظر ~90 ثانية ثم اتصل.

---

## الجزء السابع: إنشاء ملف اتصال دائم (اختياري لكنه مريح)

بدل كتابة العنوان كل مرة، ولّد ملف `.rdp`:

```powershell
# على جهازك، من داخل مجلد المشروع
./scripts/make-rdp-file.ps1 -RdpHost "0.tcp.ngrok.io" -Port 12345 -Username "ghadmin"
```

سيُنشئ `GitHub-RDP.rdp` على سطح المكتب — انقره نقراً مزدوجاً مستقبلاً.

> ⚠️ العنوان يتغير في كل تشغيل جديد للـ workflow، لذا حدّث الملف عند الحاجة.

---

## الجزء الثامن: ما يجب معرفته عن نهاية الجلسة

- بعد `session_minutes` تتوقف الخطوة الأخيرة ويُنفَّذ **Cleanup** تلقائياً
- **الجهاز يُدمَّر بالكامل** — كل ما حمّلته أو أنشأته يختفي
- لإيقاف الجلسة يدوياً: صفحة الـ Run ← **Cancel workflow**
- لبدء جلسة جديدة: شغّل الـ workflow مرة أخرى

### 💾 كيف تحفظ عملك قبل النهاية
| الطريقة | كيف |
|---|---|
| مستودع Git | `git push` داخل الجهاز |
| Google Drive | حمّل المتصفح وسجّل الدخول وارفع |
| رابط مباشر | ارفع على <https://transfer.sh> أو <https://file.io> |
| مشاركة الأقراص | مفعّلة افتراضياً في ملف `.rdp` — انسخ لمجلدك المحلي |

---

## 🔜 الخطوة التالية

- اقرأ [`SECURITY.md`](SECURITY.md) لتقوية الإعداد
- عند المشاكل راجع [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md)
