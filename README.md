# current.startt.ai

Weekly energy patent report site. Static HTML — no build step, no framework.

Live at: https://current.startt.ai
Vercel project: `current-startt` (team `ram095s-projects`)

## How publishing works

This repo is connected to Vercel. Any push to `main` automatically deploys
to https://current.startt.ai within seconds — there is no manual deploy
step, no `vercel` CLI needed.

## How to publish a new weekly issue

You can do this yourself in the GitHub website, or ask Claude to do the
git commands for you.

### Option A — GitHub website (no terminal needed)

1. Go to https://github.com/Ram095/current-startt
2. Navigate into the folder you need to update (e.g. `energy/02/`) or use
   **Add file → Upload files** to add a new issue folder.
3. Drop in the new files (`index.html`, `issue.json`, any updated
   `data/*.md` files, and the updated `index.html` at the repo root that
   links to the new issue).
4. Scroll down and click **Commit changes** directly to `main`.
5. That's it — Vercel deploys automatically. Check https://current.startt.ai
   in ~30 seconds.

### Option B — via Claude (clone + push)

1. Ask Claude to clone `https://github.com/Ram095/current-startt`.
2. Give Claude the new week's files and ask it to add them, commit, and
   push to `main`.
3. Vercel deploys automatically on push — no further action needed.

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

## Important — do not remove

`vercel.json` sets `Content-Type: text/plain` on `/data/*.md` files. This
is required so the raw datasets are readable as plain text (including by
AI assistants querying the report). Do not delete or override this file.
