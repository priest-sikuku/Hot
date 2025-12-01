"use client"

import { useState, useEffect } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Label } from "@/components/ui/label"
import { Switch } from "@/components/ui/switch"
import { Textarea } from "@/components/ui/textarea"
import { Badge } from "@/components/ui/badge"
import { Search, Edit, Ban, CheckCircle, Wallet } from "lucide-react"
import { toast } from "sonner"

interface User {
  id: string
  username: string
  email: string
  is_admin: boolean
  role: string
  disabled: boolean
  created_at: string
  admin_note?: string
}

interface UserBalances {
  dashboard_balance: number
  p2p_balance: number
}

export function UserManagementTable() {
  const [users, setUsers] = useState<User[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState("")
  const [page, setPage] = useState(1)
  const [total, setTotal] = useState(0)
  const [editUser, setEditUser] = useState<User | null>(null)
  const [editForm, setEditForm] = useState({ is_admin: false, role: "user", admin_note: "" })
  const [balanceUser, setBalanceUser] = useState<User | null>(null)
  const [balances, setBalances] = useState<UserBalances>({ dashboard_balance: 0, p2p_balance: 0 })
  const [balanceForm, setBalanceForm] = useState({ dashboard_balance: 0, p2p_balance: 0, reason: "" })

  useEffect(() => {
    fetchUsers()
  }, [page, search])

  const fetchUsers = async () => {
    setLoading(true)
    try {
      const params = new URLSearchParams({
        page: page.toString(),
        limit: "20",
        search,
      })

      const res = await fetch(`/api/admin/users?${params}`)
      const data = await res.json()

      if (res.ok) {
        setUsers(data.users)
        setTotal(data.total)
      } else {
        toast.error(data.error)
      }
    } catch (error) {
      toast.error("Failed to fetch users")
    } finally {
      setLoading(false)
    }
  }

  const handleEdit = (user: User) => {
    setEditUser(user)
    setEditForm({
      is_admin: user.is_admin,
      role: user.role,
      admin_note: user.admin_note || "",
    })
  }

  const handleSaveEdit = async () => {
    if (!editUser) return

    try {
      const res = await fetch("/api/admin/users", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          userId: editUser.id,
          updates: editForm,
        }),
      })

      const data = await res.json()

      if (res.ok) {
        toast.success("User updated successfully")
        setEditUser(null)
        fetchUsers()
      } else {
        toast.error(data.error)
      }
    } catch (error) {
      toast.error("Failed to update user")
    }
  }

  const handleEditBalance = async (user: User) => {
    setBalanceUser(user)

    try {
      const res = await fetch(`/api/admin/users/${user.id}/balances`)
      const data = await res.json()

      if (res.ok) {
        setBalances(data)
        setBalanceForm({
          dashboard_balance: data.dashboard_balance,
          p2p_balance: data.p2p_balance,
          reason: "",
        })
      } else {
        toast.error("Failed to load balances")
      }
    } catch (error) {
      console.error("[v0] Error fetching balances:", error)
      toast.error("Failed to load balances")
    }
  }

  const handleSaveBalance = async () => {
    if (!balanceUser || !balanceForm.reason.trim()) {
      toast.error("Please provide a reason for the balance change")
      return
    }

    try {
      const res = await fetch(`/api/admin/users/${balanceUser.id}/balances`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(balanceForm),
      })

      const data = await res.json()

      if (res.ok) {
        toast.success("Balances updated successfully")
        setBalanceUser(null)
        fetchUsers() // Refresh user list
      } else {
        toast.error(data.error)
      }
    } catch (error) {
      console.error("[v0] Error updating balances:", error)
      toast.error("Failed to update balances")
    }
  }

  const handleToggleStatus = async (user: User) => {
    const action = user.disabled ? "enable" : "disable"
    const reason = prompt(`Reason to ${action} this user:`)

    if (!reason) return

    try {
      const res = await fetch(`/api/admin/users/${user.id}/toggle-status`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          disabled: !user.disabled,
          reason,
        }),
      })

      const data = await res.json()

      if (res.ok) {
        toast.success(`User ${action}d successfully`)
        fetchUsers()
      } else {
        toast.error(data.error)
      }
    } catch (error) {
      toast.error(`Failed to ${action} user`)
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-4">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
          <Input
            placeholder="Search users by username or email..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-10 bg-white/5 border-white/10 text-white placeholder:text-gray-500"
          />
        </div>
      </div>

      <div className="rounded-2xl border border-white/10 overflow-hidden glass-card">
        <Table>
          <TableHeader>
            <TableRow className="border-white/10 hover:bg-white/5">
              <TableHead className="text-gray-400">Username</TableHead>
              <TableHead className="text-gray-400">Email</TableHead>
              <TableHead className="text-gray-400">Role</TableHead>
              <TableHead className="text-gray-400">Status</TableHead>
              <TableHead className="text-gray-400">Joined</TableHead>
              <TableHead className="text-gray-400">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={6} className="text-center text-gray-400">
                  Loading...
                </TableCell>
              </TableRow>
            ) : users.length === 0 ? (
              <TableRow>
                <TableCell colSpan={6} className="text-center text-gray-400">
                  No users found
                </TableCell>
              </TableRow>
            ) : (
              users.map((user) => (
                <TableRow key={user.id} className="border-white/10 hover:bg-white/5">
                  <TableCell className="font-medium text-white">{user.username}</TableCell>
                  <TableCell className="text-gray-300">{user.email}</TableCell>
                  <TableCell>
                    <Badge
                      variant={user.is_admin ? "default" : "secondary"}
                      className={user.is_admin ? "bg-orange-500/20 text-orange-400 border-orange-500/30" : ""}
                    >
                      {user.is_admin ? "Admin" : user.role}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <Badge
                      variant={user.disabled ? "destructive" : "default"}
                      className={
                        user.disabled
                          ? "bg-red-500/20 text-red-400 border-red-500/30"
                          : "bg-green-500/20 text-green-400 border-green-500/30"
                      }
                    >
                      {user.disabled ? "Disabled" : "Active"}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-gray-300">{new Date(user.created_at).toLocaleDateString()}</TableCell>
                  <TableCell>
                    <div className="flex items-center gap-2">
                      <Button size="sm" variant="ghost" onClick={() => handleEdit(user)} className="hover:bg-white/10">
                        <Edit className="h-4 w-4" />
                      </Button>
                      <Button
                        size="sm"
                        variant="ghost"
                        onClick={() => handleEditBalance(user)}
                        className="hover:bg-white/10"
                      >
                        <Wallet className="h-4 w-4" />
                      </Button>
                      <Button
                        size="sm"
                        variant="ghost"
                        onClick={() => handleToggleStatus(user)}
                        className="hover:bg-white/10"
                      >
                        {user.disabled ? <CheckCircle className="h-4 w-4" /> : <Ban className="h-4 w-4" />}
                      </Button>
                    </div>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      <div className="flex items-center justify-between">
        <p className="text-sm text-gray-400">
          Showing {users.length} of {total} users
        </p>
        <div className="flex gap-2">
          <Button
            variant="outline"
            size="sm"
            disabled={page === 1}
            onClick={() => setPage(page - 1)}
            className="bg-white/5 border-white/10 hover:bg-white/10"
          >
            Previous
          </Button>
          <Button
            variant="outline"
            size="sm"
            disabled={page * 20 >= total}
            onClick={() => setPage(page + 1)}
            className="bg-white/5 border-white/10 hover:bg-white/10"
          >
            Next
          </Button>
        </div>
      </div>

      <Dialog open={!!editUser} onOpenChange={() => setEditUser(null)}>
        <DialogContent className="bg-gray-900 border-white/10">
          <DialogHeader>
            <DialogTitle className="text-white">Edit User</DialogTitle>
            <DialogDescription className="text-gray-400">Update user permissions and role</DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <Label htmlFor="is_admin" className="text-gray-300">
                Admin Access
              </Label>
              <Switch
                id="is_admin"
                checked={editForm.is_admin}
                onCheckedChange={(checked) => setEditForm({ ...editForm, is_admin: checked })}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="role" className="text-gray-300">
                Role
              </Label>
              <Input
                id="role"
                value={editForm.role}
                onChange={(e) => setEditForm({ ...editForm, role: e.target.value })}
                className="bg-white/5 border-white/10 text-white"
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="admin_note" className="text-gray-300">
                Admin Note
              </Label>
              <Textarea
                id="admin_note"
                value={editForm.admin_note}
                onChange={(e) => setEditForm({ ...editForm, admin_note: e.target.value })}
                placeholder="Internal notes about this user..."
                className="bg-white/5 border-white/10 text-white placeholder:text-gray-500"
              />
            </div>
          </div>

          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setEditUser(null)}
              className="bg-white/5 border-white/10 hover:bg-white/10"
            >
              Cancel
            </Button>
            <Button
              onClick={handleSaveEdit}
              className="bg-gradient-to-r from-orange-500 to-red-500 hover:from-orange-600 hover:to-red-600"
            >
              Save Changes
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={!!balanceUser} onOpenChange={() => setBalanceUser(null)}>
        <DialogContent className="bg-gray-900 border-white/10 sm:max-w-[500px]">
          <DialogHeader>
            <DialogTitle className="text-white">Edit User Balances</DialogTitle>
            <DialogDescription className="text-gray-400">
              Update {balanceUser?.username}'s AFX balances (fetched in real-time)
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="dashboard_balance" className="text-gray-300">
                Dashboard Balance (AFX)
              </Label>
              <Input
                id="dashboard_balance"
                type="number"
                step="0.01"
                min="0"
                value={balanceForm.dashboard_balance}
                onChange={(e) =>
                  setBalanceForm({ ...balanceForm, dashboard_balance: Number.parseFloat(e.target.value) || 0 })
                }
                className="bg-white/5 border-white/10 text-white"
              />
              <p className="text-xs text-gray-500">Current: {balances.dashboard_balance.toFixed(2)} AFX</p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="p2p_balance" className="text-gray-300">
                P2P Balance (AFX)
              </Label>
              <Input
                id="p2p_balance"
                type="number"
                step="0.01"
                min="0"
                value={balanceForm.p2p_balance}
                onChange={(e) =>
                  setBalanceForm({ ...balanceForm, p2p_balance: Number.parseFloat(e.target.value) || 0 })
                }
                className="bg-white/5 border-white/10 text-white"
              />
              <p className="text-xs text-gray-500">Current: {balances.p2p_balance.toFixed(2)} AFX</p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="reason" className="text-gray-300 flex items-center gap-1">
                Reason for Change <span className="text-red-400">*</span>
              </Label>
              <Textarea
                id="reason"
                value={balanceForm.reason}
                onChange={(e) => setBalanceForm({ ...balanceForm, reason: e.target.value })}
                placeholder="Required: Explain why you're adjusting the balance (e.g., 'Refund for system error', 'Promotional bonus')..."
                className="bg-white/5 border-white/10 text-white placeholder:text-gray-500"
                rows={3}
                required
              />
            </div>
          </div>

          <DialogFooter className="flex-col sm:flex-row gap-2">
            <Button
              variant="outline"
              onClick={() => setBalanceUser(null)}
              className="bg-white/5 border-white/10 hover:bg-white/10 w-full sm:w-auto"
            >
              Cancel
            </Button>
            <Button
              onClick={handleSaveBalance}
              disabled={!balanceForm.reason.trim()}
              className="bg-gradient-to-r from-orange-500 to-red-500 hover:from-orange-600 hover:to-red-600 w-full sm:w-auto"
            >
              Save Balances
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
