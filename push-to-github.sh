#!/usr/bin/env bash
# =====================================================================
#  يرفع المشروع إلى مستودع GitHub جديد بأمر واحد (Linux / macOS)
#  ---------------------------------------------------------------------
#  المتطلب: Personal Access Token بصلاحية repo
#           أنشئه من https://github.com/settings/tokens/new
#
#  الاستخدام:
#      chmod +x push-to-github.sh
#      ./push-to-github.sh
#      ./push-to-github.sh my-repo-name          # اسم مخصص
#      ./push-to-github.sh my-repo-name private  # مستودع خاص
# =====================================================================
set -euo pipefail

REPO_NAME="${1:-rdp-github-actions}"
VISIBILITY="${2:-public}"
DESCRIPTION="Windows RDP environment via GitHub Actions (for CI/CD, testing and development)"

C_CYAN='\033[0;36m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[1;33m'; C_RED='\033[0;31m'; C_OFF='\033[0m'
step() { echo -e "\n${C_CYAN}[$1] $2${C_OFF}"; }
done_(){ echo -e "    ${C_GREEN}✅ $1${C_OFF}"; }
warn() { echo -e "    ${C_YELLOW}⚠️  $1${C_OFF}"; }
fail() { echo -e "    ${C_RED}❌ $1${C_OFF}"; exit 1; }

cd "$(dirname "$0")"

# ---------- 1) التحقق من الأدوات ----------
step 1 "التحقق من الأدوات..."
command -v git   >/dev/null || fail "git غير مثبّت"
command -v curl  >/dev/null || fail "curl غير مثبّت"
command -v python3 >/dev/null || fail "python3 غير مثبّت (مطلوب لقراءة JSON)"
done_ "git $(git --version | awk '{print $3}')"

# ---------- 2) المستودع المحلي ----------
step 2 "التحقق من المستودع المحلي..."
if [ ! -d .git ]; then
  warn "لا يوجد .git — أهيّئ مستودعاً جديداً"
  git init -b main
  git add -A
  git commit -m "Initial commit: Windows RDP via GitHub Actions"
fi
git config core.autocrlf input
COMMITS="$(git rev-list --count HEAD 2>/dev/null || echo 0)"
[ "$COMMITS" -gt 0 ] || fail "لا توجد commits للدفع"
done_ "عدد الـ commits: $COMMITS"

# ---------- 3) بيانات الدخول ----------
step 3 "بيانات GitHub..."
echo -e "    ${C_YELLOW}🔑 أنشئ Personal Access Token من: https://github.com/settings/tokens/new${C_OFF}"
echo -e "    ${C_YELLOW}   وفعّل صلاحية repo فقط${C_OFF}"
echo
read -r -p "    اسم مستخدم GitHub: " GH_USER
[ -n "$GH_USER" ] || fail "اسم المستخدم مطلوب"
read -r -s -p "    Personal Access Token (مخفي): " GH_TOKEN
echo
[ -n "$GH_TOKEN" ] || fail "التوكن مطلوب"

AUTH_HEADER="Authorization: Bearer $GH_TOKEN"

# ---------- 4) التحقق من التوكن ----------
step 4 "التحقق من صلاحية التوكن..."
ME_JSON="$(curl -sf -H "$AUTH_HEADER" -H "Accept: application/vnd.github+json" \
            https://api.github.com/user)" || fail "التوكن مرفوض — تأكد من صلاحيته ومن تفعيل repo"
GH_USER="$(printf '%s' "$ME_JSON" | python3 -c 'import sys,json;print(json.load(sys.stdin)["login"])')"
done_ "مرحباً $GH_USER — التوكن صالح"

# ---------- 5) إنشاء المستودع ----------
step 5 "إنشاء المستودع '$REPO_NAME' ($VISIBILITY)..."
IS_PRIVATE="false"
[ "$VISIBILITY" = "private" ] && IS_PRIVATE="true"

