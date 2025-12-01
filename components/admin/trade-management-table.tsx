"use client"

import { useState, useEffect } from "react"
import { createBrowserClient } from "@/lib/supabase/client"
import { Button } from "@/components/ui/button"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Badge } from "@/components/ui/badge"
import { Textarea } from "@/components/ui/textarea"
import { CheckCircle, XCircle } from "lucide-react"
import { toast } from "sonner"

interface Trade {
  id: string
  afx_amount: number
  status: string
  created_at: string
  buyer_username: string
  seller_username: string
  is_paid: boolean
}

export function TradeManagementTable() {
  const [trades, setTrades] = useState<Trade[]>([])
  const [loading, setLoading] = useState(true)
  const [actionTrade, setActionTrade] = useState<{ trade: Trade; action: "complete" | "refund" } | null>(null)
  const [reason, setReason] = useState("")

  useEffect(() => {
    fetchTrades()
  }, [])

  const fetchTrades = async () => {
    setLoading(true)
    const supabase = createBrowserClient()

    const { data, error } = await supabase
      .from("p2p_trades")
      .select(`
        *,
        buyer:buyer_id(username),
        seller:seller_id(username)
      `)
      .order("created_at", { ascending: false })
      .limit(50)

    if (error) {
      toast.error("Failed to fetch trades")
    } else {
      setTrades(
        data.map((t: any) => ({
          ...t,
          buyer_username: t.buyer?.username || "Unknown",
          seller_username: t.seller?.username || "Unknown",
        })),
      )
    }

    setLoading(false)
  }

  const handleAction = async () => {
    if (!actionTrade || !reason.trim()) {
      toast.error("Please provide a reason")
      return
    }

    const endpoint = actionTrade.action === "complete" ? "force-complete" : "force-refund"

    try {
      const res = await fetch(`/api/admin/trades/${actionTrade.trade.id}/${endpoint}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ reason }),
      })

      const data = await res.json()

      if (res.ok) {
        toast.success(`Trade ${actionTrade.action}d successfully`)
        setActionTrade(null)
        setReason("")
        fetchTrades()
      } else {
        toast.error(data.error)
      }
    } catch (error) {
      toast.error("Failed to perform action")
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case "completed":
        return "default"
      case "pending":
        return "secondary"
      case "cancelled":
        return "destructive"
      case "expired":
        return "outline"
      default:
        return "secondary"
    }
  }

  return (
    <div className="space-y-4">
      <div className="rounded-md border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Trade ID</TableHead>
              <TableHead>Buyer</TableHead>
              <TableHead>Seller</TableHead>
              <TableHead>Amount</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Paid</TableHead>
              <TableHead>Date</TableHead>
              <TableHead>Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={8} className="text-center">
                  Loading...
                </TableCell>
              </TableRow>
            ) : trades.length === 0 ? (
              <TableRow>
                <TableCell colSpan={8} className="text-center">
                  No trades found
                </TableCell>
              </TableRow>
            ) : (
              trades.map((trade) => (
                <TableRow key={trade.id}>
                  <TableCell className="font-mono text-xs">{trade.id.slice(0, 8)}...</TableCell>
                  <TableCell>{trade.buyer_username}</TableCell>
                  <TableCell>{trade.seller_username}</TableCell>
                  <TableCell>{trade.afx_amount} AFX</TableCell>
                  <TableCell>
                    <Badge variant={getStatusColor(trade.status)}>{trade.status}</Badge>
                  </TableCell>
                  <TableCell>
                    <Badge variant={trade.is_paid ? "default" : "secondary"}>{trade.is_paid ? "Yes" : "No"}</Badge>
                  </TableCell>
                  <TableCell>{new Date(trade.created_at).toLocaleDateString()}</TableCell>
                  <TableCell>
                    {trade.status === "pending" && (
                      <div className="flex gap-2">
                        <Button size="sm" variant="ghost" onClick={() => setActionTrade({ trade, action: "complete" })}>
                          <CheckCircle className="h-4 w-4" />
                        </Button>
                        <Button size="sm" variant="ghost" onClick={() => setActionTrade({ trade, action: "refund" })}>
                          <XCircle className="h-4 w-4" />
                        </Button>
                      </div>
                    )}
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      <Dialog open={!!actionTrade} onOpenChange={() => setActionTrade(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {actionTrade?.action === "complete" ? "Force Complete Trade" : "Force Refund Trade"}
            </DialogTitle>
            <DialogDescription>
              This action will {actionTrade?.action === "complete" ? "complete" : "refund"} the trade and log the
              action. Please provide a reason.
            </DialogDescription>
          </DialogHeader>

          <Textarea
            placeholder="Reason for this action..."
            value={reason}
            onChange={(e) => setReason(e.target.value)}
          />

          <DialogFooter>
            <Button variant="outline" onClick={() => setActionTrade(null)}>
              Cancel
            </Button>
            <Button onClick={handleAction}>Confirm {actionTrade?.action === "complete" ? "Complete" : "Refund"}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
