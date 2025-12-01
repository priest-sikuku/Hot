"use client"

import { useState, useEffect } from "react"
import { createBrowserClient } from "@/lib/supabase/client"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { toast } from "sonner"

interface AuditLog {
  id: string
  action: string
  target_table: string
  created_at: string
  admin_username: string
  details: any
}

export function AuditLogsTable() {
  const [logs, setLogs] = useState<AuditLog[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchLogs()
  }, [])

  const fetchLogs = async () => {
    setLoading(true)
    const supabase = createBrowserClient()

    const { data, error } = await supabase
      .from("admin_audit_logs")
      .select(`
        *,
        admin:admin_id(username)
      `)
      .order("created_at", { ascending: false })
      .limit(100)

    if (error) {
      toast.error("Failed to fetch logs")
    } else {
      setLogs(
        data.map((log: any) => ({
          ...log,
          admin_username: log.admin?.username || "Unknown",
        })),
      )
    }

    setLoading(false)
  }

  return (
    <div className="rounded-md border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Timestamp</TableHead>
            <TableHead>Admin</TableHead>
            <TableHead>Action</TableHead>
            <TableHead>Target</TableHead>
            <TableHead>Details</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {loading ? (
            <TableRow>
              <TableCell colSpan={5} className="text-center">
                Loading...
              </TableCell>
            </TableRow>
          ) : logs.length === 0 ? (
            <TableRow>
              <TableCell colSpan={5} className="text-center">
                No logs found
              </TableCell>
            </TableRow>
          ) : (
            logs.map((log) => (
              <TableRow key={log.id}>
                <TableCell>{new Date(log.created_at).toLocaleString()}</TableCell>
                <TableCell>{log.admin_username}</TableCell>
                <TableCell>
                  <Badge>{log.action}</Badge>
                </TableCell>
                <TableCell>{log.target_table || "-"}</TableCell>
                <TableCell className="max-w-xs truncate">{JSON.stringify(log.details)}</TableCell>
              </TableRow>
            ))
          )}
        </TableBody>
      </Table>
    </div>
  )
}
