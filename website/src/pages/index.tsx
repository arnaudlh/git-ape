import type {ReactNode} from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';

import styles from './index.module.css';

function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <header className={clsx('hero hero--primary', styles.heroBanner)}>
      <div className="container">
        <Heading as="h1" className="hero__title">
          {siteConfig.title}
        </Heading>
        <p className="hero__subtitle">{siteConfig.tagline}</p>
        <div className={styles.buttons}>
          <Link
            className="button button--secondary button--lg"
            to="/docs/intro">
            Get Started →
          </Link>
        </div>
      </div>
    </header>
  );
}

function FeatureItem({title, description, emoji}: {title: string; description: string; emoji: string}) {
  return (
    <div className={clsx('col col--4')}>
      <div className="text--center padding-horiz--md" style={{padding: '2rem 1rem'}}>
        <div style={{fontSize: '3rem', marginBottom: '1rem'}}>{emoji}</div>
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

const features = [
  {
    title: 'Multi-Agent Architecture',
    emoji: '🤖',
    description: '8 specialized agents orchestrated by @git-ape — from requirements gathering to deployment validation.',
  },
  {
    title: 'Security-First',
    emoji: '🔒',
    description: 'Blocking security gate, managed identities, least-privilege RBAC, and compliance analysis before every deployment.',
  },
  {
    title: '13 Built-in Skills',
    emoji: '🔧',
    description: 'Cost estimation, naming validation, preflight checks, drift detection, and more — invoked automatically at the right stage.',
  },
  {
    title: 'CI/CD Integration',
    emoji: '⚙️',
    description: 'GitHub Actions workflows for plan-on-PR, deploy-on-merge, and tear-down with OIDC authentication.',
  },
  {
    title: 'Living Documentation',
    emoji: '📖',
    description: 'Auto-generated from source — agents, skills, and workflows stay in sync with the codebase.',
  },
  {
    title: 'Two Execution Modes',
    emoji: '🔄',
    description: 'Interactive via VS Code Copilot Chat, or headless via Copilot Coding Agent with GitHub Issues.',
  },
];

export default function Home(): ReactNode {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title="Documentation"
      description="Git-Ape — Intelligent Azure deployment agent system for GitHub Copilot">
      <HomepageHeader />
      <main>
        <section style={{padding: '2rem 0'}}>
          <div className="container">
            <div className="row">
              {features.map((f, idx) => (
                <FeatureItem key={idx} {...f} />
              ))}
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
