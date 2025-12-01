import { requireAdmin } from "@/lib/admin/check-admin"
import { TradeManagementTable } from "@/components/admin/trade-management-table"

export default async function AdminTradesPage() {
  await requireAdmin()

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Trade Management</h1>
        <p className="text-muted-foreground">Monitor and manage P2P trades</p>
      </div>

      <TradeManagementTable />
    </div>
  )
}
