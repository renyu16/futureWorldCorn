class Category {
  final String id;
  final String label;
  final List<String> keywords;
  const Category({required this.id, required this.label, required this.keywords});
}

const List<Category> categories = [
  Category(id: 'crypto', label: '加密', keywords: ['btc', 'bitcoin', 'eth', 'ethereum', 'sol', 'token', '加密', '币', '链', 'tvl', 'defi', 'nft', 'world chain', 'worldchain', 'corn', 'crypto', 'usdc', 'usdt', 'bnb', 'xrp', 'doge', 'wld', 'worldcoin', 'coin']),
  Category(id: 'sports', label: '体育', keywords: ['比赛', '冠军', 'nba', '足球', '世界杯', '球赛', 'cpl']),
  Category(id: 'politics', label: '政治', keywords: ['选举', '总统', '政策', '大选', '法案', 'bill', 'government']),
  Category(id: 'economy', label: '经济', keywords: ['通胀', '利率', 'gdp', 'cpi', '美联储', 'fed', '就业']),
  Category(id: 'culture', label: '文化', keywords: ['奥斯卡', '格莱美', '电影', '专辑', '颁奖']),
  Category(id: 'tech', label: '科技', keywords: ['ai', '芯片', '发布', '发射', 'launch', 'gpt', '机器人']),
];

const String categoryOther = 'other';

String classifyQuestion(String question) {
  final q = question.toLowerCase();
  for (final cat in categories) {
    for (final kw in cat.keywords) {
      if (q.contains(kw)) return cat.id;
    }
  }
  return categoryOther;
}

String categoryLabel(String id) {
  if (id == categoryOther) return '其他';
  for (final cat in categories) {
    if (cat.id == id) return cat.label;
  }
  return '其他';
}
