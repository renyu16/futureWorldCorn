export interface Category {
  id: string
  label: string
  keywords: string[]
}

export const CATEGORIES: Category[] = [
  { id: 'crypto', label: '加密', keywords: ['btc', 'bitcoin', 'eth', 'ethereum', 'sol', 'token', '加密', '币', '链', 'tvl', 'defi', 'nft', 'world chain', 'worldchain', 'corn', 'crypto', 'usdc', 'usdt', 'bnb', 'xrp', 'doge', 'wld', 'worldcoin', 'coin'] },
  { id: 'sports', label: '体育', keywords: ['比赛', '冠军', 'nba', '足球', '世界杯', '球赛', 'cpl'] },
  { id: 'politics', label: '政治', keywords: ['选举', '总统', '政策', '大选', '法案', 'bill', '总统', 'government'] },
  { id: 'economy', label: '经济', keywords: ['通胀', '利率', 'gdp', 'cpi', '美联储', 'fed', '就业'] },
  { id: 'culture', label: '文化', keywords: ['奥斯卡', '格莱美', '电影', '专辑', '颁奖'] },
  { id: 'tech', label: '科技', keywords: ['ai', '芯片', '发布', '发射', 'launch', 'gpt', '机器人'] },
]

export const CATEGORY_OTHER = 'other'

export function classifyQuestion(question: string): string {
  const q = question.toLowerCase()
  for (const cat of CATEGORIES) {
    for (const kw of cat.keywords) {
      if (q.includes(kw)) return cat.id
    }
  }
  return CATEGORY_OTHER
}
