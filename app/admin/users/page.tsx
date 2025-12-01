import { requireAdmin } from "@/lib/admin/check-admin"
import { UserManagementTable } from "@/components/admin/user-management-table"

export default async function AdminUsersPage() {
  await requireAdmin()

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold">User Management</h1>
        <p className="text-muted-foreground">Manage user accounts and permissions</p>
      </div>

      <UserManagementTable />
    </div>
  )
}
