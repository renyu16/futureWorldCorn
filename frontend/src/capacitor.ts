import { App } from '@capacitor/app'

export const isNative = (): boolean =>
  typeof (window as any).Capacitor !== 'undefined' &&
  (window as any).Capacitor.isNativePlatform?.()

export async function setupDeepLink(): Promise<void> {
  if (!isNative()) return
  await App.addListener('appUrlOpen', (data) => {
    const url = data.url
    if (url.startsWith('wc:')) {
      window.location.href = url
    }
  })
}
