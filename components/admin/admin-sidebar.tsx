"use client"

import { useState } from "react"
import Link from "next/link"
import { usePathname } from 'next/navigation'
import { cn } from "@/lib/utils"
import { LayoutDashboard, Users, ShoppingBag, TrendingUp, FileText, Settings, ArrowLeft, Shield, ChevronLeft, ChevronRight, AlertCircle, Coins } from 'lucide-react'
import { Button } from "@/components/ui/button"

const navItems = [
  { href: "/admin", label: "Dashboard", icon: LayoutDashboard },
  { href: "/admin/users", label: "Users", icon: Users },
  { href: "/admin/ads", label: "P2P Ads", icon: ShoppingBag },
  { href: "/admin/trades", label: "Trades", icon: TrendingUp },
  { href: "/admin/disputes", label: "Disputes", icon: AlertCircle },
  { href: "/admin/supply", label: "Supply", icon: Coins },
  { href: "/admin/logs", label: "Audit Logs", icon: FileText },
  { href: "/admin/settings", label: "Settings", icon: Settings },
]

export function AdminSidebar() {
  const pathname = usePathname()
  const [isCollapsed, setIsCollapsed] = useState(() => {
    if (typeof window !== "undefined") {
      const saved = localStorage.getItem("admin-sidebar-collapsed")
      return saved === "true"
    }
    return false
  })

  const toggleSidebar = () => {
    const newState = !isCollapsed
    setIsCollapsed(newState)
    if (typeof window !== "undefined") {
      localStorage.setItem("admin-sidebar-collapsed", String(newState))
    }
  }

  return (
    <aside
      className={cn(
        "border-r border-white/10 backdrop-blur-xl bg-black/30 transition-all duration-300 ease-in-out",
        isCollapsed ? "w-20" : "w-64",
      )}
    >
      <div className="flex h-full flex-col">
        <div className="border-b border-white/10 p-6 relative">
          <div
            className={cn("flex items-center gap-3 mb-2 transition-opacity duration-200", isCollapsed && "opacity-0")}
          >
            <div className="p-2 bg-gradient-to-br from-orange-500 to-red-500 rounded-lg">
              <Shield className="w-5 h-5 text-white" />
            </div>
            {!isCollapsed && (
              <h2 className="text-lg font-bold bg-gradient-to-r from-orange-400 to-red-400 bg-clip-text text-transparent">
                AFX Admin
              </h2>
            )}
          </div>
          {!isCollapsed && <p className="text-sm text-gray-400">Control Panel</p>}

          <Button
            variant="ghost"
            size="icon"
            onClick={toggleSidebar}
            className={cn(
              "absolute -right-3 top-6 h-6 w-6 rounded-full border border-white/10 bg-gray-900 hover:bg-gray-800",
              "flex items-center justify-center shadow-lg",
            )}
          >
            {isCollapsed ? (
              <ChevronRight className="h-3 w-3 text-gray-400" />
            ) : (
              <ChevronLeft className="h-3 w-3 text-gray-400" />
            )}
          </Button>
        </div>

        <nav className="flex-1 space-y-1 p-4">
          {navItems.map((item) => {
            const Icon = item.icon
            const isActive = pathname === item.href

            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  "flex items-center gap-3 rounded-xl px-4 py-3 text-sm font-medium transition-all duration-200",
                  isActive
                    ? "bg-gradient-to-r from-orange-500/20 to-red-500/20 text-white border border-orange-500/30"
                    : "text-gray-400 hover:bg-white/5 hover:text-white",
                  isCollapsed && "justify-center px-0",
                )}
                title={isCollapsed ? item.label : undefined}
              >
                <Icon className="h-5 w-5 flex-shrink-0" />
                {!isCollapsed && <span>{item.label}</span>}
              </Link>
            )
          })}
        </nav>

        <div className="border-t border-white/10 p-4">
          <Link
            href="/dashboard"
            className={cn(
              "flex items-center gap-3 rounded-xl px-4 py-3 text-sm font-medium text-gray-400 transition-all duration-200 hover:bg-white/5 hover:text-white",
              isCollapsed && "justify-center px-0",
            )}
            title={isCollapsed ? "Back to Dashboard" : undefined}
          >
            <ArrowLeft className="h-5 w-5 flex-shrink-0" />
            {!isCollapsed && <span>Back to Dashboard</span>}
          </Link>
        </div>
      </div>
    </aside>
  )
}
