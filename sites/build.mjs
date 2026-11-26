// Builds one status page per domain from sites/template.html + sites/sites.json into sites/out/.
// Each page is self-contained (no shared script), reads the same outage issues as docs/index.html,
// and shows only its own site's targets. After a change: node sites/build.mjs, then copy each
// sites/out/<id>.html to the repo path in its `deployTo`.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const template = readFileSync(join(here, 'template.html'), 'utf8')
const { sites } = JSON.parse(readFileSync(join(here, 'sites.json'), 'utf8'))
const targets = readFileSync(join(here, '..', 'check.sh'), 'utf8')

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
mkdirSync(join(here, 'out'), { recursive: true })

for (const site of sites) {
  // Every key must be a live check.sh target, or the page would show a service nothing watches.
  for (const g of site.config.groups) for (const s of g.services) {
    if (!targets.includes(`"${s.key}|`)) throw new Error(`${site.id}: "${s.key}" is not a check.sh target`)
  }
  const t = site.theme
  const vars = {
    TITLE: esc(site.title), DESCRIPTION: esc(site.description), CANONICAL: esc(site.canonical),
    HOME: esc(site.home), HOME_LABEL: esc(site.homeLabel),
    CONTACT_LEAD: esc(site.contactLead), CONTACT_HREF: esc(site.contactHref), CONTACT_LABEL: esc(site.contactLabel),
    BG: t.bg, INK: t.ink, INK2: t.ink2, INK3: t.ink3, RULE: t.rule, TICK: t.tick, ACCENT: t.accent, PART: t.part, DOWN: t.down,
    CONFIG: JSON.stringify(site.config).replace(/</g, '\\u003c'),
  }
  const html = template.replace(/\{\{([A-Z0-9_]+)\}\}/g, (m, k) => {
    if (!(k in vars)) throw new Error(`${site.id}: no value for {{${k}}}`)
    return vars[k]
  })
  writeFileSync(join(here, 'out', `${site.id}.html`), html)
  console.log(`${site.id} -> sites/out/${site.id}.html  (deploy to ${site.deployTo})`)
}
