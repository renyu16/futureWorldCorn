export type AdminRole = 'owner' | 'operator' | 'none' | 'unconnected' | 'unknown'

export interface AdminRoleInput {
  address?: string
  owner?: string
  isResolver?: boolean
}

export function getAdminRole({ address, owner, isResolver }: AdminRoleInput): AdminRole {
  if (!address) return 'unconnected'
  if (!owner) return 'unknown'
  if (address.toLowerCase() === owner.toLowerCase()) return 'owner'
  if (isResolver === true) return 'operator'
  return 'none'
}

export function isRightChain(connected: number | undefined, expected: number): boolean {
  return connected === expected
}