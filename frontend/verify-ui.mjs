import { chromium } from 'playwright'

const BASE = process.env.BASE_URL || 'http://localhost:5173'
const results = []
let consoleErrors = []

function record(name, ok, detail = '') {
  results.push({ name, ok, detail })
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? `  (${detail})` : ''}`)
}

async function main() {
  const browser = await chromium.launch()
  const page = await browser.newPage()

  page.on('console', (msg) => {
    if (msg.type() === 'error') consoleErrors.push(msg.text())
  })
  page.on('pageerror', (err) => consoleErrors.push(`pageerror: ${err.message}`))

  // 1. Page loads
  await page.goto(BASE, { waitUntil: 'networkidle', timeout: 60000 })
  const title = await page.title()
  record('page loads', title.length > 0, `title=${JSON.stringify(title)}`)

  const h1 = await page.locator('h1').textContent()
  record('app header renders', h1 === 'Prediction Master', `h1=${JSON.stringify(h1)}`)

  // 2. Connect button exists (RainbowKit, localized)
  await page.waitForSelector('header button', { timeout: 30000 })
  const connectBtn = page.locator('header button').last()
  const hasConnect = await connectBtn.isVisible().catch(() => false)
  const connectText = hasConnect ? await connectBtn.innerText().catch(() => '') : ''
  record('connect wallet button visible', hasConnect, `text=${JSON.stringify(connectText)}`)

  // 3. Market list reads live chain data via public RPC
  const marketsHeading = page.locator('h2:has-text("Markets (")')
  let marketCount = 0
  try {
    await marketsHeading.waitFor({ state: 'visible', timeout: 60000 })
    const headingText = await marketsHeading.textContent()
    marketCount = Number((headingText.match(/\((\d+)\)/) || [])[1] || 0)
    record('market list reads chain (marketCount>0)', marketCount > 0, `count=${marketCount}`)
  } catch (e) {
    record('market list reads chain (marketCount>0)', false, e.message.split('\n')[0])
  }

  // market cards render
  const cards = page.locator('div[style*="border-radius: 8px"]')
  const cardCount = await cards.count()
  record('market cards render', cardCount === marketCount, `cards=${cardCount}`)

  // card content matches on-chain data (question text + pools)
  await page.locator('h3').first().waitFor({ state: 'visible', timeout: 60000 })
  const question = await page.locator('h3').first().innerText()
  const bodyText = await page.locator('body').innerText()
  const hasPools = /YES Pool: \d+\.\d+ \| NO Pool: \d+\.\d+/.test(bodyText)
  record('market card shows on-chain question', question.includes('ETH above 1000'), `question=${JSON.stringify(question)}`)
  record('market card shows pool amounts', hasPools)

  // 4. Nav tabs render without crashing
  const tabs = [
    ['Markets', 'h2:has-text("Markets (")'],
    ['Create', 'h2:has-text("Create Market")'],
    ['Portfolio', 'h2:has-text("Portfolio")'],
    ['Delegate', 'h2:has-text("Delegate")'],
    ['Governance', 'h2:has-text("Governance")'],
    ['Disputes', 'h2:has-text("HumanHouse")'],
  ]
  for (const [label, selector] of tabs) {
    const btn = page.locator(`nav button:has-text("${label}")`).first()
    try {
      await btn.click({ timeout: 10000 })
      await page.locator(selector).waitFor({ state: 'visible', timeout: 60000 })
      record(`tab renders: ${label}`, true)
    } catch (e) {
      record(`tab renders: ${label}`, false, e.message.split('\n')[0])
    }
  }

  // 5. Portfolio unconnected state
  await page.locator('nav button:has-text("Portfolio")').first().click()
  await page.locator('text=Connect your wallet to view portfolio.').waitFor({ state: 'visible', timeout: 30000 })
  record('portfolio unconnected state', true)

  // 6. Disputes page renders (HumanHouse not deployed yet -> no chain deposit expected)
  await page.locator('nav button:has-text("Disputes")').first().click()
  const raiseDisputeVisible = await page.locator('h3:has-text("Raise Dispute")').isVisible().catch(() => false)
  record('humanhouse page renders', raiseDisputeVisible)

  // 7. Console errors (allow known benign warnings, fail on real errors)
  const benign = [
    'favicon',
    'ResizeObserver',
    'WebSocket connection',
  ]
  const realErrors = consoleErrors.filter((e) => !benign.some((b) => e.includes(b)))
  record('no console/page errors', realErrors.length === 0, realErrors.slice(0, 3).join(' | '))

  await browser.close()

  const failed = results.filter((r) => !r.ok)
  console.log(`\n=== ${results.length - failed.length}/${results.length} checks passed ===`)
  process.exit(failed.length ? 1 : 0)
}

main().catch((e) => {
  console.error('Verification crashed:', e)
  process.exit(1)
})
