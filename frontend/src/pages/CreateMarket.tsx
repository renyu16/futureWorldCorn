import { useState } from 'react'
import { useWriteCreateMarket } from '../hooks/useMarket'
import { predictionMarketABI, PREDICTION_MARKET_ADDRESS } from '../contracts/abi'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

export function CreateMarket() {
  const { writeContract } = useWriteCreateMarket()
  const [question, setQuestion] = useState('')
  const [deadline, setDeadline] = useState('')
  const [feeBps, setFeeBps] = useState('')
  const [status, setStatus] = useState('')

  const handleCreate = async () => {
    if (!question || !deadline) return
    const deadlineUnix = Math.floor(new Date(deadline).getTime() / 1000)
    if (deadlineUnix <= Math.floor(Date.now() / 1000)) {
      setStatus('Deadline must be in the future.')
      return
    }
    const fee = feeBps ? Number(feeBps) : 0
    if (fee > 1000) {
      setStatus('Fee cannot exceed 1000 basis points (10%).')
      return
    }
    writeContract({
      address: PREDICTION_MARKET_ADDRESS, abi: predictionMarketABI, functionName: 'createMarket',
      args: [question, deadlineUnix, fee],
    })
    setStatus('Transaction submitted. Check wallet to confirm.')
  }

  return (
    <Card className="max-w-2xl">
      <CardHeader>
        <CardTitle>Create Market</CardTitle>
        <CardDescription>Deploy a new prediction market on World Chain Sepolia.</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label>Question</Label>
          <Input type="text" value={question} onChange={(e) => setQuestion(e.target.value)} placeholder="e.g. Will ETH reach $10k by end of 2026?" />
        </div>
        <div className="space-y-2">
          <Label>Deadline</Label>
          <Input type="datetime-local" value={deadline} onChange={(e) => setDeadline(e.target.value)} />
        </div>
        <div className="space-y-2">
          <Label>Fee (basis points, optional)</Label>
          <Input type="number" value={feeBps} onChange={(e) => setFeeBps(e.target.value)} placeholder="e.g. 250 = 2.5%" min="0" max="1000" />
        </div>
        <Button className="w-full" disabled={!question || !deadline} onClick={handleCreate}>Create Market</Button>
        {status && <p className="text-sm text-muted">{status}</p>}
      </CardContent>
    </Card>
  )
}