CREATE_BODY="$(python3 - "$REPO_NAME" "$DESCRIPTION" "$IS_PRIVATE" <<'PY'
import json,sys
print(json.dumps({
  "name": sys.argv[1],
  "description": sys.argv[2],
  "private": sys.argv[3] == "true",
  "auto_init": False,
}))
PY
)"

RESP="$(curl -s -w '\n%{http_code}' -X POST \
          -H "$AUTH_HEADER" -H "Accept: application/vnd.github+json" \
          -H "Content-Type: application/json" \
          -d "$CREATE_BODY" https://api.github.com/user/repos)"
CODE="$(printf '%s' "$RESP" | tail -n1)"
BODY="$(printf '%s' "$RESP" | sed '$d')"

case "$CODE" in
  201) done_ "تم إنشاء المستودع" ;;
  422) warn "المستودع موجود مسبقاً — سأتابع الدفع إليه" ;;
  *)   echo "$BODY"; fail "فشل إنشاء المستودع (HTTP $CODE)" ;;
esac

if [ "$IS_PRIVATE" = "false" ]; then
  warn "Public = دقائق Actions غير محدودة مجاناً (هذا ما تريده)"
else
  warn "Private = 2000 دقيقة/شهر ومعامل ×2 لساعات Windows"
fi

# ---------- 6) الدفع ----------
step 6 "دفع الملفات إلى GitHub..."
git remote remove origin 2>/dev/null || true
git remote add origin "https://${GH_USER}:${GH_TOKEN}@github.com/${GH_USER}/${REPO_NAME}.git"
git branch -M main
git push -u origin main
# إزالة التوكن من الإعدادات المحفوظة (أمان)
git remote set-url origin "https://github.com/${GH_USER}/${REPO_NAME}.git"
done_ "تم الدفع بنجاح"

# ---------- 7) صلاحيات Actions ----------
step 7 "تفعيل صلاحيات الكتابة لـ Actions..."
PERM_CODE="$(curl -s -o /dev/null -w '%{http_code}' -X PUT \
              -H "$AUTH_HEADER" -H "Accept: application/vnd.github+json" \
              -H "Content-Type: application/json" \
              -d '{"permission":"write"}' \
              "https://api.github.com/repos/${GH_USER}/${REPO_NAME}/actions/permissions/workflow")"
if [ "$PERM_CODE" = "204" ]; then
  done_ "Workflow permissions = Read and write"
else
  warn "تعذّر ضبطها تلقائياً (HTTP $PERM_CODE) — اضبطها يدوياً:"
  echo "    Settings → Actions → General → Read and write permissions"
fi

# ---------- 8) الملخص ----------
echo
echo -e "${C_GREEN}═══════════════════════════════════════════════════════════${C_OFF}"
echo -e "${C_GREEN}  🎉 اكتمل الرفع!${C_OFF}"
echo -e "${C_GREEN}═══════════════════════════════════════════════════════════${C_OFF}"
echo
echo -e "  المستودع : ${C_CYAN}https://github.com/${GH_USER}/${REPO_NAME}${C_OFF}"
echo -e "  Actions  : ${C_CYAN}https://github.com/${GH_USER}/${REPO_NAME}/actions${C_OFF}"
echo
echo -e "  ${C_YELLOW}الخطوات المتبقية (3):${C_OFF}"
echo "   1. سجّل في https://dashboard.ngrok.com/signup وانسخ الـ Authtoken"
echo "   2. أضفه Secret باسم NGROK_AUTHTOKEN في:"
echo "      https://github.com/${GH_USER}/${REPO_NAME}/settings/secrets/actions/new"
echo "   3. افتح تبويب Actions → «RDP - Windows + ngrok» → Run workflow"
echo
echo -e "  ${C_YELLOW}🖤 بديل بلا حساب ngrok:${C_OFF}"
echo "     Actions → «Windows Desktop in Browser (بدون حساب)» → Run workflow"
echo
echo -e "  ${C_YELLOW}🔒 احذف التوكن بعد الانتهاء: https://github.com/settings/tokens${C_OFF}"
echo
