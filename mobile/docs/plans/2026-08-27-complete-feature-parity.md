# 预测大师 Flutter — 补齐4个缺失页面实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在 Flutter 移动端补齐浏览器版的全部功能：投资组合、委托、治理、HumanHouse 争议，使两端功能完全一致。

**Architecture:** 扩展 `contract_service.dart` 添加 govCORN/TokenHouse/HumanHouse 的读写方法和事件日志查询；创建底部导航壳 (NavigationShell) 替代当前单页架构；逐页实现4个缺失页面，每个页面通过 Provider 从链上读取数据，写入操作显示原始交易数据供手动签名。

**Tech Stack:** Flutter + Riverpod + http (JSON-RPC) + SharedPreferences，无新依赖。

---

## Task 1: 扩展 ContractService — 添加 govCORN / TokenHouse / HumanHouse 方法

**Files:**
- Modify: `lib/services/contract_service.dart`

**Step 1: 添加 govCORN 读取方法**

在 `contract_service.dart` 的 `// ── Token reads ──` 区域下方添加新区域 `// ── govCORN reads ──`：

```dart
// ── govCORN reads ──

static Future<BigInt> govCornBalance(String rpcUrl, String userAddress) async {
  return _readUint(rpcUrl, addr.govCornTokenAddress, '0x70a08231${_addrPad(userAddress)}');
}

static Future<BigInt> govCornVotes(String rpcUrl, String userAddress) async {
  return _readUint(rpcUrl, addr.govCornTokenAddress, '0x9a5e179d${_addrPad(userAddress)}');
}

static Future<BigInt> govCornAllowance(String rpcUrl, String userAddress) async {
  final ownerPad = _addrPad(userAddress);
  final spenderPad = _addrPad(addr.govCornTokenAddress);
  return _readUint(rpcUrl, addr.cornTokenAddress, '0xdd62ed3f$ownerPad$spenderPad');
}

static Future<String> govCornDelegates(String rpcUrl, String userAddress) async {
  final result = await _ethCall(rpcUrl, addr.govCornTokenAddress, '0x765722e1${_addrPad(userAddress)}');
  if (result == null || result == '0x') return '';
  return '0x${result.substring(26)}';
}

static Future<BigInt> govCornGetVotes(String rpcUrl, String delegateAddress) async {
  return _readUint(rpcUrl, addr.govCornTokenAddress, '0x9a5e179d${_addrPad(delegateAddress)}');
}
```

**Step 2: 添加 TokenHouse 读取方法**

在 `// ── Dispute reads ──` 区域上方添加新区域 `// ── TokenHouse reads ──`：

```dart
// ── TokenHouse reads ──

static Future<int> proposalState(String rpcUrl, int proposalId) async {
  final val = await _readUint(rpcUrl, addr.tokenHouseAddress, '0x317240ea${_uintPadInt(proposalId)}');
  return val.toInt();
}

static Future<List<BigInt>> proposalVotes(String rpcUrl, int proposalId) async {
  final result = await _ethCall(rpcUrl, addr.tokenHouseAddress, '0x57040343${_uintPadInt(proposalId)}');
  if (result == null || result.length < 194) return [BigInt.zero, BigInt.zero, BigInt.zero];
  int w(int n) => 2 + n * 64;
  return [
    BigInt.parse(result.substring(w(0), w(1)), radix: 16),
    BigInt.parse(result.substring(w(1), w(2)), radix: 16),
    BigInt.parse(result.substring(w(2), w(3)), radix: 16),
  ];
}

static Future<String> proposalProposer(String rpcUrl, int proposalId) async {
  final result = await _ethCall(rpcUrl, addr.tokenHouseAddress, '0x4613dc10${_uintPadInt(proposalId)}');
  if (result == null || result == '0x') return '';
  return '0x${result.substring(26)}';
}

static Future<int> proposalDeadline(String rpcUrl, int proposalId) async {
  final val = await _readUint(rpcUrl, addr.tokenHouseAddress, '0x0b8a0448${_uintPadInt(proposalId)}');
  return val.toInt();
}

static Future<int> proposalSnapshot(String rpcUrl, int proposalId) async {
  final val = await _readUint(rpcUrl, addr.tokenHouseAddress, '0x3a087523${_uintPadInt(proposalId)}');
  return val.toInt();
}

static Future<BigInt> proposalThreshold(String rpcUrl) async {
  return _readUint(rpcUrl, addr.tokenHouseAddress, '0x3388838e');
}
```

**Step 3: 添加 HumanHouse 额外读取方法**

在现有 `// ── Dispute reads ──` 区域末尾添加：

```dart
static Future<BigInt> disputeDeposit(String rpcUrl) async {
  return _readUint(rpcUrl, addr.humanHouseAddress, '0x43058948');
}

static Future<BigInt> disputeVotingPeriod(String rpcUrl) async {
  return _readUint(rpcUrl, addr.humanHouseAddress, '0xd6a3844a');
}
```

