const BLOCK_RANGE = 99n
const DEFAULT_MAX_BLOCKS = 50000n
const TIMEOUT_MS = 30000
const EARLY_STOP_EMPTY_CHUNKS = 5

export async function getLogsChunked(
  publicClient: any,
  params: {
    address: `0x${string}`
    event: any
    args?: any
    maxBlocks?: bigint
  }
) {
  const latest = await publicClient.getBlockNumber()
  const maxBlocks = params.maxBlocks ?? DEFAULT_MAX_BLOCKS
  const from = latest > maxBlocks ? latest - maxBlocks : 0n
  const allLogs: any[] = []

  const deadline = Date.now() + TIMEOUT_MS
  let fromBlock = from
  let emptyStreak = 0

  while (fromBlock <= latest && Date.now() < deadline) {
    const toBlock = fromBlock + BLOCK_RANGE > latest ? latest : fromBlock + BLOCK_RANGE
    try {
      const logs = await publicClient.getLogs({
        ...params,
        fromBlock,
        toBlock,
      })
      if (logs.length > 0) {
        allLogs.push(...logs)
        emptyStreak = 0
      } else {
        emptyStreak++
      }
    } catch {
      emptyStreak++
    }
    if (emptyStreak >= EARLY_STOP_EMPTY_CHUNKS) break
    fromBlock = toBlock + 1n
  }

  return allLogs
}
