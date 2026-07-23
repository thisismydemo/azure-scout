import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'AzureScout',
  description: 'See everything. Own your cloud. A PowerShell module for comprehensive Azure + Entra ID discovery and inventory.',
  base: '/azure-scout/',

  themeConfig: {
    logo: '/images/azurescout-banner.svg',

    nav: [
      { text: 'Home', link: '/' },
      { text: 'Getting Started', link: '/prerequisites' },
      { text: 'Assessment', link: '/assessment' },
      { text: 'Module Reference', link: '/arm-modules' },
      { text: 'Project', link: '/roadmap' },
    ],

    sidebar: [
      {
        text: 'Getting Started',
        items: [
          { text: 'Prerequisites & Required Modules', link: '/prerequisites' },
          { text: 'Authentication', link: '/authentication' },
          { text: 'Usage Guide', link: '/usage' },
          { text: 'Permissions', link: '/permissions' },
          { text: 'Parameters Reference', link: '/parameters' },
          { text: 'Category Filtering', link: '/category-filtering' },
          { text: 'Output Files & Formats', link: '/output' },
          { text: 'Troubleshooting', link: '/troubleshooting' },
          { text: 'Testing', link: '/testing' },
        ],
      },
      {
        text: 'CAF/WAF Assessment',
        items: [
          { text: 'Assessment Platform', link: '/assessment' },
          { text: 'Assessment Prerequisites', link: '/assessment-prerequisites' },
          { text: 'Auth & Permissions per Scan Type', link: '/assessment-permissions' },
          { text: 'Assessment Registry', link: '/design/assessment-registry' },
        ],
      },
      {
        text: 'Module Reference',
        items: [
          { text: 'ARM Modules', link: '/arm-modules' },
          { text: 'Entra ID Modules', link: '/entra-modules' },
          { text: 'Coverage Table', link: '/coverage-table' },
          { text: 'Category Structure', link: '/category-structure' },
        ],
      },
      {
        text: 'Project',
        items: [
          { text: 'Roadmap', link: '/roadmap' },
          { text: 'Repository Structure', link: '/folder-structure' },
          { text: 'Contributing', link: '/contributing' },
          { text: 'Credits & Attribution', link: '/credits' },
          { text: 'Differences from ARI', link: '/ari-differences' },
          { text: 'Changelog', link: '/changelog' },
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