**Step 4: 添加事件日志查询方法**

在 `// ── Event logs ──` 区域末尾添加：

```dart
static Future<List<Map<String, dynamic>>> getProposalCreatedLogs(String rpcUrl) async {
  final topic = '0x7d84a6263ae0d98d3329bd7b46bb4e8d6f98cd35a7adb45c274c8b7fd5ebd5e0';
  final body = jsonEncode({
    'jsonrpc': '2.0',
    'method': 'eth_getLogs',
    'params': [{'address': addr.tokenHouseAddress, 'topics': [topic]}],
    'id': 1,
  });
  final uri = Uri.parse(rpcUrl);
  final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body)
      .timeout(const Duration(seconds: 15));
  final json = jsonDecode(res.body);
  if (json['error'] != null) return [];
  final logs = (json['result'] as List?) ?? [];
  return logs.map<Map<String, dynamic>>((log) {
    final topics = (log['topics'] as List).cast<String>();
    final proposalId = int.parse(topics[1].substring(26), radix: 16);
    final data = log['data'] as String;
    // description is the last dynamic field; decode from tail
    final descOffset = int.parse(data.substring(data.length - 128, data.length - 64), radix: 16);
    final descLen = int.parse(data.substring(data.length - 64), radix: 16);
    final descStart = 2 + descOffset * 2 + 64;
    final descBytes = _hexToBytes(data.substring(descStart, descStart + descLen * 2));
    final description = utf8.decode(descBytes, allowMalformed: true);
    return {'proposalId': proposalId, 'description': description};
  }).toList();
}

static Future<List<Map<String, dynamic>>> getDisputeCreatedLogs(String rpcUrl) async {
  final topic = '0xd040e3d8a268cd295b5f89ec2e2534dd45f107f73bbefda49c554c14ab5b44cb';
  final body = jsonEncode({
    'jsonrpc': '2.0',
    'method': 'eth_getLogs',
    'params': [{'address': addr.humanHouseAddress, 'topics': [topic]}],
    'id': 1,
  });
  final uri = Uri.parse(rpcUrl);
  final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body)
      .timeout(const Duration(seconds: 15));
  final json = jsonDecode(res.body);
  if (json['error'] != null) return [];
  final logs = (json['result'] as List?) ?? [];
  return logs.map<Map<String, dynamic>>((log) {
    final topics = (log['topics'] as List).cast<String>();
    return {
      'disputeId': int.parse(topics[1].substring(26), radix: 16),
      'marketId': int.parse(topics[2].substring(26), radix: 16),
    };
  }).toList();
}

static Future<List<Map<String, dynamic>>> getVoteCastLogs(String rpcUrl, {int? disputeId}) async {
  final topic = '0xa569f04ac50c7dc602af46da32d6b4bb55adafc0bc482968f959264ea5edde96';
  final params = <String, dynamic>{
    'address': addr.humanHouseAddress,
    'topics': disputeId != null ? [topic, _uintPadInt(disputeId)] : [topic],
  };
  final body = jsonEncode({'jsonrpc': '2.0', 'method': 'eth_getLogs', 'params': [params], 'id': 1});
  final uri = Uri.parse(rpcUrl);
  final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body)
      .timeout(const Duration(seconds: 15));
  final json = jsonDecode(res.body);
  if (json['error'] != null) return [];
  final logs = (json['result'] as List?) ?? [];
  return logs.map<Map<String, dynamic>>((log) {
    final data = log['data'] as String;
    return {
      'disputeId': int.parse(log['topics'][1].substring(26), radix: 16),
      'support': data.substring(2, 66).endsWith('01'),
      'blockNumber': log['blockNumber'],
    };
  }).toList();
}

static Future<List<Map<String, dynamic>>> getDisputeExecutedLogs(String rpcUrl) async {
  final topic = '0x606f6ccbd7f9c4089b2e0e3f07b80bc5e91da4da19f38e1747bde0755ae2ad28';
  final body = jsonEncode({
    'jsonrpc': '2.0',
    'method': 'eth_getLogs',
    'params': [{'address': addr.humanHouseAddress, 'topics': [topic]}],
    'id': 1,
  });
  final uri = Uri.parse(rpcUrl);
  final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body)
      .timeout(const Duration(seconds: 15));
  final json = jsonDecode(res.body);
  if (json['error'] != null) return [];
  final logs = (json['result'] as List?) ?? [];
  return logs.map<Map<String, dynamic>>((log) {
    final data = (log['data'] as String).substring(2);
    return {
      'disputeId': int.parse(log['topics'][1].substring(26), radix: 16),
      'outcome': int.parse(data.substring(0, 64), radix: 16),
      'blockNumber': log['blockNumber'],
    };
  }).toList();
}

static List<int> _hexToBytes(String hex) {
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return bytes;
}
```

