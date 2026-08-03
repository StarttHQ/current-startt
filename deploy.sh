#!/usr/bin/env bash
# CURRENT: publish files to https://current.startt.ai
#
#   ./deploy.sh <file> [file ...]        publish these files
#   ./deploy.sh --dry-run <file> ...     show what would happen, change nothing
#
# It works out where each file belongs, does the bookkeeping a new issue needs,
# pushes, waits for the site to update, and tells you whether it worked.
#
# Examples
#   ./deploy.sh ~/Documents/CoworkOS/current-report/issues/FY2026-27/CURRENT-energy-03.html \
#               ~/Documents/CoworkOS/current-report/issues/FY2026-27/weekly/energy-32_2026.md \
#               ~/Documents/CoworkOS/current-report/issues/FY2026-27/cumulative/energy-FY2026-27.md
#   ./deploy.sh ~/Downloads/brief.html
#   ./deploy.sh ~/Downloads/site-ready-to-deploy.tgz
#
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE="https://current.startt.ai"
DRY=0
FILES=()

for a in "$@"; do
  case "$a" in
    --dry-run|-n) DRY=1 ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) FILES+=("$a") ;;
  esac
done

if [ ${#FILES[@]} -eq 0 ]; then
  echo "Nothing to publish. Pass one or more files."
  echo "Run './deploy.sh --help' for examples."
  exit 1
fi

say()  { echo "$*"; }
step() { echo ""; echo "== $* =="; }
die()  { echo ""; echo "STOPPED: $*"; echo "Nothing has been published."; exit 1; }

cd "$REPO" || die "cannot find the site folder"

# ---------------------------------------------------------------- sync
step "Getting the current site"
git fetch -q origin || die "could not reach GitHub. Check your connection."
if ! git diff --quiet || ! git diff --cached --quiet; then
  die "this folder has uncommitted edits. Sort those out first, or run: git reset --hard origin/main"
fi
git reset -q --hard origin/main
say "  at $(git rev-parse --short HEAD)"

STAGED=()   # human-readable list of what we placed
NEW_ISSUE="" # set to NN if this publish adds an issue

# --------------------------------------------------- place one file
place() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  STAGED+=("$dest")
  say "  $(basename "$src")  ->  /$dest"
}

# Artifact exports (a single self-contained HTML page) lose three things every
# time they are re-exported. Put them back, or the page flashes cream on load
# and shares with a broken-looking preview. See README, "Standalone pages".
fix_artifact_shell() {
  local f="$1" desc="$2"
  python3 - "$f" "$desc" <<'PYEOF'
import re, sys
f, desc = sys.argv[1], sys.argv[2]
h = open(f, encoding='utf-8').read()
cut = h.find('__bundler/manifest')
if cut < 0:
    sys.exit(0)                      # not an artifact export, leave it alone
shell, rest = h[:cut], h[cut:]

# 1. the placeholder SVG loses its viewBox to attribute mangling, so it cannot
#    scale and the cream behind it shows through as a flash on every load
shell = shell.replace('sc-camel-view-box="0 0 100 100"',
                      'viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice"')
# 2. the bootstrap paints cream while the finished page is near-black
shell = shell.replace('body { background: #faf9f5;', 'body { background: #09090b;')
shell = shell.replace('#__bundler_thumbnail { position: fixed; inset: 0; width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; background: #faf9f5;',
                      '#__bundler_thumbnail { position: fixed; inset: 0; width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; background: #09090b;')
shell = shell.replace('color: #666; background: #fff; padding: 8px 14px; border-radius: 8px; box-shadow: 0 1px 4px rgba(0,0,0,0.12);',
                      'color: #a1a1aa; background: #18181b; padding: 8px 14px; border-radius: 8px; border: 1px solid #27272a;')
# 3. loading text, shown to people and to crawlers that do not run JavaScript
shell = re.sub(r'(<div id="__bundler_loading">)[^<]*', r'\g<1>' + desc, shell)
rest  = re.sub(r"setStatus\('(Unpacking [^']*|Rendering\.\.\.)'\)", "setStatus('%s')" % desc, rest)

# 4. link-preview tags, which must be in the plain HTML because WhatsApp,
#    LinkedIn and Slack do not run JavaScript
if 'og:title' not in shell:
    tags = '\n'.join([
      '  <meta name="viewport" content="width=device-width, initial-scale=1">',
      '  <meta name="theme-color" content="#09090b">',
      '  <meta name="description" content="%s">' % desc,
      '  <meta property="og:type" content="website">',
      '  <meta property="og:site_name" content="Startt">',
      '  <meta property="og:title" content="Startt, the sourcing layer">',
      '  <meta property="og:description" content="%s">' % desc,
      '  <meta property="og:url" content="https://current.startt.ai/brief/">',
      '  <meta property="og:image" content="https://current.startt.ai/brief/preview.png">',
      '  <meta property="og:image:width" content="1200">',
      '  <meta property="og:image:height" content="630">',
      '  <meta name="twitter:card" content="summary_large_image">',
      '  <meta name="twitter:title" content="Startt, the sourcing layer">',
      '  <meta name="twitter:description" content="%s">' % desc,
      '  <meta name="twitter:image" content="https://current.startt.ai/brief/preview.png">',
    ])
    shell = re.sub(r'(<title>[^<]*</title>)', r'\1\n' + tags, shell, count=1)

open(f, 'w', encoding='utf-8').write(shell + rest)
print("  applied the standalone-page fixes (no cream flash, working link preview)")
PYEOF
}

# ------------------------------------------------------------- routing
step "Working out where each file goes"
for src in "${FILES[@]}"; do
  [ -f "$src" ] || die "cannot find $src"
  base="$(basename "$src")"
  case "$base" in
    # a weekly issue page:  CURRENT-energy-02.html
    CURRENT-*-[0-9][0-9].html)
      nn="${base%.html}"; nn="${nn##*-}"
      sector="${base#CURRENT-}"; sector="${sector%-[0-9][0-9].html}"
      place "$src" "$sector/$nn/index.html"
      NEW_ISSUE="$sector/$nn"
      ;;
    # a weekly or cumulative data appendix:  energy-31_2026.md / energy-FY2026-27.md
    *-[0-9][0-9]_[0-9][0-9][0-9][0-9].md|*-FY[0-9]*.md)
      place "$src" "data/$base" ;;
    # the standalone brief
    brief*.html)
      place "$src" "brief/index.html"
      fix_artifact_shell "brief/index.html" "The sourcing layer, in four parts" ;;
    # a full site bundle
    *.tgz|*.tar.gz)
      tmp="$(mktemp -d)"; tar xzf "$src" -C "$tmp"
      root="$tmp"; [ -d "$tmp/site" ] && root="$tmp/site"
      while IFS= read -r rel; do place "$root/$rel" "$rel"; done \
        < <(cd "$root" && find . -type f ! -name '.DS_Store' | sed 's|^\./||')
      rm -rf "$tmp" ;;
    robots.txt|favicon.ico|index.html|vercel.json)
      place "$src" "$base" ;;
    *.png)
      place "$src" "email/$base" ;;   # email marks: filenames are permanent
    *)
      die "not sure where $base belongs. Add a rule to deploy.sh, or copy it in by hand." ;;
  esac
