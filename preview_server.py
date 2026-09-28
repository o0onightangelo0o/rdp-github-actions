#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""خادم معاينة بسيط: فهرس عربي RTL + عرض كل الملفات (بما فيها المخفية)."""
import html, os, sys, urllib.parse
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler

ROOT = os.path.dirname(os.path.abspath(__file__))
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8000

CSS = """
:root{--bg:#0d1117;--p:#161b22;--b:#30363d;--t:#e6edf3;--m:#8b949e;--a:#58a6ff;--g:#3fb950}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--t);direction:rtl;
     font-family:"Segoe UI",Tahoma,Arial,sans-serif;line-height:1.7}
.w{max-width:940px;margin:0 auto;padding:26px 20px 70px}
h1{font-size:1.5rem;margin:0 0 4px}
.crumb{color:var(--m);font-size:.86rem;margin-bottom:20px;direction:ltr;text-align:right}
.crumb a{color:var(--a);text-decoration:none}
table{width:100%;border-collapse:collapse;background:var(--p);
      border:1px solid var(--b);border-radius:10px;overflow:hidden}
th,td{padding:10px 14px;border-bottom:1px solid var(--b);text-align:right;font-size:.92rem}
th{background:#1c2230;color:var(--a);font-weight:600}
tr:last-child td{border-bottom:none}
tr:hover td{background:rgba(88,166,255,.06)}
a.f{color:var(--t);text-decoration:none;font-family:Consolas,monospace;direction:ltr;
    unicode-bidi:embed;display:inline-block}
a.f:hover{color:var(--a)}
.dir{color:var(--a);font-weight:600}
.sz{color:var(--m);font-size:.82rem;white-space:nowrap;font-family:Consolas,monospace}
.tag{display:inline-block;padding:1px 8px;border-radius:999px;font-size:.7rem;
     border:1px solid var(--b);color:var(--m);margin-inline-start:7px}
.tag.y{background:rgba(210,153,34,.13);border-color:rgba(210,153,34,.4);color:#d29922}
.tag.p{background:rgba(188,140,255,.13);border-color:rgba(188,140,255,.4);color:#bc8cff}
.tag.d{background:rgba(63,185,80,.13);border-color:rgba(63,185,80,.4);color:var(--g)}
.top{background:var(--p);border:1px solid var(--b);border-radius:10px;padding:15px 19px;margin-bottom:20px}
.btn{display:inline-block;background:var(--a);color:#04121f;padding:9px 18px;border-radius:8px;
     text-decoration:none;font-weight:600;margin:4px 6px 4px 0;font-size:.9rem}
.btn.alt{background:transparent;color:var(--a);border:1px solid var(--a)}
.btn:hover{opacity:.88}
.note{color:var(--m);font-size:.84rem;margin-top:9px}
footer{color:var(--m);font-size:.8rem;text-align:center;margin-top:34px}
"""

ICON = {
    ".yml": "⚙️", ".yaml": "⚙️", ".ps1": "🔷", ".sh": "🐚", ".md": "📘",
    ".docx": "📄", ".zip": "🗜️", ".txt": "📃", ".gitignore": "🚫",
    ".gitattributes": "🔀", "LICENSE": "⚖️",
}

def icon_for(name):
    if name in ICON: return ICON[name]
    ext = os.path.splitext(name)[1].lower()
    return ICON.get(ext, "📃")

def tag_for(name):
    if name.startswith(".git"): return '<span class="tag">git</span>'
    if name == "LICENSE":       return '<span class="tag d">MIT</span>'
    if name.endswith(".yml"):   return '<span class="tag y">workflow</span>'
    if name.endswith(".ps1"):   return '<span class="tag p">PowerShell</span>'
    if name.endswith(".docx"):  return '<span class="tag d">Word</span>'
    return ""

def human(n):
    for u in ("B", "KB", "MB"):
        if n < 1024 or u == "MB":
            return f"{n:.0f} {u}" if u == "B" else f"{n/1:.1f} {u}" if u == "KB" and n < 10 else f"{n:.1f} {u}"
        n /= 1024
    return f"{n:.1f} MB"

