import { useState, useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { useToast } from '../components/Toast'
import { Settings as SettingsIcon, CheckCircle, AlertCircle, RefreshCw } from 'lucide-react'
import { RPC_URL as DEFAULT_RPC } from '../config'

const STORAGE_KEY_RPC = 'app_rpc_url'

export function getStoredRpcUrl(): string {
  try {
    return localStorage.getItem(STORAGE_KEY_RPC) || ''
  } catch {
    return ''
  }
}

function isValidUrl(str: string): boolean {
  if (!str) return true
  try {
    const url = new URL(str)
    return url.protocol === 'http:' || url.protocol === 'https:'
  } catch {
    return false
  }
}

export function Settings() {
  const { toast } = useToast()
  const [rpcUrl, setRpcUrl] = useState('')
  const [loaded, setLoaded] = useState(false)
  const [testing, setTesting] = useState(false)
  const [testResult, setTestResult] = useState<'ok' | 'fail' | null>(null)

  useEffect(() => {
    setRpcUrl(getStoredRpcUrl())
    setLoaded(true)
  }, [])

  const currentRpc = rpcUrl || DEFAULT_RPC
  const isCustom = !!rpcUrl
  const isValid = isValidUrl(rpcUrl)

  const testConnection = async () => {
    if (!rpcUrl) return
    setTesting(true)
    setTestResult(null)
    const ac = new AbortController()
    const timer = setTimeout(() => ac.abort(), 8000)
    try {
      const res = await fetch(rpcUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ jsonrpc: '2.0', method: 'eth_blockNumber', params: [], id: 1 }),
        signal: ac.signal,
      })
      const data = await res.json()
      if (data.result) {
        setTestResult('ok')
        toast(`连接成功，当前区块：${parseInt(data.result, 16)}`, 'success')
      } else {
        setTestResult('fail')
        toast('响应格式异常', 'error')
      }
    } catch (e: any) {
      setTestResult('fail')
      const msg = ac.signal.aborted ? '连接超时（8秒）' : (e.message || '未知错误')
      toast('连接失败：' + msg, 'error')
    } finally {
      clearTimeout(timer)
      setTesting(false)
    }
  }

  const saveRpc = () => {
    if (!isValid) {
      toast('URL 格式无效，请检查', 'error')
      return
    }
    try {
      localStorage.setItem(STORAGE_KEY_RPC, rpcUrl)
      toast('设置已保存，页面即将刷新', 'success')
      setTimeout(() => window.location.reload(), 500)
    } catch {
      toast('保存失败', 'error')
    }
  }

  const restoreDefault = () => {
    try {
      localStorage.removeItem(STORAGE_KEY_RPC)
      setRpcUrl('')
      toast('已恢复默认，页面即将刷新', 'success')
      setTimeout(() => window.location.reload(), 500)
    } catch {
      toast('操作失败', 'error')
    }
  }

  if (!loaded) return null

  return (
    <div className="space-y-4">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <SettingsIcon className="h-5 w-5" />
            网络设置
          </CardTitle>
          <CardDescription>
            配置自定义 RPC 节点地址，留空使用默认 Alchemy 公网节点
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="rpc-url">RPC URL</Label>
            <Input
              id="rpc-url"
              value={rpcUrl}
              onChange={(e) => { setRpcUrl(e.target.value); setTestResult(null) }}
              placeholder={DEFAULT_RPC}
              className="font-mono text-sm"
              autoComplete="url"
            />
            {!isValid && (
              <p className="flex items-center gap-1 text-xs text-no">
                <AlertCircle className="h-3 w-3" />
                URL 格式无效（需要 http:// 或 https:// 开头）
              </p>
            )}
          </div>

          <div className="flex flex-wrap gap-2">
            <Button onClick={saveRpc} disabled={!isValid}>
              保存
            </Button>
            <Button
              variant="outline"
              onClick={testConnection}
              disabled={!rpcUrl || testing || !isValid}
            >
              {testing ? (
                <>
                  <RefreshCw className="mr-1 h-4 w-4 animate-spin" />
                  测试中...
                </>
              ) : (
                '测试连接'
              )}
            </Button>
            <Button variant="ghost" onClick={restoreDefault}>
              恢复默认
            </Button>
          </div>

          <div className="rounded-lg border border-border/50 bg-muted/20 p-3">
            <div className="flex items-center gap-2 text-sm">
              {isCustom ? (
                <CheckCircle className="h-4 w-4 text-yes" />
              ) : (
                <CheckCircle className="h-4 w-4 text-muted" />
              )}
              <span className="text-muted">当前生效：</span>
              <span className="font-mono text-xs break-all">{currentRpc}</span>
            </div>
            {testResult && (
              <p className={`mt-1 text-xs ${testResult === 'ok' ? 'text-yes' : 'text-no'}`}>
                {testResult === 'ok' ? '✓ 连接正常' : '✗ 连接失败'}
              </p>
            )}
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-sm">常见 RPC 节点</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-2 text-sm text-muted">
            <p>默认：<span className="font-mono text-xs">{DEFAULT_RPC}</span></p>
            <p>阿里云反代（手机网络可直连）：<span className="font-mono text-xs">http://8.141.100.69:8085/rpc</span></p>
            <p>局域网示例：<span className="font-mono text-xs">http://192.168.1.100:8545</span></p>
            <p>本机测试：<span className="font-mono text-xs">http://127.0.0.1:8545</span>（需 adb reverse）</p>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
