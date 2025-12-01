"use client"

import { useState, useEffect } from "react"
import { createBrowserClient } from "@/lib/supabase/client"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Coins, TrendingDown, TrendingUp, Save } from 'lucide-react'
import { toast } from "sonner"

export default function AdminSupplyPage() {
  const [supply, setSupply] = useState({ total_supply: 0, mined_supply: 0, remaining_supply: 0 })
  const [loading, setLoading] = useState(true)
  const [editing, setEditing] = useState(false)
  const [editForm, setEditForm] = useState({ total_supply: 0 })

  const supabase = createBrowserClient()

  useEffect(() => {
    fetchSupply()
  }, [])

  const fetchSupply = async () => {
    setLoading(true)
    try {
      const { data, error } = await supabase.from("global_supply").select("*").single()

      if (error) throw error

      setSupply(data)
      setEditForm({ total_supply: data.total_supply })
    } catch (error: any) {
      toast.error(error.message)
    } finally {
      setLoading(false)
    }
  }

  const handleSave = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser()

      const { error } = await supabase
        .from("global_supply")
        .update({
          total_supply: editForm.total_supply,
          remaining_supply: editForm.total_supply - supply.mined_supply,
          updated_at: new Date().toISOString()
        })
        .eq("id", 1)

      if (error) throw error

      toast.success("Supply updated successfully")
      setEditing(false)
      fetchSupply()
    } catch (error: any) {
      toast.error(error.message)
    }
  }

  if (loading) {
    return <div className="text-gray-400">Loading...</div>
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-white">Global Supply Management</h1>
        <p className="text-gray-400">Monitor and adjust AFX total supply</p>
      </div>

      <div className="grid gap-6 md:grid-cols-3">
        <Card className="bg-gradient-to-br from-blue-500/10 to-cyan-500/10 border-blue-500/30">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-blue-400">Total Supply</CardTitle>
            <Coins className="h-4 w-4 text-blue-400" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-white">{supply.total_supply.toLocaleString()} AFX</div>
            <p className="text-xs text-gray-400 mt-1">Maximum supply cap</p>
          </CardContent>
        </Card>

        <Card className="bg-gradient-to-br from-green-500/10 to-emerald-500/10 border-green-500/30">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-green-400">Mined Supply</CardTitle>
            <TrendingUp className="h-4 w-4 text-green-400" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-white">{supply.mined_supply.toLocaleString()} AFX</div>
            <p className="text-xs text-gray-400 mt-1">
              {((supply.mined_supply / supply.total_supply) * 100).toFixed(2)}% mined
            </p>
          </CardContent>
        </Card>

        <Card className="bg-gradient-to-br from-orange-500/10 to-yellow-500/10 border-orange-500/30">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-orange-400">Remaining Supply</CardTitle>
            <TrendingDown className="h-4 w-4 text-orange-400" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-white">{supply.remaining_supply.toLocaleString()} AFX</div>
            <p className="text-xs text-gray-400 mt-1">Available for mining</p>
          </CardContent>
        </Card>
      </div>

      <Card className="bg-gray-900/50 border-white/10">
        <CardHeader>
          <CardTitle className="text-white">Edit Total Supply</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="total_supply" className="text-gray-300">
              Total Supply (AFX)
            </Label>
            <Input
              id="total_supply"
              type="number"
              value={editForm.total_supply}
              onChange={(e) => setEditForm({ total_supply: Number.parseFloat(e.target.value) })}
              disabled={!editing}
              className="bg-white/5 border-white/10 text-white disabled:opacity-50"
            />
            <p className="text-xs text-gray-500">
              Warning: Changing total supply affects remaining supply calculation
            </p>
          </div>

          <div className="flex gap-2">
            {!editing ? (
              <Button
                onClick={() => setEditing(true)}
                className="bg-gradient-to-r from-orange-500 to-red-500"
              >
                <Save className="h-4 w-4 mr-2" />
                Edit Supply
              </Button>
            ) : (
              <>
                <Button
                  onClick={handleSave}
                  className="bg-gradient-to-r from-green-500 to-emerald-500"
                >
                  <Save className="h-4 w-4 mr-2" />
                  Save Changes
                </Button>
                <Button
                  variant="outline"
                  onClick={() => {
                    setEditing(false)
                    setEditForm({ total_supply: supply.total_supply })
                  }}
                  className="bg-white/5 border-white/10"
                >
                  Cancel
                </Button>
              </>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
