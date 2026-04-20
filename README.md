# win11-debloat-guide

Cloudflare Pages static deployment.

## Contents
- `index.html` — single-file presentation
- `_headers` — basic security/cache headers for Pages
- `_redirects` — root handling

## Deploy to Cloudflare Pages
1. Push this folder to the root of your GitHub repo.
2. In Cloudflare Pages, create a new project from that repo.
3. Framework preset: `None`
4. Build command: leave empty
5. Build output directory: `/`
6. Deploy

## Notes
- No build step required.
- This is a pure static site.