done

# --------------------------------------- new issue: metadata + front page
if [ -n "$NEW_ISSUE" ]; then
  step "Issue bookkeeping for /$NEW_ISSUE/"
  python3 - "$NEW_ISSUE" <<'PYEOF'
import json, os, re, sys, html
d = sys.argv[1]
page = open(os.path.join(d, 'index.html'), encoding='utf-8', errors='replace').read()
text = re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', page)))

def first(pat, default=''):
    m = re.search(pat, page, re.S | re.I)
    return html.unescape(re.sub(r'<[^>]+>', '', m.group(1))).strip() if m else default

nn      = os.path.basename(d)
head    = first(r'<h1[^>]*>(.*?)</h1>')
week    = (re.search(r'Week of\s*(\d{2}/\d{2}/\d{4})', text) or
           re.search(r'(\d{2}/\d{2}/\d{4})', text))
week    = week.group(1) if week else ''
pub     = re.search(r'Compiled\s+(\d{1,2}\s+\w+\s+\d{4})', text)
if pub:
    import datetime
    pub = datetime.datetime.strptime(pub.group(1), '%d %B %Y').strftime('%Y-%m-%d')
else:
    pub = ''

meta_path = os.path.join(d, 'issue.json')
meta = {"issue_no": nn, "headline": head, "week": week,
        "published": pub, "sector": os.path.dirname(d)}
missing = [k for k, v in meta.items() if not v]
if missing:
    print("  could not read %s from the page." % ', '.join(missing))
    print("  Write %s by hand, then run this again." % meta_path)
    sys.exit(3)

# The deploy check compares these against the live page, so they must appear on it.
for k in ('week', 'headline'):
    if meta[k] not in text:
        print("  the %s in issue.json does not appear on the page itself." % k)
        print("  That would fail the deploy check. Fix %s by hand." % meta_path)
        sys.exit(3)

json.dump(meta, open(meta_path, 'w'), indent=1)
open(meta_path, 'a').write('\n')
print("  issue.json: No. %s, week of %s, published %s" % (nn, meta['week'], meta['published']))
print("  headline: %s" % meta['headline'][:70])

# --- front page: the step that is easy to forget, so we do it here ---
home = open('index.html', encoding='utf-8').read()
if '/%s/' % d in home:
    print("  front page already lists /%s/" % d)
