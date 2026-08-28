import { createContext, useCallback, useContext, useMemo, useState } from 'react'
import { CheckCircle, AlertCircle, Info, X } from 'lucide-react'
import { cn } from '@/lib/utils'

type ToastType = 'success' | 'error' | 'info'

interface Toast {
  id: number
  message: string
  type: ToastType
}

interface ToastContextValue {
  toast: (message: string, type?: ToastType) => void
}

const ToastContext = createContext<ToastContextValue | null>(null)

let nextId = 0

const ICONS: Record<ToastType, typeof CheckCircle> = {
  success: CheckCircle,
  error: AlertCircle,
  info: Info,
}

const STYLES: Record<ToastType, string> = {
  success: 'bg-yes text-white',
  error: 'bg-no text-white',
  info: 'bg-primary text-white',
}

function ToastItem({
  toast: t,
  onDismiss,
}: {
  toast: Toast
  onDismiss: (id: number) => void
}) {
  const Icon = ICONS[t.type]

  return (
    <div
      className={cn(
        'pointer-events-auto flex items-center gap-3 rounded-lg px-4 py-3 shadow-lg animate-in slide-in-from-top-2 fill-mode-forwards',
        STYLES[t.type],
      )}
    >
      <Icon className="h-5 w-5 shrink-0" />
      <span className="flex-1 text-sm font-medium">{t.message}</span>
      <button
        onClick={() => onDismiss(t.id)}
        className="shrink-0 rounded-md p-0.5 opacity-80 hover:opacity-100 transition-opacity"
      >
        <X className="h-4 w-4" />
      </button>
    </div>
  )
}

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([])

  const dismiss = useCallback((id: number) => {
    setToasts((prev) => prev.filter((t) => t.id !== id))
  }, [])

  const addToast = useCallback(
    (message: string, type: ToastType = 'info') => {
      const id = nextId++
      setToasts((prev) => [...prev, { id, message, type }])
      const duration = type === 'error' ? 6000 : 3000
      setTimeout(() => dismiss(id), duration)
    },
    [dismiss],
  )

  const ctx = useMemo(() => ({ toast: addToast }), [addToast])

  return (
    <ToastContext.Provider value={ctx}>
      {children}
      <div role="status" aria-live="polite" className="pointer-events-none fixed inset-x-0 top-24 z-50 flex justify-center">
        <div className="pointer-events-auto flex flex-col items-center gap-2">
          {toasts.map((t) => (
            <ToastItem key={t.id} toast={t} onDismiss={dismiss} />
          ))}
        </div>
      </div>
    </ToastContext.Provider>
  )
}

export function useToast(): ToastContextValue {
  const ctx = useContext(ToastContext)
  if (!ctx) throw new Error('useToast must be used within a ToastProvider')
  return ctx
}
