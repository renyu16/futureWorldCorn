import { describe, it, expect } from 'vitest'
import { CHAIN_ID, RPC_URL, getConfig } from '../config'

describe('config', () => {
  it('默认链为 World Chain Sepolia (4801)', () => {
    expect(CHAIN_ID).toBe(4801)
  })

  it('4801 测试网地址均为已确认值', () => {
    const cfg = getConfig(4801)
    expect(cfg.cornToken).toBe('0x7440503d25a38513919203e58db70d3ee14197ed')
    expect(cfg.predictionMarket).toBe('0x9cb69cb7da9677b3a122a6a4e402398a6df4a026')
    expect(cfg.oracleAdapter).toBe('0x1457eef9d78eda3e18095f3ff50e15f10764de72')
    expect(cfg.govCornToken).toBe('0x3F540371f5E88E3B9625b63411e4ba1FDB4702f0')
    expect(cfg.tokenHouse).toBe('0x70Edf96015fE901c44b6b61Ad5CcB9884B545DE9')
    expect(cfg.humanHouse).toBe('0xd1062855477c08bff3c852fc42844ca35db32c72')
  })

  it('480 主网地址为待填占位', () => {
    const cfg = getConfig(480)
    expect(cfg.cornToken).toBe('0x...')
    expect(cfg.predictionMarket).toBe('0x...')
    expect(cfg.oracleAdapter).toBe('0x...')
    expect(cfg.govCornToken).toBe('0x...')
    expect(cfg.tokenHouse).toBe('0x...')
    expect(cfg.humanHouse).toBe('0x...')
  })

  it('未知链抛出异常', () => {
    expect(() => getConfig(999)).toThrow(/No chain config/)
  })

  it('默认 RPC 为测试网公网节点', () => {
    expect(RPC_URL).toBe('https://worldchain-sepolia.g.alchemy.com/public')
  })
})