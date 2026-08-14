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
  record('app header renders', h1 === '预测大师', `h1=${JSON.stringify(h1)}`)

  // 2. Connect button exists (RainbowKit, localized)
  await page.waitForSelector('header button', { timeout: 30000 })
  const connectBtn = page.locator('header button').last()
  const hasConnect = await connectBtn.isVisible().catch(() => false)
  const connectText = hasConnect ? await connectBtn.innerText().catch(() => '') : ''
  record('connect wallet button visible', hasConnect, `text=${JSON.stringify(connectText)}`)

  // 3. Market list reads live chain data via public RPC
  const marketsHeading = page.locator('h2:has-text("市场（")')
  let marketCount = 0
  try {
    await marketsHeading.waitFor({ state: 'visible', timeout: 60000 })
    const headingText = await marketsHeading.textContent()
    marketCount = Number((headingText.match(/（(\d+)）/) || [])[1] || 0)
    record('market list reads chain (marketCount>0)', marketCount > 0, `count=${marketCount}`)
  } catch (e) {
    record('market list reads chain (marketCount>0)', false, e.message.split('\n')[0])
  }

  // market cards render (each card has a View Details button)
  const cards = page.locator('main button:has-text("查看详情")')
  try {
    await cards.first().waitFor({ state: 'visible', timeout: 60000 })
  } catch { /* count() below still reports the truth */ }
  const cardCount = await cards.count()
  record('market cards render', cardCount === marketCount, `cards=${cardCount}`)

  // card content matches on-chain data (question text + pools)
  const ethCard = page.locator('main div:has-text("ETH above 1000")').first()
  const hasEthQuestion = (await ethCard.count()) > 0
  const bodyText = await page.locator('body').innerText()
  const hasPools = /YES \d+\.\d+/.test(bodyText) && /NO \d+\.\d+/.test(bodyText)
  record('market card shows on-chain question', hasEthQuestion, `found=${hasEthQuestion}`)
  record('market card shows pool amounts', hasPools)

  // 3b. Category filter bar renders; clicking a category filters cards
  const catBtn = page.locator('main button:has-text("加密")').first()
  try {
    await catBtn.waitFor({ state: 'visible', timeout: 30000 })
    const before = await page.locator('main button:has-text("查看详情")').count()
    await catBtn.click()
    await page.waitForTimeout(500)
    const after = await page.locator('main button:has-text("查看详情")').count()
    record('category filter bar renders and filters', after > 0 && after < before, `before=${before} after=${after}`)
    await page.locator('main button:has-text("全部")').first().click()
    await page.waitForTimeout(500)
  } catch (e) {
    record('category filter bar renders and filters', false, e.message.split('\n')[0])
  }

  // 3a. Trending section renders with open market cards
  const trendingCard = page.locator('[data-testid="trending-card"]').first()
  try {
    await trendingCard.waitFor({ state: 'visible', timeout: 30000 })
    const trendingCards = await page.locator('[data-testid="trending-card"]').count()
    record('trending section renders', trendingCards > 0, `cards=${trendingCards}`)
  } catch (e) {
    record('trending section renders', false, e.message.split('\n')[0])
  }

  // 4. Nav tabs render without crashing
  const tabs = [
    ['市场', 'h2:has-text("市场（")'],
    ['投资组合', 'h2:has-text("投资组合")'],
    ['委托', 'h2:has-text("委托")'],
    ['治理', 'h2:has-text("治理")'],
    ['争议', 'h2:has-text("HumanHouse")'],
  ]
  for (const [label, selector] of tabs) {
    const btn = page.locator(`[role="tab"]:has-text("${label}")`).first()
    try {
      await btn.click({ timeout: 10000 })
      await page.locator(selector).waitFor({ state: 'visible', timeout: 60000 })
      record(`tab renders: ${label}`, true)
    } catch (e) {
      record(`tab renders: ${label}`, false, e.message.split('\n')[0])
    }
  }

  // 4b. Role gating: unconnected (non-owner) users must NOT see the Create tab
  const createTabCount = await page.locator('[role="tab"]:has-text("创建")').count()
  record('create tab hidden for non-owner', createTabCount === 0, `createTabs=${createTabCount}`)

  // 5. Portfolio unconnected state
  await page.locator('[role="tab"]:has-text("投资组合")').first().click()
  await page.locator('text=连接钱包以查看投资组合。').waitFor({ state: 'visible', timeout: 30000 })
  record('portfolio unconnected state', true)

  // 6. Disputes page renders (HumanHouse not deployed yet -> no chain deposit expected)
  await page.locator('[role="tab"]:has-text("争议")').first().click()
  const raiseDisputeVisible = await page.locator('text=发起争议').first().isVisible().catch(() => false)
  record('humanhouse page renders', raiseDisputeVisible)

  // 7. Console errors (allow known benign warnings, fail on real errors)
  const benign = [
    'favicon',
    'ResizeObserver',
    'WebSocket connection',
    'ERR_CONNECTION_RESET',
    'pulse.walletconnect.org',
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
