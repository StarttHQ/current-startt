# current.startt.ai

Weekly energy patent report site. Static HTML — no build step, no framework.

Live at: https://current.startt.ai
Repo: https://github.com/StarttHQ/current-startt

## Publishing, the short version

```
./deploy.sh <the files you were given>
```

That is the whole thing. A normal week:

```
./deploy.sh ~/Documents/CoworkOS/current-report/issues/FY2026-27/CURRENT-energy-03.html \
            ~/Documents/CoworkOS/current-report/issues/FY2026-27/weekly/energy-32_2026.md \
            ~/Documents/CoworkOS/current-report/issues/FY2026-27/cumulative/energy-FY2026-27.md
```

It works out where each file belongs, writes the new issue's `issue.json` by
reading the page, adds the issue to the front page, checks everything before
publishing, pushes, then waits and reports whether the live site really shows
it. It ends with either

```
PUBLISHED. It is safe to send the newsletter email.
```

or a plain description of what is wrong. **Only send the email on the first one.**

Add `--dry-run` to see what it would do without changing anything. If it is not
sure where a file belongs it stops and changes nothing, so either add a rule to
`deploy.sh` or place that file by hand.

## How publishing works underneath

Any push to `main` runs `.github/workflows/deploy.yml`, which copies the files
onto the EC2 box that nginx serves, then checks the live site from the outside:
that current.startt.ai is serving that exact commit, that every image and data
file matches byte for byte, that the five email marks still load as images with
no redirect, that each issue page shows the right issue, and that the front page
links every issue and those links open. A red run means the site is not
confirmed showing your update — do not send the email.

The site used to be on Vercel. It is not any more, so `vercel.json` no longer
does anything: nginx ignores it. The headers it declares are **not** in effect.

## File structure

```
site/
  index.html          Homepage — list of published issues
  vercel.json         Required headers (do not remove — sets .md files to
                       serve as text/plain so AI assistants can read them)
  energy/
    01/
      index.html       Full report for issue 01
      issue.json       Metadata: issue number, headline, week, publish date
      img/             Images used only by this issue (create when needed)
  data/
    energy-30_2026.md         Weekly data appendix
    energy-FY2026-27.md       Cumulative financial-year appendix
  email/              Images referenced by the weekly email. Stable public
                       URLs — filenames must never change. See below.
```

Each new issue gets its own folder under `energy/NN/`, plus an updated
entry in the root `index.html` linking to it, and updated `data/*.md`
files with the new week's figures appended.

Images that belong to a single issue go in that issue's own `img/` folder,
so each issue stays self-contained and filenames can repeat week to week.
Anything shared across every issue belongs in `email/` or at the root.

## Email assets — do not rename or move

Gmail refuses base64-embedded images, so the five marks in the weekly email
are referenced from public https URLs on this domain:

```
https://current.startt.ai/email/claude.png              96 x 96   Claude mark, black
https://current.startt.ai/email/openai.png              96 x 96   ChatGPT mark, black
https://current.startt.ai/email/perplexity.png          96 x 96   Perplexity mark, black
https://current.startt.ai/email/startt-glyph-black.png  62 x 80   Startt gem, white masthead
https://current.startt.ai/email/startt-glyph-white.png  62 x 80   Startt gem, black footer
```

They are 96px and 80px tall but displayed at 18px and 20px, so they stay
sharp on retina screens.

These URLs are baked into every email already sent. Renaming, moving or
deleting a file breaks the marks in every archived copy of the newsletter,
including issues sent months ago. Replace the file contents if a mark needs
updating; never change the path.

All five are marked decorative in the email, so if one fails to load the
layout does not shift and the named Claude, ChatGPT and Perplexity links
still work.

## Standalone pages

`/brief/` is a page, not an issue. An issue is a folder carrying an
`issue.json`; that is what the deploy check uses to decide which pages the
front page must list. Standalone pages are checked that they open, and are not
expected on the front page.

`/brief/` is exported from a Claude Artifact. **Every fresh export loses three
things**, which `deploy.sh` puts back automatically:

1. The link-preview tags. A raw export has only a charset and a title, so
   WhatsApp, LinkedIn and Slack fall back to the loading text and the share
   looks broken. They must sit in the plain HTML because unfurlers do not run
   JavaScript.
2. The loading text, which otherwise reads "Unpacking...".
3. The dark bootstrap colours. The export hardcodes a cream background while
   the finished page is near-black, so every load flashes bright then snaps to
   dark. The underlying cause is that the exporter kebab-cases camelCase
   attributes, so the placeholder graphic ships `sc-camel-view-box` instead of
   `viewBox` and cannot scale to cover the screen.

## Assistants cannot read the data files

Cloudflare returns 403 to GPTBot, OAI-SearchBot, ChatGPT-User, PerplexityBot,
Perplexity-User and ClaudeBot, across the whole site. Browsers and Googlebot
get 200, so this is the "Block AI Scrapers and Crawlers" setting, not anything
we publish. Cloudflare also prepends its own `robots.txt` with `Disallow: /`
for those same bots, contradicting ours. Both are fixed by one Cloudflare
setting, by whoever holds that account. Nothing in this repo can change it.

## vercel.json

Kept for reference only. The site is served by nginx now, which ignores this
file, so the headers it declares are not in effect. The `text/plain` on
`/data/*.md` that the datasets rely on comes from the nginx config on the box,
which is not in this repo.
