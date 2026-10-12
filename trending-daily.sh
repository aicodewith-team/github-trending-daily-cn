#!/usr/bin/env bash
# 每天抓 GitHub Trending，用 codex exec 生成中文日报
set -euo pipefail
cd "$(dirname "$0")"
# cron 的 PATH 很短，找不到 codex。用 `which codex` 查到绝对路径，在 crontab 里用 CODEX_BIN=... 传进来
CODEX_BIN="${CODEX_BIN:-$(command -v codex || echo $HOME/.local/bin/codex)}"
export CODEX_HOME="$PWD/codex-home"              # 独立配置，不影响 ~/.codex
: "${AICW_API_KEY:?请先设置 AICW_API_KEY}"
DAY=$(date +%F); mkdir -p data reports logs

# 1) 联网抓取放在 codex 外面（codex 沙箱默认不能联网）
curl -sfL --retry 3 "https://github.com/trending?since=daily" -o "data/$DAY.html"
python3 - "$DAY" <<'PY'
import re, html, json, sys
day = sys.argv[1]
t = open(f"data/{day}.html", encoding="utf-8").read()
out = []
for a in t.split('<article class="Box-row')[1:11]:
    m = re.search(r'<h2[^>]*>\s*<a[^>]*href="/([^"]+)"', a)
    if not m: continue                      # GitHub 改版时跳过，别让整份日报挂掉
    name = m.group(1)
    desc = re.search(r'<p class="col-9[^"]*">(.*?)</p>', a, re.S)
    lang = re.search(r'itemprop="programmingLanguage">([^<]+)<', a)
    nums = re.findall(r'</svg>\s*([\d,]+)\s*</a>', a)
    today = re.search(r'([\d,]+) stars? today', a)
    out.append({
        "repo": name, "url": f"https://github.com/{name}",
        "desc": html.unescape(re.sub(r"\s+", " ", desc.group(1))).strip() if desc else "",
        "lang": lang.group(1) if lang else "",
        "stars": nums[0] if nums else "", "forks": nums[1] if len(nums) > 1 else "",
        "stars_today": today.group(1) if today else "",
    })
# 补充每个仓库的 README（截前 2500 字）和基本信息（创建时间、协议）
import urllib.request, re as _re
def get(url, accept):
    req = urllib.request.Request(url, headers={"Accept": accept, "User-Agent": "trending-daily"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r: return r.read().decode("utf-8", "ignore")
    except Exception as e: return ""
for r in out:
    meta = get(f"https://api.github.com/repos/{r['repo']}", "application/vnd.github+json")
    try:
        m = json.loads(meta); r["created_at"] = m.get("created_at", "")[:10]
        r["license"] = (m.get("license") or {}).get("spdx_id") or "无"
    except Exception: r["created_at"] = r["license"] = "未知"
    md = get(f"https://api.github.com/repos/{r['repo']}/readme", "application/vnd.github.raw")
    md = _re.sub(r"<[^>]+>|!\[[^\]]*\]\([^)]*\)", "", md)   # 去掉 HTML 标签和图片
    md = _re.sub(r"\n{3,}", "\n\n", md).strip()
    r["readme"] = md[:2500] if md else "（README 获取失败）"
if not out: sys.exit("一个仓库都没解析到，可能 GitHub 改版了")
json.dump(out, open(f"data/{day}.json", "w"), ensure_ascii=False, indent=1)
print(f"抓到 {len(out)} 个仓库，README 成功 {sum(1 for r in out if not r['readme'].startswith('（'))} 个")
PY

# 2) 把数据交给 codex，只让它写字，不让它联网、不让它改文件
# 提示词放在 prompt.md 里，{{DAY}} 会被替换成当天日期，JSON 数据接在末尾
PROMPT="$(sed "s/{{DAY}}/$DAY/g" prompt.md)
$(cat "data/$DAY.json")"

"$CODEX_BIN" exec --sandbox read-only --skip-git-repo-check --json \
  -o "reports/$DAY.md" "$PROMPT" < /dev/null > "logs/$DAY.jsonl"

grep -o '"usage":{[^}]*}' "logs/$DAY.jsonl" | tail -1
echo "日报已生成：reports/$DAY.md"
