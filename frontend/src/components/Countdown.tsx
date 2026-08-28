import { useState, useEffect } from 'react'

interface CountdownProps {
  deadline: number
}

function calcRemaining(deadline: number) {
  const now = Date.now()
  const diff = deadline * 1000 - now
  if (diff <= 0) return null

  const days = Math.floor(diff / 86_400_000)
  const hours = Math.floor((diff % 86_400_000) / 3_600_000)
  const minutes = Math.floor((diff % 3_600_000) / 60_000)
  const seconds = Math.floor((diff % 60_000) / 1_000)

  return { days, hours, minutes, seconds }
}

export function Countdown({ deadline }: CountdownProps) {
  const [remaining, setRemaining] = useState(() => calcRemaining(deadline))

  useEffect(() => {
    if (!remaining) return

    const id = window.setInterval(() => {
      const next = calcRemaining(deadline)
      setRemaining(next)
      if (!next) window.clearInterval(id)
    }, 1_000)

    return () => window.clearInterval(id)
  }, [deadline])

  if (!remaining) {
    return <span className="text-muted">已截止</span>
  }

  return (
    <span className="inline-flex items-center gap-2">
      <span className="relative flex h-2 w-2">
        <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-green-400 opacity-75" />
        <span className="relative inline-flex h-2 w-2 rounded-full bg-green-500" />
      </span>
      <span>
        剩余 {remaining.days}天 {remaining.hours}时 {remaining.minutes}分 {remaining.seconds}秒
      </span>
    </span>
  )
}
