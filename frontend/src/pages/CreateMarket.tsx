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
      setStatus('截止时间必须晚于当前时间。')
      return
    }
    const fee = feeBps ? Number(feeBps) : 0
    if (fee > 1000) {
      setStatus('费率不能超过 1000 个基点（10%）。')
      return
    }
    writeContract({
      address: PREDICTION_MARKET_ADDRESS, abi: predictionMarketABI, functionName: 'createMarket',
      args: [question, deadlineUnix, fee],
    })
    setStatus('交易已提交，请在钱包中确认。')
  }

  return (
    <Card className="max-w-2xl">
      <CardHeader>
        <CardTitle>创建市场</CardTitle>
        <CardDescription>在 World Chain Sepolia 测试网上部署一个新的预测市场。</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label>问题</Label>
          <Input type="text" value={question} onChange={(e) => setQuestion(e.target.value)} placeholder="例如：ETH 在 2026 年底前会突破 $10k 吗？" />
        </div>
        <div className="space-y-2">
          <Label>截止时间</Label>
          <Input type="datetime-local" value={deadline} onChange={(e) => setDeadline(e.target.value)} />
        </div>
        <div className="space-y-2">
          <Label>费率（基点，可选）</Label>
          <Input type="number" value={feeBps} onChange={(e) => setFeeBps(e.target.value)} placeholder="例如 250 = 2.5%" min="0" max="1000" />
        </div>
        <Button className="w-full" disabled={!question || !deadline} onClick={handleCreate}>创建市场</Button>
        {status && <p className="text-sm text-muted">{status}</p>}
      </CardContent>
    </Card>
  )
}
