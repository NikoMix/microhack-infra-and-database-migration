import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
const repo = process.env.GITHUB_REPOSITORY ?? 'NikoMix/microhack-infra-and-database-migration';
const [owner, repoName] = repo.split('/');
const isUserOrOrgPage = repoName?.toLowerCase() === `${owner?.toLowerCase()}.github.io`;
const site = process.env.ASTRO_SITE ?? (isUserOrOrgPage ? `https://${owner}.github.io` : `https://${owner}.github.io/${repoName}`);
const base = process.env.ASTRO_BASE ?? (isUserOrOrgPage ? '/' : `/${repoName}/`);
const githubUrl = process.env.ASTRO_GITHUB_URL ?? `https://github.com/${repo}`;
export default defineConfig({ site, base, integrations: [ starlight({
  title: 'Migrate & Modernize to Azure — MicroHack',
  description: 'Train-the-Trainer hands-on labs for the Infrastructure and Database Migration to Microsoft Azure Advanced Specialization (Module B).',
  social: [{ icon: 'github', label: 'GitHub', href: githubUrl }],
  editLink: { baseUrl: `${githubUrl}/edit/main/docs-site/` },
  sidebar: [
    { label: 'Start Here', items: [ { autogenerate: { directory: 'start-here' } } ] },
    { label: 'Challenges', items: [ { autogenerate: { directory: 'challenges' } } ] },
    { label: 'Trainer Guide', items: [ { autogenerate: { directory: 'trainer' } } ] },
    { label: 'Reference', items: [ { autogenerate: { directory: 'reference' } } ] },
  ] }) ] });