**Step 5: 添加写入交易数据构建方法**

在 `// ── Write transaction data builders ──` 区域末尾添加：

```dart
static String depositForData(String userAddress, BigInt amount) {
  return '0xb28bcc8e${_addrPad(userAddress)}${_uintPad(amount)}';
}

static String withdrawToData(String userAddress, BigInt amount) {
  return '0x693ec85e${_addrPad(userAddress)}${_uintPad(amount)}';
}

static String delegateData(String delegateeAddress) {
  return '0x5c19a95c${_addrPad(delegateeAddress)}';
}

static String castVoteData(int proposalId, int support) {
  return '0xc0246668${_uintPadInt(proposalId)}${support.toRadixString(16).padLeft(64, '0')}';
}

static String proposeData(List<String> targets, List<BigInt> values, List<String> calldatas, String description) {
  // Simplified: encode as dynamic arrays
  // This is a complex ABI encoding; for now, show placeholder
  return 'propose(...)';
}
```

**Step 6: 验证**

Run: `flutter analyze 2>&1`
Expected: 0 errors, only info-level warnings about print statements.

---

## Task 2: 创建导航壳 — 底部导航栏

**Files:**
- Create: `lib/pages/navigation_shell.dart`
- Modify: `lib/main.dart`

**Step 1: 创建 NavigationShell**

```dart
// lib/pages/navigation_shell.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_page.dart';
import 'portfolio_page.dart';
import 'delegate_page.dart';
import 'governance_page.dart';
import 'humanhouse_page.dart';
import 'settings_page.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});
  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _currentIndex = 0;

  final _pages = const [
    HomePage(),
    PortfolioPage(),
    DelegatePage(),
    GovernancePage(),
    HumanHousePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: AppTheme.card,
        indicatorColor: AppTheme.primary.withAlpha(25),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '市场'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outlined), selectedIcon: Icon(Icons.pie_chart), label: '投资'),
          NavigationDestination(icon: Icon(Icons.how_to_vote_outlined), selectedIcon: Icon(Icons.how_to_vote), label: '委托'),
          NavigationDestination(icon: Icon(Icons.gavel_outlined), selectedIcon: Icon(Icons.gavel), label: '治理'),
          NavigationDestination(icon: Icon(Icons.balance_outlined), selectedIcon: Icon(Icons.balance), label: '争议'),
        ],
      ),
    );
  }
}
```

**Step 2: 修改 main.dart 使用 NavigationShell**

```dart
// 修改 lib/main.dart 的 home:
home: const NavigationShell(),
```

**Step 3: 修改 HomePage — 移除 Scaffold 的 appBar 和 settings 按钮（移到 NavigationShell）**

需要把 HomePage 的 AppBar 保留（因为每个 tab 不同），但移除 settings 导航按钮到 NavigationShell 的 AppBar 或 drawer。

最简方案：保留 HomePage 的 AppBar，NavigationShell 不显示 AppBar，每个 page 自带 AppBar。

**Step 4: 验证**

Run: `flutter analyze 2>&1`
Run: `flutter build apk --debug 2>&1`
Expected: 构建成功，模拟器底部显示5个导航标签。

---

## Task 3: 实现投资组合页面 (PortfolioPage)

**Files:**
- Create: `lib/pages/portfolio_page.dart`

**Step 1: 创建 PortfolioPage**

核心逻辑：
1. 读取所有市场（复用 marketsProvider）
2. 对每个市场读取用户 sharesYes 和 sharesNo
3. 筛选有持仓的市场
4. 分为"进行中"和"已结算"两组
5. 每个持仓卡片显示：问题、状态、YES/NO 份额百分比条、份额数量、领取按钮

```dart
// lib/pages/portfolio_page.dart
// 完整实现见下方 Task 3 详细代码
```

页面结构：
- 顶部摘要卡：钱包地址、CORN 余额、持仓市场数、总份额
- "进行中"分组 → 持仓卡片列表
- "已结算"分组 → 持仓卡片列表 + 领取按钮
- 未连接钱包提示
- 空状态提示

**Step 2: 验证**

Run: `flutter analyze 2>&1`
Run: `flutter build apk --debug 2>&1`

---

## Task 4: 实现委托页面 (DelegatePage)

**Files:**
- Create: `lib/pages/delegate_page.dart`

**Step 1: 创建 DelegatePage**

核心逻辑：
1. 读取 CORN 余额、govCORN 余额、投票权、allowance、当前委托目标
2. 存入表单：输入金额 → 授权按钮 → 存入按钮
3. 取回表单：输入金额 → 取回按钮
4. 委托表单：输入地址 → 委托按钮
5. 当前委托状态显示

