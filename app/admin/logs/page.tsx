import { requireAdmin } from "@/lib/admin/check-admin"
import { AuditLogsTable } from "@/components/admin/audit-logs-table"

export default async function AdminLogsPage() {
  await requireAdmin()

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Audit Logs</h1>
        <p className="text-muted-foreground">View all admin actions and system events</p>
      </div>

      <AuditLogsTable />
    </div>
  )
}
