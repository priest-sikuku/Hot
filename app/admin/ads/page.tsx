import { requireAdmin } from "@/lib/admin/check-admin"
import { AdManagementTable } from "@/components/admin/ad-management-table"

export default async function AdminAdsPage() {
  await requireAdmin()

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold">P2P Ad Management</h1>
        <p className="text-muted-foreground">Monitor and manage P2P advertisements</p>
      </div>

      <AdManagementTable />
    </div>
  )
}