def page(title, body):
    return f"""<!DOCTYPE html><html lang="ar" dir="rtl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)}</title><style>{CSS}</style></head><body><div class="w">{body}</div></body></html>"""


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def log_message(self, fmt, *args):
        sys.stderr.write("· %s\n" % (fmt % args))

    def do_GET(self):
        p = urllib.parse.urlparse(self.path).path
        if p in ("/", ""):
            self.send_response(302)
            self.send_header("Location", "/RESULTS.html")
            self.end_headers()
            return
        if p.endswith("/"):
            body = self.render_dir(p)
            data = body.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        return super().do_GET()

    def render_dir(self, urlpath):
        rel = urllib.parse.unquote(urlpath).lstrip("/")
        fs = os.path.join(ROOT, rel) if rel else ROOT
        if not os.path.isdir(fs):
            return page("غير موجود", "<h1>المجلد غير موجود</h1>")
        try:
            entries = sorted(os.listdir(fs))
        except PermissionError:
            return page("ممنوع", "<h1>لا صلاحية</h1>")

        dirs  = [e for e in entries if os.path.isdir(os.path.join(fs, e)) and e != ".git"]
        fls   = [e for e in entries if not os.path.isdir(os.path.join(fs, e))]
        dirs.sort(key=lambda x: (x.startswith("."), x.lower()))
        fls.sort(key=lambda x: (x.startswith("."), x.lower()))

        # شريط التنقل
        crumbs = ['<a href="/">🏠 rdp-github-actions</a>']
        acc = ""
        for part in [p for p in rel.split("/") if p]:
            acc += "/" + urllib.parse.quote(part)
            crumbs.append(f'<a href="{acc}/">{html.escape(part)}</a>')
        crumb = " / ".join(crumbs)

        rows = []
        if rel:
            parent = "/" + "/".join([p for p in rel.split("/") if p][:-1])
            parent = parent.rstrip("/") + "/" if parent != "/" else "/"
            rows.append(f'<tr><td>⬆️</td><td><a class="f dir" href="{parent}">..</a></td><td></td></tr>')
        for d in dirs:
            href = urllib.parse.quote(d) + "/"
            rows.append(f'<tr><td>📁</td><td><a class="f dir" href="{href}">{html.escape(d)}/</a></td><td class="sz">—</td></tr>')
        for f in fls:
            size = os.path.getsize(os.path.join(fs, f))
            href = urllib.parse.quote(f)
            rows.append(f'<tr><td>{icon_for(f)}</td>'
                        f'<td><a class="f" href="{href}">{html.escape(f)}</a>{tag_for(f)}</td>'
                        f'<td class="sz">{human(size)}</td></tr>')

        top = ""
        if not rel:
            top = """<div class="top">
              <a class="btn" href="/RESULTS.html">📊 تقرير النتائج النهائية</a>
              <a class="btn alt" href="/rdp-github-actions.zip">⬇️ تنزيل المشروع كاملاً (.zip)</a>
              <a class="btn alt" href="/%D8%AF%D9%84%D9%8A%D9%84-RDP-%D8%B9%D8%A8%D8%B1-GitHub.docx">📄 دليل Word</a>
              <div class="note">اضغط على أي ملف لعرض محتواه. الملفات التي تبدأ بنقطة
              (<code>.github</code> · <code>.gitignore</code> · <code>.gitattributes</code>) ظاهرة هنا
              بعكس مستكشف Windows.</div></div>"""

        body = (f"<h1>📂 تصفّح ملفات المشروع</h1><div class='crumb'>{crumb}</div>{top}"
                f"<table><thead><tr><th style='width:44px'></th><th>الاسم</th>"
                f"<th style='width:110px'>الحجم</th></tr></thead><tbody>"
                f"{''.join(rows)}</tbody></table>"
                f"<footer>{len(dirs)} مجلد · {len(fls)} ملف</footer>")
        return page(rel or "rdp-github-actions", body)


if __name__ == "__main__":
    srv = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Preview server on http://0.0.0.0:{PORT}  (root: {ROOT})", flush=True)
    srv.serve_forever()