需要新增 ContractService 方法：
- `govCornBalance` (已在 Task 1 添加)
- `govCornVotes` (已在 Task 1 添加)
- `govCornAllowance` (已在 Task 1 添加)
- `govCornDelegates` (已在 Task 1 添加)
- `depositForData` (已在 Task 1 添加)
- `withdrawToData` (已在 Task 1 添加)
- `delegateData` (已在 Task 1 添加)

**Step 2: 验证**

Run: `flutter analyze 2>&1`
Run: `flutter build apk --debug 2>&1`

---

## Task 5: 实现治理页面 (GovernancePage)

**Files:**
- Create: `lib/pages/governance_page.dart`

**Step 1: 创建 GovernancePage**

核心逻辑：
1. 从链上获取 ProposalCreated 事件日志，提取 proposalId 和 description
2. 对每个 proposal 读取 state、votes、proposer、deadline、snapshot
3. 列表显示：ID、状态标签、描述截断、查看按钮
4. 详情视图：提案人、快照区块、截止区块、投票数、投票按钮（赞成/反对/弃权）
5. 创建提案表单：目标地址、ETH 值、函数签名、参数、描述

需要新增 ContractService 方法：
- `proposalState` (已在 Task 1 添加)
- `proposalVotes` (已在 Task 1 添加)
- `proposalProposer` (已在 Task 1 添加)
- `proposalDeadline` (已在 Task 1 添加)
- `proposalSnapshot` (已在 Task 1 添加)
- `proposalThreshold` (已在 Task 1 添加)
- `castVoteData` (已在 Task 1 添加)
- `getProposalCreatedLogs` (已在 Task 1 添加)

**Step 2: 验证**

Run: `flutter analyze 2>&1`
Run: `flutter build apk --debug 2>&1`

---

## Task 6: 实现 HumanHouse 争议页面 (HumanHousePage)

**Files:**
- Create: `lib/pages/humanhouse_page.dart`

**Step 1: 创建 HumanHousePage**

核心逻辑：
1. 获取所有争议（复用 DisputeService）
2. 发起争议表单：市场 ID、类型（预言机结果/市场内容）、原因、授权+提交
3. 争议列表：ID、状态、市场链接、类型、截止、原因截断、投票条、押金
4. 争议详情：完整信息、投票进度条、投票按钮（模拟 World ID）、执行按钮、活动时间线

需要新增 ContractService 方法：
- `disputeDeposit` (已在 Task 1 添加)
- `disputeVotingPeriod` (已在 Task 1 添加)
- `raiseDisputeData` (已有)
- `getDisputeCreatedLogs` (已在 Task 1 添加)
- `getVoteCastLogs` (已在 Task 1 添加)
- `getDisputeExecutedLogs` (已在 Task 1 添加)

**Step 2: 验证**

Run: `flutter analyze 2>&1`
Run: `flutter build apk --debug 2>&1`

---

## Task 7: 最终集成测试

**Step 1: 构建并安装到模拟器**

```bash
flutter build apk --debug 2>&1
```

**Step 2: 安装并启动**

```bash
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell monkey -p com.predictionmaster.future_world_corn_mobile -c android.intent.category.LAUNCHER 1
```

**Step 3: 逐页验证**

1. 市场列表 → 点击进入详情 → 验证所有功能正常
2. 投资组合 → 连接钱包后显示持仓
3. 委托 → 显示余额、委托表单
4. 治理 → 加载提案列表
5. 争议 → 加载争议列表、发起争议表单

**Step 4: 清理 debug print 语句（可选）**

移除 `market_provider.dart` 中的 `print()` 调用。

---

## 文件清单

| 操作 | 文件路径 |
|------|----------|
| Modify | `lib/services/contract_service.dart` |
| Create | `lib/pages/navigation_shell.dart` |
| Create | `lib/pages/portfolio_page.dart` |
| Create | `lib/pages/delegate_page.dart` |
| Create | `lib/pages/governance_page.dart` |
| Create | `lib/pages/humanhouse_page.dart` |
| Modify | `lib/main.dart` |
| Modify | `lib/pages/home_page.dart` (可选: 移除 settings 导航到独立位置) |

## 事件 Topic 哈希 (已验证)

以下 topic 哈希已通过 viem keccak256 验证：

- `ProposalCreated`: `0x7d84a6263ae0d98d3329bd7b46bb4e8d6f98cd35a7adb45c274c8b7fd5ebd5e0`
- `DisputeCreated`: `0xd040e3d8a268cd295b5f89ec2e2534dd45f107f73bbefda49c554c14ab5b44cb`
- `VoteCast`: `0xa569f04ac50c7dc602af46da32d6b4bb55adafc0bc482968f959264ea5edde96`
- `DisputeExecuted`: `0x606f6ccbd7f9c4089b2e0e3f07b80bc5e91da4da19f38e1747bde0755ae2ad28`
