"use client"

import { useEffect, useState } from "react"
import { createClient } from "@/lib/supabase/client"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Switch } from "@/components/ui/switch"
import { toast } from "sonner"

export function AdminSettingsForm() {
  const [settings, setSettings] = useState<Record<string, any>>({})
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)

  const supabase = createClient()

  const fetchSettings = async () => {
    setLoading(true)
    try {
      const { data, error } = await supabase.from("admin_settings").select("*")

      if (error) throw error

      const settingsMap: Record<string, any> = {}
      data?.forEach((setting) => {
        settingsMap[setting.key] = setting.value
      })
      setSettings(settingsMap)
    } catch (error: any) {
      toast.error(error.message)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchSettings()
  }, [])

  const updateSetting = async (key: string, value: any) => {
    setSaving(true)
    try {
      const { data: user } = await supabase.auth.getUser()

      const { error } = await supabase.rpc("admin_update_setting", {
        p_admin_id: user.user?.id,
        p_key: key,
        p_value: value,
      })

      if (error) throw error

      toast.success("Setting updated")
      fetchSettings()
    } catch (error: any) {
      toast.error(error.message)
    } finally {
      setSaving(false)
    }
  }

  if (loading) {
    return <div>Loading settings...</div>
  }

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Trade Settings</CardTitle>
          <CardDescription>Configure P2P trading parameters</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="trade_auto_expire_minutes">Auto-expire Minutes</Label>
            <Input
              id="trade_auto_expire_minutes"
              type="number"
              value={settings.trade_auto_expire_minutes || 30}
              onChange={(e) => setSettings({ ...settings, trade_auto_expire_minutes: Number.parseInt(e.target.value) })}
              onBlur={(e) => updateSetting("trade_auto_expire_minutes", Number.parseInt(e.target.value))}
            />
            <p className="text-sm text-muted-foreground">Minutes before unpaid trades auto-expire</p>
          </div>

          <div className="space-y-2">
            <Label htmlFor="min_trade_amount">Minimum Trade Amount (AFX)</Label>
            <Input
              id="min_trade_amount"
              type="number"
              value={settings.min_trade_amount || 10}
              onChange={(e) => setSettings({ ...settings, min_trade_amount: Number.parseInt(e.target.value) })}
              onBlur={(e) => updateSetting("min_trade_amount", Number.parseInt(e.target.value))}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="max_trade_amount">Maximum Trade Amount (AFX)</Label>
            <Input
              id="max_trade_amount"
              type="number"
              value={settings.max_trade_amount || 10000}
              onChange={(e) => setSettings({ ...settings, max_trade_amount: Number.parseInt(e.target.value) })}
              onBlur={(e) => updateSetting("max_trade_amount", Number.parseInt(e.target.value))}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="platform_fee_percent">Platform Fee (%)</Label>
            <Input
              id="platform_fee_percent"
              type="number"
              step="0.1"
              value={settings.platform_fee_percent || 0}
              onChange={(e) => setSettings({ ...settings, platform_fee_percent: Number.parseFloat(e.target.value) })}
              onBlur={(e) => updateSetting("platform_fee_percent", Number.parseFloat(e.target.value))}
            />
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>System Settings</CardTitle>
          <CardDescription>Platform-wide configuration</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center justify-between">
            <div className="space-y-0.5">
              <Label htmlFor="maintenance_mode">Maintenance Mode</Label>
              <p className="text-sm text-muted-foreground">Disable platform access for maintenance</p>
            </div>
            <Switch
              id="maintenance_mode"
              checked={settings.maintenance_mode === "true" || settings.maintenance_mode === true}
              onCheckedChange={(checked) => updateSetting("maintenance_mode", checked)}
              disabled={saving}
            />
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
