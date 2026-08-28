import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import { Countdown } from '../components/Countdown'

describe('Countdown', () => {
  it('renders expired state for past deadline', () => {
    const pastDeadline = Math.floor(Date.now() / 1000) - 3600
    render(<Countdown deadline={pastDeadline} />)
    expect(screen.getByText('已截止')).toBeInTheDocument()
  })

  it('renders remaining time for future deadline', () => {
    const futureDeadline = Math.floor(Date.now() / 1000) + 86400
    render(<Countdown deadline={futureDeadline} />)
    expect(screen.getByText(/剩余/)).toBeInTheDocument()
  })
})
