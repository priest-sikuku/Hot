import { requireAdmin } from "@/lib/admin/check-admin"
import { createClient } from "@/lib/supabase/server"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Users, ShoppingBag, TrendingUp, Activity, AlertCircle } from "lucide-react"

export default async function AdminDashboard() {
  const { user } = await requireAdmin()
  const supabase = await createClient()

  const { data: statsData, error: statsError } = await supabase.rpc("admin_get_dashboard_stats")

  const stats = statsData || {
    total_users: 0,
    active_ads: 0,
    active_trades: 0,
    completed_trades_today: 0,
  }

  const statCards = [
    {
      title: "Total Users",
      value: stats.total_users || 0,
      icon: Users,
      description: "Registered users",
      color: "from-blue-500 to-cyan-500",
    },
    {
      title: "Active Ads",
      value: stats.active_ads || 0,
      icon: ShoppingBag,
      description: "P2P advertisements",
      color: "from-green-500 to-emerald-500",
    },
    {
      title: "Active Trades",
      value: stats.active_trades || 0,
      icon: Activity,
      description: "Pending trades",
      color: "from-orange-500 to-yellow-500",
    },
    {
      title: "Completed Today",
      value: stats.completed_trades_today || 0,
      icon: TrendingUp,
      description: "Today's trades",
      color: "from-purple-500 to-pink-500",
    },
  ]

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-4xl font-bold bg-gradient-to-r from-orange-400 to-red-400 bg-clip-text text-transparent mb-2">
          Admin Dashboard
        </h1>
        <p className="text-gray-400">Welcome back, manage your AFX platform</p>
      </div>

      {statsError && (
        <Card className="border-red-500/50 bg-red-500/10">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-red-400">
              <AlertCircle className="h-5 w-5" />
              Error Loading Stats
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-gray-400">{statsError.message}</p>
          </CardContent>
        </Card>
      )}

      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        {statCards.map((stat) => (
          <div
            key={stat.title}
            className="glass-card p-6 rounded-2xl border border-white/10 hover:border-white/20 transition-all duration-300 hover:scale-105"
          >
            <div className="flex items-start justify-between mb-4">
              <div>
                <p className="text-gray-400 text-sm mb-1">{stat.title}</p>
                <p className="text-3xl font-bold text-white">{stat.value}</p>
              </div>
              <div className={`p-3 bg-gradient-to-br ${stat.color} rounded-lg`}>
                <stat.icon className="h-6 w-6 text-white" />
              </div>
            </div>
            <p className="text-xs text-gray-500">{stat.description}</p>
          </div>
        ))}
      </div>
    </div>
  )
}
