"use client"

import { useState } from "react"
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { ArrowLeftRight, ArrowRight } from "lucide-react"
import { createClient } from "@/lib/supabase/client"
import { useToast } from "@/hooks/use-toast"

interface BalanceTransferModalProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  dashboardBalance: number
  p2pBalance: number
  onTransferComplete: () => void
}

export function BalanceTransferModal({
  open,
  onOpenChange,
  dashboardBalance,
  p2pBalance,
  onTransferComplete,
}: BalanceTransferModalProps) {
  const [amount, setAmount] = useState("")
  const [direction, setDirection] = useState<"to_p2p" | "to_dashboard">("to_p2p")
  const [loading, setLoading] = useState(false)
  const { toast } = useToast()

  const handleTransfer = async () => {
    if (!amount || Number(amount) <= 0) {
      toast({
        title: "Invalid Amount",
        description: "Please enter a valid amount greater than 0",
        variant: "destructive",
      })
      return
    }

    const transferAmount = Number(amount)
    const sourceBalance = direction === "to_p2p" ? dashboardBalance : p2pBalance

    if (transferAmount > sourceBalance) {
      toast({
        title: "Insufficient Balance",
        description: `You don't have enough balance. Available: ${sourceBalance.toFixed(2)} AFX`,
        variant: "destructive",
      })
      return
    }

    setLoading(true)
    const supabase = createClient()

    try {
      const {
        data: { user },
      } = await supabase.auth.getUser()
      if (!user) throw new Error("Not authenticated")

      const functionName = direction === "to_p2p" ? "transfer_to_p2p" : "transfer_from_p2p"

      console.log("[v0] Calling transfer function:", functionName, "with amount:", transferAmount)

      const { data, error } = await supabase.rpc(functionName, {
        p_user_id: user.id,
        p_amount: transferAmount,
      })

      if (error) {
        console.error("[v0] Transfer RPC error:", error)
        throw error
      }

      console.log("[v0] Transfer successful:", data)

      toast({
        title: "Transfer Successful",
        description: `${transferAmount.toFixed(2)} AFX transferred ${
          direction === "to_p2p" ? "to P2P Balance" : "to Dashboard Balance"
        }`,
      })

      setAmount("")
      onTransferComplete()
      onOpenChange(false)
    } catch (error: any) {
      console.error("[v0] Transfer error:", error)
      toast({
        title: "Transfer Failed",
        description:
          error.message || "Failed to transfer funds. Please ensure the database functions are set up correctly.",
        variant: "destructive",
      })
    } finally {
      setLoading(false)
    }
  }

  const toggleDirection = () => {
    setDirection(direction === "to_p2p" ? "to_dashboard" : "to_p2p")
    setAmount("")
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md bg-gray-900 border-gray-800">
        <DialogHeader>
          <DialogTitle className="text-xl font-bold">Transfer AFX</DialogTitle>
        </DialogHeader>

        <div className="space-y-6 py-4">
          {/* Direction Selector */}
          <div className="flex items-center justify-between p-4 bg-gray-800/50 rounded-lg">
            <div className="text-center flex-1">
              <p className="text-xs text-gray-400 mb-1">From</p>
              <p className="font-semibold">{direction === "to_p2p" ? "Dashboard" : "P2P"}</p>
              <p className="text-xs text-green-400 mt-1">
                {(direction === "to_p2p" ? dashboardBalance : p2pBalance).toFixed(2)} AFX
              </p>
            </div>

            <Button variant="ghost" size="icon" onClick={toggleDirection} className="mx-4 hover:bg-gray-700">
              <ArrowLeftRight className="w-5 h-5" />
            </Button>

            <div className="text-center flex-1">
              <p className="text-xs text-gray-400 mb-1">To</p>
              <p className="font-semibold">{direction === "to_p2p" ? "P2P" : "Dashboard"}</p>
              <p className="text-xs text-green-400 mt-1">
                {(direction === "to_p2p" ? p2pBalance : dashboardBalance).toFixed(2)} AFX
              </p>
            </div>
          </div>

          {/* Amount Input */}
          <div className="space-y-2">
            <Label htmlFor="amount">Amount (AFX)</Label>
            <div className="flex gap-2">
              <Input
                id="amount"
                type="number"
                step="0.01"
                min="0"
                placeholder="0.00"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="flex-1"
              />
              <Button
                variant="outline"
                onClick={() => setAmount((direction === "to_p2p" ? dashboardBalance : p2pBalance).toString())}
              >
                Max
              </Button>
            </div>
            <p className="text-xs text-gray-400">
              Available: {(direction === "to_p2p" ? dashboardBalance : p2pBalance).toFixed(2)} AFX
            </p>
          </div>

          {/* Transfer Button */}
          <Button
            onClick={handleTransfer}
            disabled={loading || !amount || Number(amount) <= 0}
            className="w-full bg-green-600 hover:bg-green-700"
          >
            {loading ? (
              "Processing..."
            ) : (
              <>
                <ArrowRight className="w-4 h-4 mr-2" />
                Transfer {amount || "0.00"} AFX
              </>
            )}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  )
}
