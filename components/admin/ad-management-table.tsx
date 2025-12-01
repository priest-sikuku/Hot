"use client"

import { useEffect, useState } from "react"
import { createClient } from "@/lib/supabase/client"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Ban, CheckCircle, Search } from "lucide-react"
import { toast } from "sonner"

export function AdManagementTable() {
  const [ads, setAds] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState("")
  const [page, setPage] = useState(1)
  const [total, setTotal] = useState(0)
  const limit = 20

  const supabase = createClient()

  const fetchAds = async () => {
    setLoading(true)
    try {
      let query = supabase
        .from("p2p_ads")
        .select("*, profiles!p2p_ads_user_id_fkey(username, email)", { count: "exact" })
        .order("created_at", { ascending: false })
        .range((page - 1) * limit, page * limit - 1)

      if (search) {
        query = query.or(`ad_type.ilike.%${search}%,status.ilike.%${search}%`)
      }

      const { data, error, count } = await query

      if (error) throw error

      setAds(data || [])
      setTotal(count || 0)
    } catch (error: any) {
      toast.error(error.message)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchAds()
  }, [page, search])

  const toggleAdStatus = async (adId: string, currentStatus: boolean) => {
    try {
      const { error } = await supabase.rpc("admin_toggle_ad_status", {
        p_admin_id: (await supabase.auth.getUser()).data.user?.id,
        p_ad_id: adId,
        p_disabled: !currentStatus,
        p_reason: currentStatus ? "Disabled by admin" : "Enabled by admin",
      })

      if (error) throw error

      toast.success(currentStatus ? "Ad disabled" : "Ad enabled")
      fetchAds()
    } catch (error: any) {
      toast.error(error.message)
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>P2P Advertisements</CardTitle>
        <div className="flex items-center gap-4">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              placeholder="Search ads..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="pl-10"
            />
          </div>
        </div>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>User</TableHead>
              <TableHead>Type</TableHead>
              <TableHead>Amount</TableHead>
              <TableHead>Price</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Created</TableHead>
              <TableHead>Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={7} className="text-center">
                  Loading...
                </TableCell>
              </TableRow>
            ) : ads.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7} className="text-center">
                  No ads found
                </TableCell>
              </TableRow>
            ) : (
              ads.map((ad) => (
                <TableRow key={ad.id}>
                  <TableCell>
                    <div>
                      <div className="font-medium">{ad.profiles?.username}</div>
                      <div className="text-sm text-muted-foreground">{ad.profiles?.email}</div>
                    </div>
                  </TableCell>
                  <TableCell>
                    <Badge variant={ad.ad_type === "buy" ? "default" : "secondary"}>{ad.ad_type}</Badge>
                  </TableCell>
                  <TableCell>{ad.afx_amount} AFX</TableCell>
                  <TableCell>${ad.price_per_afx}</TableCell>
                  <TableCell>
                    <Badge variant={ad.status === "active" ? "default" : "secondary"}>{ad.status}</Badge>
                  </TableCell>
                  <TableCell>{new Date(ad.created_at).toLocaleDateString()}</TableCell>
                  <TableCell>
                    <Button
                      size="sm"
                      variant={ad.disabled ? "default" : "destructive"}
                      onClick={() => toggleAdStatus(ad.id, ad.disabled)}
                    >
                      {ad.disabled ? <CheckCircle className="h-4 w-4" /> : <Ban className="h-4 w-4" />}
                    </Button>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>

        <div className="mt-4 flex items-center justify-between">
          <div className="text-sm text-muted-foreground">
            Showing {(page - 1) * limit + 1} to {Math.min(page * limit, total)} of {total} ads
          </div>
          <div className="flex gap-2">
            <Button variant="outline" size="sm" disabled={page === 1} onClick={() => setPage(page - 1)}>
              Previous
            </Button>
            <Button variant="outline" size="sm" disabled={page * limit >= total} onClick={() => setPage(page + 1)}>
              Next
            </Button>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}
