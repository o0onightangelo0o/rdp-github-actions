# 🔒 دليل الأمان والتعزيز

الهدف: استخدام هذه البيئة بأقل مخاطرة ممكنة.

---

## 1️⃣ فهم نموذج المخاطرة

عند تشغيل جلسة RDP عبر GitHub Actions، أنت تُعرّض جهاز Windows للإنترنت
عبر نفق عام (ngrok / Cloudflare). أي شخص يحصل على **العنوان + المنفذ + كلمة المرور**
يدخل الجهاز بصلاحيات كاملة.

**مصادر الخطر بالترتيب:**

| الخطر | الاحتمال | الأثر |
|---|---|---|
| تسرّب كلمة المرور عبر سجلات Actions | **عالي** إن كتبتها في الملف | حرج |
| مشاركة رابط النفق مع آخرين | متوسط | حرج |
| مسح ضوئي عشوائي لمنافذ ngrok | منخفض (العنوان عشوائي) | متوسط |
| تسجيل بيانات حساسة داخل الجهاز | **سلوكك أنت** | حرج |
| إيقاف الحساب لمخالفة شروط GitHub | **مرتفع مع الاستخدام المفرط** | حرج |

---

## 2️⃣ القاعدة الذهبية: لا أسرار داخل الملفات

### ❌ خطأ شائع (لا تفعله)
```yaml
- name: Enable RDP
  run: |
    ./scripts/enable-rdp.ps1 -Username "admin" -Password "MySecret123!"
```
هذه الكلمة ستظهر في:
- سجلات الـ Run العامة (أي شخص يراها!)
- تاريخ الـ commits للأبد
- أي fork للمستودع

### ✅ الطريقة الصحيحة
```yaml
- name: Enable RDP
  env:
    RDP_USER: ${{ secrets.RDP_USERNAME }}
    RDP_PASS: ${{ secrets.RDP_PASSWORD }}
  run: |
    Write-Host "::add-mask::$env:RDP_PASS"   # يخفيها في كل السجلات
    ./scripts/enable-rdp.ps1 -Username $env:RDP_USER -Password $env:RDP_PASS
```

### الأسرار المطلوبة للنسخة المؤمّنة
في **Settings → Secrets and variables → Actions** أضف:

| اسم الـ Secret | القيمة |
|---|---|
| `NGROK_AUTHTOKEN` | توكن ngrok |
| `RDP_USERNAME` | اسم مستخدم تختاره (مثال `winuser`) |
| `RDP_PASSWORD` | كلمة مرور قوية (16+ حرفاً) |
| `TELEGRAM_BOT_TOKEN` | اختياري — لاستقبال بيانات الاتصال في تيليجرام |
| `TELEGRAM_CHAT_ID` | اختياري — معرّف محادثتك |

### توليد كلمة مرور قوية
```powershell
# على جهازك في PowerShell
-join ((48..57)+(65..90)+(97..122) | Get-Random -Count 20 | ForEach-Object {[char]$_})
```

---

## 3️⃣ لماذا NLA مهم؟ (مفعّل افتراضياً في السكربت)

**Network Level Authentication** يجبر العميل على إثبات هويته *قبل* إنشاء
جلسة RDP كاملة. بدونه:
- يستطيع أي مهاجم استهلاك موارد الجهاز بطلبات اتصال فارغة
- تُستغل ثغرات RDP القديمة (مثل BlueKeep CVE-2019-0708) بسهولة أكبر

السكربت يفعّله عبر:
```powershell
Set-ItemProperty -Path "$tsKey\WinStations\RDP-Tcp" -Name 'UserAuthentication' -Value 1
Set-ItemProperty -Path "$tsKey\WinStations\RDP-Tcp" -Name 'SecurityLayer' -Value 2
```

> ⚠️ إن ظهر خطأ اتصال بعد تفعيل NLA، حدّث تطبيق Remote Desktop على جهازك.

---

## 4️⃣ تقوية ngrok

### أ) حجز عنوان ثابت (خطة مجانية محدودة)
الخطة المجانية تعطي عنواناً عشوائياً يتغير كل تشغيل — وهذا **في صالحك أمنياً**
(أصعب على الماسحات الضوئية). لا تحجز عنواناً ثابتاً إلا لحاجة حقيقية.

