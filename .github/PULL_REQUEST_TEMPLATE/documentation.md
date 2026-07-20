# Documentation Update

## Description

<!-- Describe what documentation was added, updated, or restructured. -->

## Changes Made

<!-- List the files and sections changed. -->

## Testing

- [ ] `npm run docs:build` completes without errors
- [ ] `npm run docs:dev` renders correctly at `http://localhost:5173/azure-scout/`
- [ ] All navigation links resolve
- [ ] Search returns expected results

## Deployment Notes

After merge, the GitHub Actions workflow builds and deploys to GitHub Pages automatically.

To enable GitHub Pages (first time only):
1. Go to **Settings → Pages**
2. Set source to **GitHub Actions**
3. The site will be available at `https://thisismydemo.github.io/azure-scout/`

## Checklist

- [ ] Content is accurate and up-to-date
- [ ] All internal links work
- [ ] VitePress config (`docs/.vitepress/config.ts`) updated if nav/sidebar changed
- [ ] No MkDocs-specific syntax left (`!!!`, `{ .md-button }`, `{ align=... }`)