else:
    entry = ('<a class="ix" href="/%s/">\n'
             '   <div class="ixn">No. %s</div>\n'
             '   <div class="ixt">%s</div>\n'
             '   <div class="ixd">Week of %s &nbsp;&middot;&nbsp; published %s</div></a>\n ' %
             (d, nn, html.escape(meta['headline']), meta['week'], meta['published']))
    home = re.sub(r'(<a class="ix" )', entry + r'\1', home, count=1)
    home = re.sub(r'href="/[a-z]+/\d\d/" style="color:#000">No\. \d\d, week of [\d/]+',
                  'href="/%s/" style="color:#000">No. %s, week of %s' % (d, nn, meta['week']), home, count=1)
    n = len(re.findall(r'<a class="ix" ', home))
    home = re.sub(r'<div class="n">\d+ published</div>',
                  '<div class="n">%d published</div>' % n, home, count=1)
    open('index.html', 'w', encoding='utf-8').write(home)
    print("  front page: added No. %s, now lists %d issues" % (nn, n))
PYEOF
  rc=$?
  [ $rc -eq 0 ] || die "could not finish the issue bookkeeping (see above)."
  STAGED+=("index.html" "$NEW_ISSUE/issue.json")
fi

# ------------------------------------------------------------ pre-flight
step "Checking before publishing"
python3 - <<'PYEOF'
import glob, json, os, re, sys, html
bad = 0
def chk(label, ok):
    global bad
    print("  %s  %s" % ("ok  " if ok else "FAIL", label))
    if not ok: bad += 1

for meta_path in glob.glob('*/*/issue.json'):
    d = os.path.dirname(meta_path)
    meta = json.load(open(meta_path))
    page = open(os.path.join(d, 'index.html'), encoding='utf-8', errors='replace').read()
    text = re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', page)))
    for k in ('week', 'headline'):
        chk("/%s/ page shows the %s from issue.json" % (d, k), meta[k] in text)
    chk("front page links /%s/" % d, '/%s/' % d in open('index.html', encoding='utf-8').read())

for f in ['index.html', 'robots.txt', 'vercel.json']:
    chk("%s present" % f, os.path.exists(f))
for f in glob.glob('email/*.png'):
    chk("%s not empty (already-sent emails point at it)" % f, os.path.getsize(f) > 0)
sys.exit(1 if bad else 0)
PYEOF
[ $? -eq 0 ] || die "the checks above would fail after publishing."

# ---------------------------------------------------------------- publish
if [ "$DRY" = "1" ]; then
  step "Dry run, nothing published"
  # stage first, or brand-new files are invisible to diff and the summary lies
  git add -A
  git --no-pager diff --cached --stat | sed 's/^/  /'
  git reset -q --hard origin/main
  git clean -qfd
  exit 0
fi

step "Publishing"
git add -A
if git diff --cached --quiet; then
  say "  nothing changed. The site is already showing these files."
  exit 0
fi
git --no-pager diff --cached --stat | sed 's/^/  /'

SUMMARY="Publish $(printf '%s, ' "${STAGED[@]##*/}" | sed 's/, $//')"
[ -n "$NEW_ISSUE" ] && SUMMARY="Publish issue ${NEW_ISSUE##*/}, week of $(python3 -c "import json;print(json.load(open('$NEW_ISSUE/issue.json'))['week'])")"
git commit -q -m "$SUMMARY" -m "Published with deploy.sh." \
           -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>" || die "commit failed"
git push -q origin main || die "push failed. Do you have access to the repo?"
say "  pushed $(git rev-parse --short HEAD)"

# ----------------------------------------------------------- verify live
step "Waiting for the site to update"
say "  this takes about a minute"
for _ in $(seq 60); do
  st="$(gh run list --repo StarttHQ/current-startt --limit 1 --json status,conclusion,headSha \
        --jq 'first(.[] | select(.headSha=="'"$(git rev-parse HEAD)"'")) | "\(.status) \(.conclusion // "-")"' 2>/dev/null)"
  [ "${st%% *}" = "completed" ] && break
  sleep 10
done

echo ""
if [ "${st#* }" = "success" ]; then
  echo "=================================================="
  echo "PUBLISHED. $SITE is live and showing these files."
  [ -n "$NEW_ISSUE" ] && echo "Read it at $SITE/$NEW_ISSUE/"
  echo "It is safe to send the newsletter email."
  echo "=================================================="
else
  echo "=================================================="
  echo "PUBLISHED, BUT THE SITE CHECK FAILED."
  echo ""
  echo "Your files are on GitHub, but the checks say the live site is not"
  echo "showing them correctly. Do NOT send the newsletter email yet."
  echo "See what went wrong here:"
  gh run list --repo StarttHQ/current-startt --limit 1 --json url --jq '.[0].url' 2>/dev/null
  echo "=================================================="
  exit 1
fi
