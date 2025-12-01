"use client"

import { useState, useEffect } from "react"
import { requireAdmin } from "@/lib/admin/check-admin"
import { createBrowserClient } from "@/lib/supabase/client"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Textarea } from "@/components/ui/textarea"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { AlertCircle, CheckCircle, XCircle } from 'lucide-react'
import { toast } from "sonner"

interface DisputedTrade {
  id: string
  afx_amount: number
  total_amount: number
  status: string
  dispute_reason: string
  disputed_at: string
  disputed_by_username: string
  buyer_username: string
  seller_username: string
  created_at: string
}

export default function AdminDisputesPage() {
  const [disputes, setDisputes] = useState<DisputedTrade[]>([])
  const [loading, setLoading] = useState(true)
  const [resolveDialog, setResolveDialog] = useState<{ trade: DisputedTrade; action: "buyer" | "seller" } | null>(null)
  const [resolution, setResolution] = useState("")
  
  const supabase = createBrowserClient()

  useEffect(() => {
    fetchDisputes()
  }, [])

  const fetchDisputes = async () => {
    setLoading(true)
    try {
      const { data, error } = await supabase
        .from("p2p_trades")
        .select(`
          *,
          buyer:buyer_id(username),
          seller:seller_id(username),
          disputed_by_user:disputed_by(username)
        `)
        .eq("status", "disputed")
        .order("disputed_at", { ascending: false })

      if (error) throw error

      setDisputes(
        data.map((t: any) => ({
          ...t,
          buyer_username: t.buyer?.username || "Unknown",
          seller_username: t.seller?.username || "Unknown",
          disputed_by_username: t.disputed_by_user?.username || "Unknown",
        }))
      )
    } catch (error: any) {
      toast.error(error.message)
    } finally {
      setLoading(false)
    }
  }

  const handleResolve = async () => {
    if (!resolveDialog || !resolution.trim()) {
      toast.error("Please provide resolution notes")
      return
    }

    try {
      const { data: { user } } = await supabase.auth.getUser()
      
      const { error } = await supabase.rpc("admin_resolve_dispute", {
        p_admin_id: user?.id,
        p_trade_id: resolveDialog.trade.id,
        p_favor_buyer: resolveDialog.action === "buyer",
        p_resolution_notes: resolution
      })

      if (error) throw error

      toast.success("Dispute resolved successfully")
      setResolveDialog(null)
      setResolution("")
      fetchDisputes()
    } catch (error: any) {
      toast.error(error.message)
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-white">Dispute Management</h1>
        <p className="text-gray-400">Resolve disputed P2P trades</p>
      </div>

      <Card className="bg-gray-900/50 border-white/10">
        <CardHeader>
          <CardTitle className="text-white flex items-center gap-2">
            <AlertCircle className="h-5 w-5 text-orange-400" />
            Active Disputes ({disputes.length})
          </CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow className="border-white/10">
                <TableHead className="text-gray-400">Trade ID</TableHead>
                <TableHead className="text-gray-400">Amount</TableHead>
                <TableHead className="text-gray-400">Buyer</TableHead>
                <TableHead className="text-gray-400">Seller</TableHead>
                <TableHead className="text-gray-400">Disputed By</TableHead>
                <TableHead className="text-gray-400">Reason</TableHead>
                <TableHead className="text-gray-400">Date</TableHead>
                <TableHead className="text-gray-400">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {loading ? (
                <TableRow>
                  <TableCell colSpan={8} className="text-center text-gray-400">
                    Loading...
                  </TableCell>
                </TableRow>
              ) : disputes.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={8} className="text-center text-gray-400">
                    No active disputes
                  </TableCell>
                </TableRow>
              ) : (
                disputes.map((dispute) => (
                  <TableRow key={dispute.id} className="border-white/10 hover:bg-white/5">
                    <TableCell className="font-mono text-xs text-gray-300">{dispute.id.slice(0, 8)}...</TableCell>
                    <TableCell className="text-white">{dispute.afx_amount} AFX</TableCell>
                    <TableCell className="text-gray-300">{dispute.buyer_username}</TableCell>
                    <TableCell className="text-gray-300">{dispute.seller_username}</TableCell>
                    <TableCell>
                      <Badge variant="outline" className="border-orange-500/30 text-orange-400">
                        {dispute.disputed_by_username}
                      </Badge>
                    </TableCell>
                    <TableCell className="max-w-xs truncate text-gray-400">{dispute.dispute_reason}</TableCell>
                    <TableCell className="text-gray-400">{new Date(dispute.disputed_at).toLocaleDateString()}</TableCell>
                    <TableCell>
                      <div className="flex gap-2">
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() => setResolveDialog({ trade: dispute, action: "buyer" })}
                          className="bg-green-500/10 border-green-500/30 hover:bg-green-500/20 text-green-400"
                        >
                          <CheckCircle className="h-4 w-4 mr-1" />
                          Favor Buyer
                        </Button>
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() => setResolveDialog({ trade: dispute, action: "seller" })}
                          className="bg-red-500/10 border-red-500/30 hover:bg-red-500/20 text-red-400"
                        >
                          <XCircle className="h-4 w-4 mr-1" />
                          Favor Seller
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      <Dialog open={!!resolveDialog} onOpenChange={() => setResolveDialog(null)}>
        <DialogContent className="bg-gray-900 border-white/10">
          <DialogHeader>
            <DialogTitle className="text-white">
              Resolve Dispute - Favor {resolveDialog?.action === "buyer" ? "Buyer" : "Seller"}
            </DialogTitle>
            <DialogDescription className="text-gray-400">
              {resolveDialog?.action === "buyer"
                ? "Coins will be released to the buyer. This action is irreversible."
                : "Coins will be refunded to the seller. This action is irreversible."}
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
            <div className="p-4 bg-yellow-500/10 border border-yellow-500/30 rounded-lg">
              <p className="text-sm text-yellow-400 font-medium">Dispute Reason:</p>
              <p className="text-sm text-gray-300 mt-1">{resolveDialog?.trade.dispute_reason}</p>
            </div>

            <div className="space-y-2">
              <label className="text-sm text-gray-300">Resolution Notes (Required)</label>
              <Textarea
                placeholder="Explain your decision and reasoning..."
                value={resolution}
                onChange={(e) => setResolution(e.target.value)}
                className="bg-white/5 border-white/10 text-white min-h-[100px]"
              />
            </div>
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={() => setResolveDialog(null)} className="bg-white/5 border-white/10">
              Cancel
            </Button>
            <Button
              onClick={handleResolve}
              className={`${
                resolveDialog?.action === "buyer"
                  ? "bg-gradient-to-r from-green-500 to-emerald-500"
                  : "bg-gradient-to-r from-red-500 to-rose-500"
              }`}
            >
              Confirm Resolution
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
