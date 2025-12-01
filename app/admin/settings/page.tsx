import { requireAdmin } from "@/lib/admin/check-admin"
import { AdminSettingsForm } from "@/components/admin/admin-settings-form"

export default async function AdminSettingsPage() {
  await requireAdmin()

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold">System Settings</h1>
        <p className="text-muted-foreground">Configure platform-wide settings</p>
      </div>

      <AdminSettingsForm />
    </div>
  )
}
