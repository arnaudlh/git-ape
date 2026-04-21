import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: 'Git-Ape',
  tagline: 'Intelligent Azure deployment agent system for GitHub Copilot',
  favicon: 'img/favicon.ico',

  future: {
    v4: true,
  },

  url: 'https://azure.github.io',
  baseUrl: '/git-ape-private/',

  organizationName: 'Azure',
  projectName: 'git-ape-private',
  trailingSlash: false,

  onBrokenLinks: 'warn',
  onBrokenMarkdownLinks: 'warn',

  markdown: {
    mermaid: true,
    format: 'md',
  },
  themes: ['@docusaurus/theme-mermaid'],

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          editUrl: 'https://github.com/Azure/git-ape-private/edit/main/website/',
          lastVersion: 'current',
          versions: {
            current: {
              label: 'Next',
              path: '',
            },
          },
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/git-ape-social-card.png',
    colorMode: {
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'Git-Ape',
      logo: {
        alt: 'Git-Ape Logo',
        src: 'img/logo.png',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'docsSidebar',
          position: 'left',
          label: 'Documentation',
        },
        {
          type: 'docsVersionDropdown',
          position: 'right',
        },
        {
          href: 'https://github.com/Azure/git-ape-private',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Documentation',
          items: [
            { label: 'Getting Started', to: '/docs/intro' },
            { label: 'Agents', to: '/docs/agents/overview' },
            { label: 'Skills', to: '/docs/skills/overview' },
          ],
        },
        {
          title: 'Resources',
          items: [
            { label: 'GitHub Repository', href: 'https://github.com/Azure/git-ape-private' },
            { label: 'Azure Cloud Adoption Framework', href: 'https://learn.microsoft.com/azure/cloud-adoption-framework/' },
            { label: 'License (MIT)', href: 'https://github.com/Azure/git-ape-private/blob/main/LICENSE' },
          ],
        },
        {
          title: 'Security',
          items: [
            { label: 'Security Policy', href: 'https://github.com/Azure/git-ape-private/blob/main/SECURITY.md' },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} Microsoft. Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash', 'json', 'yaml'],
    },
    mermaid: {
      theme: { light: 'neutral', dark: 'dark' },
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
