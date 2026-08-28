import { useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useWriteCreateMarket } from '../hooks/useMarket'
import { predictionMarketABI, PREDICTION_MARKET_ADDRESS } from '../contracts/abi'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Loader2 } from 'lucide-react'
import { useToast } from '../components/Toast'

export function CreateMarket() {
  const queryClient = useQueryClient()
  const { writeContract, isPending } = useWriteCreateMarket()
  const { toast } = useToast()
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
    toast('交易已提交，请等待确认...', 'info')
    writeContract({
      address: PREDICTION_MARKET_ADDRESS, abi: predictionMarketABI, functionName: 'createMarket',
      args: [question, deadlineUnix, fee],
    }, {
      onSuccess: () => queryClient.invalidateQueries({ queryKey: ['readContract'] }),
      onError: (e: any) => { toast('交易失败: ' + (e.shortMessage ?? e.message), 'error'); setStatus('') },
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
          <Label htmlFor="create-question">问题</Label>
          <Input id="create-question" type="text" value={question} onChange={(e) => setQuestion(e.target.value)} placeholder="例如：ETH 在 2026 年底前会突破 $10k 吗？" />
        </div>
        <div className="space-y-2">
          <Label htmlFor="create-deadline">截止时间</Label>
          <Input id="create-deadline" type="datetime-local" value={deadline} onChange={(e) => setDeadline(e.target.value)} />
        </div>
        <div className="space-y-2">
          <Label htmlFor="create-fee">费率（基点，可选）</Label>
          <Input id="create-fee" type="number" value={feeBps} onChange={(e) => setFeeBps(e.target.value)} placeholder="例如 250 = 2.5%" min="0" max="1000" />
        </div>
        <Button className="w-full" disabled={!question || !deadline || isPending} onClick={handleCreate}>
          {isPending ? <><Loader2 className="h-4 w-4 animate-spin" /> 创建中...</> : '创建市场'}
        </Button>
        {status && <p className="text-sm text-muted">{status}</p>}
      </CardContent>
    </Card>
  )
}
