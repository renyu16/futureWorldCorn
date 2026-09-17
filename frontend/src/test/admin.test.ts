import { describe, it, expect } from 'vitest'
import { getAdminRole, isRightChain } from '../lib/admin'

describe('getAdminRole', () => {
  const OWNER = '0xDeF213DFeB1D3d09158E64C31d8e32fF0484033f'
  const OPERATOR = '0xbaD8931A4A6a25710644BcA9F9d07680ABaB1dA5'
  const OTHER = '0xa9224844a50bd920461685dd84e2f839f53c1f3b'

  it('返回 unconnected 当未连接钱包', () => {
    expect(getAdminRole({ address: undefined, owner: OWNER, isResolver: false })).toBe('unconnected')
  })

  it('返回 owner 当地址等于合约 owner()（大小写不敏感）', () => {
    expect(getAdminRole({ address: OWNER, owner: OWNER, isResolver: false })).toBe('owner')
    expect(getAdminRole({ address: OWNER.toLowerCase(), owner: OWNER, isResolver: false })).toBe('owner')
  })

  it('返回 operator 当 resolvers[address] 为 true', () => {
    expect(getAdminRole({ address: OPERATOR, owner: OWNER, isResolver: true })).toBe('operator')
  })

  it('返回 none 当既非 owner 也非 resolver', () => {
    expect(getAdminRole({ address: OTHER, owner: OWNER, isResolver: false })).toBe('none')
  })

  it('owner 优先于 resolver（owner 也常被登记为 resolver）', () => {
    expect(getAdminRole({ address: OWNER, owner: OWNER, isResolver: true })).toBe('owner')
  })

  it('owner 未加载时（合约读取 pending）不误判为 none', () => {
    expect(getAdminRole({ address: OWNER, owner: undefined, isResolver: false })).toBe('unknown')
  })
})

describe('isRightChain', () => {
  it('链一致返回 true', () => {
    expect(isRightChain(4801, 4801)).toBe(true)
  })
  it('链不一致返回 false（4801 vs 480）', () => {
    expect(isRightChain(480, 4801)).toBe(false)
  })
  it('未连接（chainId undefined）返回 false', () => {
    expect(isRightChain(undefined, 4801)).toBe(false)
  })
})