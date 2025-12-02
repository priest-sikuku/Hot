"use client"

import { useState, useEffect } from "react"
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { ArrowRight, AlertCircle, CheckCircle } from "lucide-react"
import { createClient } from "@/lib/supabase/client"
import { useToast } from "@/hooks/use-toast"

interface UserTransferModalProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  currentUserBalance: number
  onTransferComplete: () => void
}

export function UserTransferModal({
  open,
  onOpenChange,
  currentUserBalance,
  onTransferComplete,
}: UserTransferModalProps) {
  const [recipientUsername, setRecipientUsername] = useState("")
  const [amount, setAmount] = useState("")
  const [loading, setLoading] = useState(false)
  const [checkingEligibility, setCheckingEligibility] = useState(false)
  const [isEligible, setIsEligible] = useState(false)
  const [tradesCount, setTradesCount] = useState(0)
  const [debugInfo, setDebugInfo] = useState("")
  const { toast } = useToast()
  const supabase = createClient()

  useEffect(() => {
    if (!open) return

    const checkEligibility = async () => {
      try {
        setCheckingEligibility(true)
        const {
          data: { user },
        } = await supabase.auth.getUser()
        if (!user) {
          setDebugInfo("User not authenticated")
          return
        }

        console.log("[v0] Calling get_completed_p2p_trades_count for user:", user.id)

        const { data: trades, error: tradesError } = await supabase
          .from("p2p_trades")
          .select("id, status, coins_released_at")
          .or(`buyer_id.eq.${user.id},seller_id.eq.${user.id}`)
          .eq("status", "completed")

        console.log("[v0] Direct query result:", { trades, tradesError })

        // Use RPC function for official count
        const { data, error } = await supabase.rpc("get_completed_p2p_trades_count", {
          p_user_id: user.id,
        })

        console.log("[v0] RPC Result:", { data, error })
        setDebugInfo(`RPC: ${data || 0}/5 | Direct Query: ${trades?.length || 0} completed trades`)

        setTradesCount(data || 0)
        setIsEligible((data || 0) >= 5)
      } catch (error: any) {
        console.error("[v0] Error checking eligibility:", error)
        setDebugInfo(`Error: ${error.message}`)
        setIsEligible(false)
      } finally {
        setCheckingEligibility(false)
      }
    }

    checkEligibility()
  }, [open, supabase])

  const handleTransfer = async () => {
    if (!recipientUsername?.trim()) {
      toast({
        title: "Invalid Recipient",
        description: "Please enter a recipient username",
        variant: "destructive",
      })
      return
    }

    if (!amount || Number(amount) <= 0) {
      toast({
        title: "Invalid Amount",
        description: "Please enter a valid amount greater than 0",
        variant: "destructive",
      })
      return
    }

    if (Number(amount) < 10) {
      toast({
        title: "Minimum Transfer",
        description: "Minimum transfer amount is 10 AFX",
        variant: "destructive",
      })
      return
    }

    if (Number(amount) > currentUserBalance) {
      toast({
        title: "Insufficient Balance",
        description: `You don't have enough balance. Available: ${currentUserBalance.toFixed(2)} AFX`,
        variant: "destructive",
      })
      return
    }

    setLoading(true)

    try {
      const {
        data: { user },
      } = await supabase.auth.getUser()
      if (!user) throw new Error("Not authenticated")

      // Find recipient by username
      const { data: recipientData, error: recipientError } = await supabase
        .from("profiles")
        .select("id, wallet_address")
        .eq("username", recipientUsername.toLowerCase())
        .single()

      if (recipientError || !recipientData) {
        toast({
          title: "User Not Found",
          description: `No user found with username "${recipientUsername}"`,
          variant: "destructive",
        })
        setLoading(false)
        return
      }

      // Call the transfer function
      const { data, error } = await supabase.rpc("transfer_balance_to_user", {
        p_sender_id: user.id,
        p_receiver_id: recipientData.id,
        p_amount: Number(amount),
      })

      if (error) {
        console.error("[v0] Transfer error:", error)
        throw new Error(error.message)
      }

      if (data?.success === false) {
        throw new Error(data.error || "Transfer failed")
      }

      toast({
        title: "Transfer Successful",
        description: `${Number(amount).toFixed(2)} AFX transferred to ${recipientUsername}`,
      })

      setRecipientUsername("")
      setAmount("")
      onTransferComplete()
      onOpenChange(false)
    } catch (error: any) {
      console.error("[v0] Transfer error:", error)
      toast({
        title: "Transfer Failed",
        description: error.message || "Failed to transfer funds",
        variant: "destructive",
      })
    } finally {
      setLoading(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md bg-gray-900 border-gray-800">
        <DialogHeader>
          <DialogTitle className="text-xl font-bold">Transfer Balance to User</DialogTitle>
        </DialogHeader>

        <div className="space-y-6 py-4">
          {/* Eligibility Check */}
          <div
            className={`flex gap-3 p-4 rounded-lg border ${
              isEligible ? "bg-green-500/10 border-green-500/30" : "bg-yellow-500/10 border-yellow-500/30"
            }`}
          >
            {isEligible ? (
              <CheckCircle className="w-5 h-5 text-green-500 flex-shrink-0 mt-0.5" />
            ) : (
              <AlertCircle className="w-5 h-5 text-yellow-500 flex-shrink-0 mt-0.5" />
            )}
            <div className="text-sm">
              <p className={`font-semibold ${isEligible ? "text-green-200" : "text-yellow-200"} mb-1`}>
                {isEligible ? "Eligible for Transfer" : "Trading Requirement"}
              </p>
              <p className={isEligible ? "text-green-100/80" : "text-yellow-100/80"}>
                {isEligible
                  ? `You have completed ${tradesCount} P2P trades`
                  : `You need to complete at least 5 P2P trades before transferring. (${tradesCount}/5 completed)`}
              </p>
            </div>
          </div>

          {debugInfo && (
            <div className="text-xs text-gray-500 bg-gray-800/50 p-2 rounded border border-gray-700">
              Debug: {debugInfo}
            </div>
          )}

          {/* Recipient Input */}
          <div className="space-y-2">
            <Label htmlFor="recipient">Recipient Username</Label>
            <Input
              id="recipient"
              placeholder="Enter username"
              value={recipientUsername}
              onChange={(e) => setRecipientUsername(e.target.value)}
              disabled={!isEligible || loading || checkingEligibility}
              className="bg-gray-800 border-gray-700"
            />
          </div>

          {/* Amount Input */}
          <div className="space-y-2">
            <Label htmlFor="amount">Amount (AFX)</Label>
            <div className="flex gap-2">
              <Input
                id="amount"
                type="number"
                step="0.01"
                min="10"
                placeholder="Minimum 10 AFX"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                disabled={!isEligible || loading || checkingEligibility}
                className="flex-1 bg-gray-800 border-gray-700"
              />
              <Button
                variant="outline"
                onClick={() => setAmount(currentUserBalance.toString())}
                disabled={!isEligible || loading || checkingEligibility}
              >
                Max
              </Button>
            </div>
            <p className="text-xs text-gray-400">Available: {currentUserBalance.toFixed(2)} AFX • Min: 10 AFX</p>
          </div>

          {/* Transfer Button */}
          <Button
            onClick={handleTransfer}
            disabled={
              loading ||
              checkingEligibility ||
              !isEligible ||
              !recipientUsername.trim() ||
              !amount ||
              Number(amount) < 10
            }
            className="w-full bg-green-600 hover:bg-green-700 disabled:bg-gray-700"
          >
            {checkingEligibility ? (
              "Checking eligibility..."
            ) : loading ? (
              "Processing..."
            ) : !isEligible ? (
              "Complete 5 trades to unlock"
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