### ب) إضافة كلمة مرور على النفق نفسه (ممتاز!)
في خطة ngrok المجانية يمكنك إضافة HTTP Auth، لكن لتنفق TCP استخدم **قائمة IPs المسموحة**:
```yaml
Start-Process -FilePath $ngrok `
  -ArgumentList "tcp","3389","--cidr-allow","YOUR.HOME.IP/32"
```
`YOUR.HOME.IP` = عنوان IP العام لجهازك (اعرفه من <https://whatismyipaddress.com>)
بهذا لا يستطيع أحد غيرك الاتصال بالنفق أصلاً.

### ج) تحقق من اتصالات النفق
أثناء الجلسة افتح في متصفح الجهاز البعيد: `http://127.0.0.1:4040`
لوحة ngrok المحلية تعرض كل الاتصالات الحية.

---

## 5️⃣ قواعد السلوك داخل الجهاز

| ✅ افعل | ❌ لا تفعل |
|---|---|
| اختبار برامجك وأدواتك | تسجيل الدخول لبنكك |
| بناء/ترجمة الأكواد | إدخال بطاقتك الائتمانية |
| تجربة إعدادات نظام | تشغيل أدوات اختراق على أهداف |
| رفع ملفاتك لـ Git عند الانتهاء | تعدين العملات (إيقاف فوري للحساب) |
| إنهاء الجلسة عند الفراغ | ترك الجلسة 24/7 |
| | تخزين بيانات تحتاجها لاحقاً (الجهاز يُحذف!) |

---

## 6️⃣ تنظيف ما بعد الجلسة

الـ workflow ينفّذ `disable-rdp.ps1` تلقائياً مع `if: always()` — أي حتى لو
فشلت الخطوات السابقة. هذا السكربت:

1. يعطّل RDP في الريجستري
2. ينهي عمليات `ngrok` و `cloudflared`
3. يحذف المستخدم المؤقت
4. يزيل قواعد جدار الحماية

**لكن تذكر:** الجهاز يُدمَّر بالكامل بعد انتهاء الـ Run، فالتنظيف
إجراء احتياطي إضافي وليس ضرورياً للخصوصية.

---

## 7️⃣ مراجعة أمنية سريعة قبل كل تشغيل

- [ ] المستودع **Public** ولا يحتوي كلمات مرور مكتوبة في الملفات
- [ ] الأسرار مضافة في **Secrets** وليس **Variables**
- [ ] لم أشارك رابط النفق مع أحد
- [ ] لن أُدخل بيانات مالية أو حسابات شخصية
- [ ] سأُنهي الجلسة عند انتهائي (لا أتركها تستهلك الدقائق)
- [ ] الاستخدام لأغراض تطوير/اختبار مشروعة

---

## 8️⃣ ماذا لو تعرّض حسابك للتحذير؟

GitHub يرسل تحذيرات عبر البريد عند الاشتباه بسوء استخدام Actions:
- **لا تتجاهلها** — التحذير الثاني غالباً ينتهي بإيقاف دائم
- أوقف استخدام الـ workflows فوراً
- احذف المستودع أو اجعله Private
- إن كنت تحتاج Windows دائماً → استأجر VPS:

| المزوّد | السعر التقريبي | المواصفات |
|---|---|---|
| Contabo | ~6$/شهر | 4 vCPU / 8GB RAM |
| Hetzner Cloud | ~7$/شهر | 2 vCPU / 4GB RAM |
| Vultr | ~10$/شهر | 2 vCPU / 4GB RAM |
| AWS Lightsail | ~14$/شهر | 2 vCPU / 8GB RAM |

هذه تعطيك جهازاً **دائماً وبلا قيود زمنية** وبلا خطر على حسابك.

---

📚 **مراجع رسمية**
- [GitHub Actions — About billing](https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-actions/about-billing-for-github-actions)
- [GitHub Terms for Additional Products](https://docs.github.com/en/site-policy/github-terms/github-terms-for-additional-products-and-features)
- [Encrypting secrets in GitHub Actions](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions)
- [ngrok documentation](https://ngrok.com/docs)
