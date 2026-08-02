import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'AzureScout',
  description: 'See everything. Own your cloud. A PowerShell module for comprehensive Azure + Entra ID discovery and inventory.',
  base: '/azure-scout/',

  // Assets referenced by an ABSOLUTE path — themeConfig.logo, the home hero image — are
  // served from docs/public, which VitePress maps to the site root and rewrites for `base`.
  // They previously lived in docs/images, which VitePress does not publish at all: only
  // assets reached through a RELATIVE markdown link get processed and bundled. The old home
  // page happened to use `![](images/…)`, so the banner survived by accident; the nav logo,
  // which has always been absolute, did not, and the hero broke the moment the home page
  // moved to the `layout: home` frontmatter form.
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/azure-scout/images/azurescout-icon.svg' }],
  ],

  // Project-management artefacts (audits, plans, the enhancement spec, the generated
  // task list) live in /pmo at the repo root and are deliberately NOT published here.
  // They are internal programme records, not product documentation.

  themeConfig: {
    // The SQUARE icon, not the banner. The navbar logo slot is 24px tall, so the 640x160
    // wordmark rendered there collapsed to ~96x24 and was illegible; the 200x200 icon is the
    // asset drawn for this size. The banner is a wordmark and belongs on the home hero, where
    // it has the width to be read.
    logo: '/images/azurescout-icon.svg',

    nav: [
      { text: 'Home', link: '/' },
      { text: 'Guide', link: '/guide/' },
      { text: 'Assessment', link: '/assessment/' },
      { text: 'Catalogues', link: '/reference/' },
      { text: 'Automation', link: '/automation-guide/' },
      { text: 'Frameworks', link: '/frameworks/' },
      { text: 'Project', link: '/project/' },
    ],

    sidebar: [
      {
        text: 'Getting Started',
        collapsed: false,
        items: [
          { text: 'Guide index', link: '/guide/' },
          { text: 'Overview', link: '/guide/overview' },
          { text: 'Prerequisites & Required Modules', link: '/guide/prerequisites' },
          { text: 'Authentication', link: '/guide/authentication' },
          { text: 'Usage Guide', link: '/guide/usage' },
          { text: 'Permissions', link: '/guide/permissions' },
          { text: 'Category Filtering', link: '/guide/category-filtering' },
          { text: 'Parameters Reference', link: '/guide/parameters' },
          { text: 'Output Files & Formats', link: '/guide/output' },
          { text: 'Troubleshooting', link: '/guide/troubleshooting' },
        ],
      },
      {
        text: 'Unattended Execution',
        collapsed: true,
        items: [
          { text: 'Automation index', link: '/automation-guide/' },
          { text: 'Azure Automation Account', link: '/automation-guide/automation' },
          { text: 'GitHub Actions', link: '/automation-guide/github-actions' },
          { text: 'Azure DevOps', link: '/automation-guide/azure-devops' },
        ],
      },
      {
        text: 'CAF/WAF Assessment',
        collapsed: false,
        items: [
          { text: 'Assessment index', link: '/assessment/' },
          { text: 'Assessment Platform', link: '/assessment/assessment' },
          { text: 'Analysis Features', link: '/assessment/analysis-features' },
          { text: 'Configuration & Report Tiers', link: '/assessment/configuration' },
          { text: 'Assessment Prerequisites', link: '/assessment/assessment-prerequisites' },
          { text: 'Auth & Permissions per Scan Type', link: '/assessment/assessment-permissions' },
        ],
      },
      {
        text: 'Catalogues & Reference',
        collapsed: false,
        items: [
          // The two questions every reader asks first — "what does it assess" and "what does
          // it collect" — now each have one generated page that cannot drift from the product.
          { text: 'Catalogues index', link: '/reference/' },
          { text: 'Assessment Catalogue', link: '/reference/assessment-catalogue' },
          { text: 'Framework Coverage', link: '/reference/framework-coverage' },
          { text: 'ARM Modules (collectors)', link: '/reference/arm-modules' },
          { text: 'Collector Fields', link: '/reference/collector-fields' },
          { text: 'Entra ID Modules', link: '/reference/entra-modules' },
          { text: 'Coverage Table', link: '/reference/coverage-table' },
          { text: 'Category Structure', link: '/reference/category-structure' },
          { text: 'Category Reference', link: '/reference/category-reference' },
          { text: 'Validation Matrix', link: '/reference/validation-matrix' },
        ],
      },
      {
        // Every framework question set is now reachable. Previously only the SMART set
        // was linked and the other eleven were published but unreachable.
        text: 'Frameworks',
        collapsed: true,
        items: [
          { text: 'Framework Index', link: '/frameworks/' },
          { text: 'CAF Landing Zone Design Areas', link: '/frameworks/caf-landing-zone-design-areas' },
          { text: 'Cloud Governance Question Set', link: '/frameworks/cloud-governance-question-set' },
          { text: 'WAF Pillar Checklists', link: '/frameworks/waf-pillar-checklists' },
          { text: 'WAF — AI Workload', link: '/frameworks/waf-ai-workload-checklist' },
          { text: 'WAF — AVD Workload', link: '/frameworks/waf-avd-workload-checklist' },
          { text: 'WAF — AVS Workload', link: '/frameworks/waf-avs-workload-checklist' },
          { text: 'WAF — Azure Local', link: '/frameworks/waf-azure-local-checklist' },
          { text: 'AVS Landing Zone Question Set', link: '/frameworks/avs-landing-zone-question-set' },
          { text: 'CASA Question Set', link: '/frameworks/casa-question-set' },
          { text: 'DevOps Capability Question Set', link: '/frameworks/devops-capability-question-set' },
          { text: 'FinOps Review Question Set', link: '/frameworks/finops-review-question-set' },
          { text: 'SMART Question Set', link: '/frameworks/smart-question-set' },
        ],
      },
      {
        // Architecture and design records. Previously only the assessment registry was
        // linked; the decision records and scoring models were unreachable.
        text: 'Design & Decisions',
        collapsed: true,
        items: [
          { text: 'Assessment Registry', link: '/design/assessment-registry' },
          { text: 'Collector Audit', link: '/design/collector-audit' },
          { text: 'ARG Round Trips', link: '/design/arg-round-trips' },
          { text: 'CAF Design-Area Weighting', link: '/design/caf-design-area-weighting' },
          { text: 'Governance Domain Maturity Scale', link: '/design/governance-domain-maturity-scale' },
          { text: 'WAF Maturity Model Mapping', link: '/design/waf-maturity-model-mapping' },
          { text: 'AzGovViz Methodology Evaluation', link: '/design/azgovviz-methodology-evaluation' },
          { text: 'Decision — Declarative Collectors', link: '/design/decisions/declarative-collectors' },
          { text: 'Decision — Deterministic Pipeline', link: '/design/decisions/deterministic-pipeline' },
          { text: 'Decision — PPTX Renderer', link: '/design/decisions/pptx-renderer' },
        ],
      },
      {
        text: 'Project',
        collapsed: true,
        items: [
          { text: 'Project index', link: '/project/' },
          { text: 'Roadmap', link: '/project/roadmap' },
          { text: 'Changelog', link: '/project/changelog' },
          { text: 'Repository Structure', link: '/project/folder-structure' },
          { text: 'Testing', link: '/project/testing' },
          { text: 'Contributing', link: '/project/contributing' },
          { text: 'Credits & Attribution', link: '/project/credits' },
          { text: 'Differences from ARI', link: '/project/ari-differences' },
        ],
      },
      {
        // Per-release detail for the v3.0.x line only. Everything from v3.1.0 onward is
        // written up in the Roadmap instead, so this is labelled for what it actually is —
        // a section titled "Release Notes" that stops at v3.0.5 implies the product does too.
        text: 'Release Notes (v3.0.x)',
        collapsed: true,
        items: [
          { text: 'v3.1.0 onward → Roadmap', link: '/project/roadmap' },
          { text: 'v3.0.5', link: '/project/releases/v3.0.5' },
          { text: 'v3.0.4', link: '/project/releases/v3.0.4' },
          { text: 'v3.0.3', link: '/project/releases/v3.0.3' },
          { text: 'v3.0.2', link: '/project/releases/v3.0.2' },
          { text: 'v3.0.1', link: '/project/releases/v3.0.1' },
          { text: 'v3.0.0', link: '/project/releases/v3.0.0' },
        ],
      },
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/thisismydemo/azure-scout' },
    ],

    search: {
      provider: 'local',
    },

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © AzureScout Contributors',
    },

    editLink: {
      pattern: 'https://github.com/thisismydemo/azure-scout/edit/main/docs/:path',
      text: 'Edit this page on GitHub',
    },
  },

  markdown: {
    lineNumbers: true,
  },
})
