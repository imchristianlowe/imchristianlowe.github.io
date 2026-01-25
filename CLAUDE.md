# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a static HTML/CSS personal portfolio and resume site deployed to GitHub Pages.

## Structure

```
index.html          # Single-page site with all sections
css/style.css       # Dark minimal theme styling
assets/images/      # Avatar and other images
```

## Local Development

```bash
# Serve locally (Python)
python -m http.server 8000

# Or with npx
npx serve
```

Then open http://localhost:8000

## Deployment

The site auto-deploys via `.github/workflows/pages-deploy.yml` on push to main/master. No build step required - GitHub Pages serves the static files directly.

## Editing Content

All content is in `index.html`. Sections are clearly marked with IDs:
- `#hero` - Name, tagline, avatar, social links
- `#projects` - Project cards
- `#experience` - Work history
- `#skills` - Technical skills grid
- `#education` - Education background

CSS variables for theming are at the top of `css/style.css`.
