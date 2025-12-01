import { Wallet, Send, Download } from "lucide-react"

interface WalletOverviewProps {
  balance: number
}

export function WalletOverview({ balance }: WalletOverviewProps) {
  return (
    <div className="glass-card p-8 rounded-2xl border border-white/5">
      <div className="flex items-center justify-between mb-8">
        <h2 className="text-2xl font-bold">Wallet</h2>
        <div className="p-3 bg-blue-500/10 rounded-lg">
          <Wallet className="w-6 h-6 text-blue-400" />
        </div>
      </div>

      {/* Wallet Address */}
      <div className="bg-white/5 rounded-lg p-4 mb-6">
        <p className="text-xs text-gray-400 mb-2">Wallet Address</p>
        <p className="text-sm font-mono text-gray-300 break-all">0x742d35Cc6634C0532925a3b844Bc9e7595f42e1</p>
      </div>

      {/* Quick Actions */}
      <div className="grid grid-cols-2 gap-3">
        <button className="flex items-center justify-center gap-2 px-4 py-3 rounded-lg btn-ghost-gx font-semibold border hover:bg-green-500/10 transition">
          <Send className="w-4 h-4" />
          <span className="text-sm">Send</span>
        </button>
        <button className="flex items-center justify-center gap-2 px-4 py-3 rounded-lg btn-ghost-gx font-semibold border hover:bg-green-500/10 transition">
          <Download className="w-4 h-4" />
          <span className="text-sm">Receive</span>
        </button>
      </div>
    </div>
  )
}
