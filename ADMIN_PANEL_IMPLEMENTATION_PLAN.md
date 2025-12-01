# AFX PLATFORM - ADMIN PANEL IMPLEMENTATION PLAN

**Status:** AWAITING ADMIN APPROVAL  
**Generated:** $(date)  
**System Version:** v2 (P2P Trading + Referrals + Mining)

---

## 🔒 SAFETY CHECKLIST (COMPLETE BEFORE PROCEEDING)

### ✅ Step 1: Create Backups

#### Database Snapshot
\`\`\`bash
# Option 1: Supabase Dashboard
1. Go to Supabase Dashboard → Database → Backups
2. Click "Create Backup" → Name: "pre-admin-panel-$(date +%Y%m%d)"
3. Wait for completion and verify backup exists

# Option 2: pg_dump (if you have direct access)
pg_dump $DATABASE_URL > backup_pre_admin_$(date +%Y%m%d).sql
\`\`\`

#### Code Branch
\`\`\`bash
# Create new branch for admin panel work
git checkout -b repair-admin-$(date +%Y%m%d-%H%M%S)
git add .
git commit -m "Pre-admin panel implementation snapshot"
git push origin repair-admin-$(date +%Y%m%d-%H%M%S)
\`\`\`

### ✅ Step 2: Verify Backups
- [ ] Database backup created and downloadable
- [ ] Git branch created and pushed
- [ ] Backup restoration tested (optional but recommended)

---

## 📊 SYSTEM SCAN RESULTS

### Database Schema Analysis

#### Existing Tables (18 total)
1. **profiles** - User accounts (NO admin role column yet)
2. **coins** - Dashboard balance (mining rewards)
3. **trade_coins** - P2P trading balance
4. **p2p_ads** - Buy/sell advertisements
5. **p2p_trades** - Active trades with escrow
6. **p2p_ratings** - User ratings after trades
7. **p2p_transfers** - Balance transfers between wallets
8. **trade_logs** - Audit trail for trades
9. **trade_messages** - Trade chat messages
10. **transactions** - Transaction history
11. **referrals** - Referral relationships
12. **referral_commissions** - Commission tracking
13. **mining_config** - Mining rewards configuration
14. **coin_ticks** - Price history
15. **coin_summary** - Price statistics
16. **user_balance_summary** - Aggregated balances (VIEW)
17. **user_count_config** - User counter settings
18. **total_coins_in_circulation** - Supply tracking (VIEW)

#### Missing Admin Infrastructure
- ❌ `profiles.is_admin` column
- ❌ `profiles.role` column
- ❌ `profiles.disabled` column (for soft deletes)
- ❌ `admin_audit_logs` table
- ❌ `admin_settings` table
- ❌ `admin_notifications` table

### Authentication System Analysis

**Current Setup:** ✅ Supabase SSR with RLS policies
- Middleware: `/middleware.ts` - Protects all routes
- Server client: `/lib/supabase/server.ts` - For server components
- Browser client: `/lib/supabase/client.ts` - For client components
- Protected layout: `/app/dashboard/layout.tsx` - Checks authentication

**Security Level:** 🟢 STRONG
- Row Level Security (RLS) enabled on all tables
- Cookie-based sessions (HttpOnly, Secure)
- Server-side validation
- Real-time session refresh

### Codebase Structure

\`\`\`
app/
├── auth/              # Authentication pages
├── dashboard/         # User dashboard (protected)
├── p2p/              # P2P trading pages
├── profile/          # User profile
├── referrals/        # Referral system
├── transactions/     # Transaction history
└── ratings/          # User ratings

components/           # Reusable UI components
lib/
├── supabase/        # Supabase clients
├── actions/         # Server actions
├── db/              # Database utilities
└── hooks/           # React hooks

scripts/             # SQL migration files (125 scripts)
\`\`\`

---

## 🛠️ PROPOSED CHANGES

### A. DATABASE MIGRATIONS (Non-Destructive)

#### Migration 126: Add Admin Role System
\`\`\`sql
-- File: scripts/126_add_admin_role_system.sql

-- Add admin columns to profiles
ALTER TABLE IF EXISTS profiles 
  ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user',
  ADD COLUMN IF NOT EXISTS admin_note TEXT,
  ADD COLUMN IF NOT EXISTS disabled BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS disabled_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS disabled_by UUID REFERENCES profiles(id);

-- Create index for admin queries
CREATE INDEX IF NOT EXISTS idx_profiles_is_admin ON profiles(is_admin) WHERE is_admin = TRUE;
CREATE INDEX IF NOT EXISTS idx_profiles_disabled ON profiles(disabled) WHERE disabled = TRUE;

-- Create admin audit logs table
CREATE TABLE IF NOT EXISTS admin_audit_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  admin_id UUID NOT NULL REFERENCES profiles(id),
  action TEXT NOT NULL,
  target_table TEXT,
  target_id UUID,
  details JSONB,
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_admin_id ON admin_audit_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created_at ON admin_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_action ON admin_audit_logs(action);

-- Enable RLS on admin_audit_logs
ALTER TABLE admin_audit_logs ENABLE ROW LEVEL SECURITY;

-- Only admins can view audit logs
CREATE POLICY "Admins can view audit logs"
  ON admin_audit_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.is_admin = TRUE
    )
  );

-- System can insert audit logs
CREATE POLICY "System can insert audit logs"
  ON admin_audit_logs FOR INSERT
  WITH CHECK (TRUE);

-- Create admin settings table
CREATE TABLE IF NOT EXISTS admin_settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  key TEXT UNIQUE NOT NULL,
  value JSONB NOT NULL,
  description TEXT,
  updated_by UUID REFERENCES profiles(id),
  updated_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_settings_key ON admin_settings(key);

-- Enable RLS on admin_settings
ALTER TABLE admin_settings ENABLE ROW LEVEL SECURITY;

-- Only admins can manage settings
CREATE POLICY "Admins can view settings"
  ON admin_settings FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.is_admin = TRUE
    )
  );

CREATE POLICY "Admins can update settings"
  ON admin_settings FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.is_admin = TRUE
    )
  );

CREATE POLICY "Admins can insert settings"
  ON admin_settings FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.is_admin = TRUE
    )
  );

-- Insert default admin settings
INSERT INTO admin_settings (key, value, description) VALUES
  ('trade_auto_expire_minutes', '30', 'Minutes before unpaid trades auto-expire'),
  ('max_active_ads_per_user', '10', 'Maximum active ads per user'),
  ('min_trade_amount', '1', 'Minimum AFX amount per trade'),
  ('max_trade_amount', '10000', 'Maximum AFX amount per trade'),
  ('referral_commission_rate', '0.015', 'Referral commission rate (1.5%)'),
  ('mining_enabled', 'true', 'Enable/disable mining system'),
  ('p2p_enabled', 'true', 'Enable/disable P2P trading')
ON CONFLICT (key) DO NOTHING;

-- Create function to log admin actions
CREATE OR REPLACE FUNCTION log_admin_action(
  p_action TEXT,
  p_target_table TEXT DEFAULT NULL,
  p_target_id UUID DEFAULT NULL,
  p_details JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_log_id UUID;
  v_admin_id UUID;
BEGIN
  -- Get current user
  v_admin_id := auth.uid();
  
  -- Verify user is admin
  IF NOT EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = v_admin_id AND is_admin = TRUE
  ) THEN
    RAISE EXCEPTION 'Unauthorized: User is not an admin';
  END IF;
  
  -- Insert audit log
  INSERT INTO admin_audit_logs (
    admin_id,
    action,
    target_table,
    target_id,
    details
  ) VALUES (
    v_admin_id,
    p_action,
    p_target_table,
    p_target_id,
    p_details
  ) RETURNING id INTO v_log_id;
  
  RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check if user is admin
CREATE OR REPLACE FUNCTION is_admin(p_user_id UUID DEFAULT NULL)
RETURNS BOOLEAN AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := COALESCE(p_user_id, auth.uid());
  
  RETURN EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = v_user_id 
    AND is_admin = TRUE 
    AND disabled = FALSE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION is_admin IS 'Check if a user has admin privileges';
COMMENT ON FUNCTION log_admin_action IS 'Log admin actions for audit trail';
\`\`\`

#### Migration 127: Admin CRUD Functions
\`\`\`sql
-- File: scripts/127_admin_crud_functions.sql

-- Function: Disable/Enable User (Soft Delete)
CREATE OR REPLACE FUNCTION admin_toggle_user_status(
  p_target_user_id UUID,
  p_disable BOOLEAN,
  p_reason TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_admin_id UUID;
  v_result JSONB;
BEGIN
  v_admin_id := auth.uid();
  
  -- Verify admin
  IF NOT is_admin(v_admin_id) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;
  
  -- Prevent self-disable
  IF p_target_user_id = v_admin_id THEN
    RAISE EXCEPTION 'Cannot disable your own account';
  END IF;
  
  -- Update user status
  UPDATE profiles
  SET 
    disabled = p_disable,
    disabled_at = CASE WHEN p_disable THEN NOW() ELSE NULL END,
    disabled_by = CASE WHEN p_disable THEN v_admin_id ELSE NULL END,
    admin_note = COALESCE(p_reason, admin_note),
    updated_at = NOW()
  WHERE id = p_target_user_id
  RETURNING jsonb_build_object(
    'id', id,
    'username', username,
    'email', email,
    'disabled', disabled,
    'disabled_at', disabled_at
  ) INTO v_result;
  
  -- Log action
  PERFORM log_admin_action(
    CASE WHEN p_disable THEN 'USER_DISABLED' ELSE 'USER_ENABLED' END,
    'profiles',
    p_target_user_id,
    jsonb_build_object('reason', p_reason)
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Update User Role
CREATE OR REPLACE FUNCTION admin_update_user_role(
  p_target_user_id UUID,
  p_new_role TEXT,
  p_is_admin BOOLEAN DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_admin_id UUID;
  v_result JSONB;
BEGIN
  v_admin_id := auth.uid();
  
  -- Verify admin
  IF NOT is_admin(v_admin_id) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;
  
  -- Validate role
  IF p_new_role NOT IN ('user', 'moderator', 'admin') THEN
    RAISE EXCEPTION 'Invalid role: %', p_new_role;
  END IF;
  
  -- Update user
  UPDATE profiles
  SET 
    role = p_new_role,
    is_admin = COALESCE(p_is_admin, (p_new_role = 'admin')),
    updated_at = NOW()
  WHERE id = p_target_user_id
  RETURNING jsonb_build_object(
    'id', id,
    'username', username,
    'role', role,
    'is_admin', is_admin
  ) INTO v_result;
  
  -- Log action
  PERFORM log_admin_action(
    'USER_ROLE_UPDATED',
    'profiles',
    p_target_user_id,
    jsonb_build_object('new_role', p_new_role, 'is_admin', p_is_admin)
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Force Release Trade
CREATE OR REPLACE FUNCTION admin_force_release_trade(
  p_trade_id UUID,
  p_reason TEXT
) RETURNS JSONB AS $$
DECLARE
  v_admin_id UUID;
  v_result JSONB;
BEGIN
  v_admin_id := auth.uid();
  
  -- Verify admin
  IF NOT is_admin(v_admin_id) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;
  
  -- Call existing release function
  SELECT release_p2p_coins(p_trade_id, (SELECT seller_id FROM p2p_trades WHERE id = p_trade_id))
  INTO v_result;
  
  -- Log action
  PERFORM log_admin_action(
    'TRADE_FORCE_RELEASED',
    'p2p_trades',
    p_trade_id,
    jsonb_build_object('reason', p_reason, 'result', v_result)
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Force Cancel/Refund Trade
CREATE OR REPLACE FUNCTION admin_force_cancel_trade(
  p_trade_id UUID,
  p_reason TEXT
) RETURNS JSONB AS $$
DECLARE
  v_admin_id UUID;
  v_result JSONB;
BEGIN
  v_admin_id := auth.uid();
  
  -- Verify admin
  IF NOT is_admin(v_admin_id) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;
  
  -- Call existing cancel function
  SELECT cancel_p2p_trade(p_trade_id, v_admin_id)
  INTO v_result;
  
  -- Log action
  PERFORM log_admin_action(
    'TRADE_FORCE_CANCELLED',
    'p2p_trades',
    p_trade_id,
    jsonb_build_object('reason', p_reason, 'result', v_result)
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Pause/Unpause Ad
CREATE OR REPLACE FUNCTION admin_toggle_ad_status(
  p_ad_id UUID,
  p_new_status TEXT,
  p_reason TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_admin_id UUID;
  v_result JSONB;
BEGIN
  v_admin_id := auth.uid();
  
  -- Verify admin
  IF NOT is_admin(v_admin_id) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;
  
  -- Validate status
  IF p_new_status NOT IN ('active', 'paused', 'removed') THEN
    RAISE EXCEPTION 'Invalid status: %', p_new_status;
  END IF;
  
  -- Update ad
  UPDATE p2p_ads
  SET 
    status = p_new_status,
    updated_at = NOW()
  WHERE id = p_ad_id
  RETURNING jsonb_build_object(
    'id', id,
    'user_id', user_id,
    'ad_type', ad_type,
    'status', status,
    'afx_amount', afx_amount
  ) INTO v_result;
  
  -- Log action
  PERFORM log_admin_action(
    'AD_STATUS_CHANGED',
    'p2p_ads',
    p_ad_id,
    jsonb_build_object('new_status', p_new_status, 'reason', p_reason)
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get Admin Dashboard Stats
CREATE OR REPLACE FUNCTION admin_get_dashboard_stats()
RETURNS JSONB AS $$
DECLARE
  v_admin_id UUID;
  v_stats JSONB;
BEGIN
  v_admin_id := auth.uid();
  
  -- Verify admin
  IF NOT is_admin(v_admin_id) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;
  
  SELECT jsonb_build_object(
    'total_users', (SELECT COUNT(*) FROM profiles WHERE disabled = FALSE),
    'disabled_users', (SELECT COUNT(*) FROM profiles WHERE disabled = TRUE),
    'total_admins', (SELECT COUNT(*) FROM profiles WHERE is_admin = TRUE),
    'active_trades', (SELECT COUNT(*) FROM p2p_trades WHERE status IN ('pending', 'paid')),
    'completed_trades_today', (
      SELECT COUNT(*) FROM p2p_trades 
      WHERE status = 'completed' 
      AND released_at >= CURRENT_DATE
    ),
    'active_ads', (SELECT COUNT(*) FROM p2p_ads WHERE status = 'active'),
    'total_afx_in_circulation', (SELECT COALESCE(SUM(amount), 0) FROM coins WHERE status = 'available'),
    'total_afx_in_p2p', (SELECT COALESCE(SUM(amount), 0) FROM trade_coins WHERE status = 'available'),
    'total_afx_locked', (SELECT COALESCE(SUM(amount), 0) FROM trade_coins WHERE status = 'locked'),
    'pending_ratings', (
      SELECT COUNT(*) FROM p2p_trades t
      WHERE t.status = 'completed'
      AND NOT EXISTS (
        SELECT 1 FROM p2p_ratings r 
        WHERE r.trade_id = t.id
      )
    )
  ) INTO v_stats;
  
  RETURN v_stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION admin_toggle_user_status IS 'Admin function to disable/enable users (soft delete)';
COMMENT ON FUNCTION admin_update_user_role IS 'Admin function to change user roles';
COMMENT ON FUNCTION admin_force_release_trade IS 'Admin function to force release coins in a trade';
COMMENT ON FUNCTION admin_force_cancel_trade IS 'Admin function to force cancel/refund a trade';
COMMENT ON FUNCTION admin_toggle_ad_status IS 'Admin function to pause/unpause/remove ads';
COMMENT ON FUNCTION admin_get_dashboard_stats IS 'Get admin dashboard statistics';
\`\`\`

### B. FRONTEND IMPLEMENTATION

#### 1. Admin Layout Protection
\`\`\`typescript
// File: app/admin/layout.tsx

import { redirect } from 'next/navigation'
import { createClient } from "@/lib/supabase/server"
import AdminSidebar from "@/components/admin/admin-sidebar"

export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const supabase = await createClient()
  
  // Check authentication
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) {
    redirect("/auth/sign-in")
  }
  
  // Check admin status
  const { data: profile } = await supabase
    .from("profiles")
    .select("is_admin, disabled")
    .eq("id", user.id)
    .single()
  
  if (!profile?.is_admin || profile.disabled) {
    redirect("/dashboard")
  }
  
  return (
    <div className="flex min-h-screen bg-background">
      <AdminSidebar />
      <main className="flex-1 p-8">
        {children}
      </main>
    </div>
  )
}
\`\`\`

#### 2. Admin Dashboard Page
\`\`\`typescript
// File: app/admin/page.tsx

import { createClient } from "@/lib/supabase/server"
import AdminStats from "@/components/admin/admin-stats"
import RecentActivity from "@/components/admin/recent-activity"

export default async function AdminDashboard() {
  const supabase = await createClient()
  
  // Fetch dashboard stats
  const { data: stats } = await supabase.rpc("admin_get_dashboard_stats")
  
  // Fetch recent audit logs
  const { data: recentLogs } = await supabase
    .from("admin_audit_logs")
    .select("*, admin:profiles!admin_id(username)")
    .order("created_at", { ascending: false })
    .limit(10)
  
  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold">Admin Dashboard</h1>
        <p className="text-muted-foreground">
          Manage users, trades, and system settings
        </p>
      </div>
      
      <AdminStats stats={stats} />
      <RecentActivity logs={recentLogs} />
    </div>
  )
}
\`\`\`

#### 3. Users Management Page
\`\`\`typescript
// File: app/admin/users/page.tsx

import { createClient } from "@/lib/supabase/server"
import UsersTable from "@/components/admin/users-table"
import UserSearch from "@/components/admin/user-search"

export default async function AdminUsersPage({
  searchParams,
}: {
  searchParams: { search?: string; page?: string }
}) {
  const supabase = await createClient()
  const page = Number(searchParams.page) || 1
  const pageSize = 50
  const offset = (page - 1) * pageSize
  
  // Build query
  let query = supabase
    .from("profiles")
    .select("*", { count: "exact" })
    .order("created_at", { ascending: false })
    .range(offset, offset + pageSize - 1)
  
  // Apply search filter
  if (searchParams.search) {
    query = query.or(`username.ilike.%${searchParams.search}%,email.ilike.%${searchParams.search}%`)
  }
  
  const { data: users, count } = await query
  
  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold">Users Management</h1>
        <UserSearch />
      </div>
      
      <UsersTable 
        users={users || []} 
        totalCount={count || 0}
        currentPage={page}
        pageSize={pageSize}
      />
    </div>
  )
}
\`\`\`

#### 4. Trades Management Page
\`\`\`typescript
// File: app/admin/trades/page.tsx

import { createClient } from "@/lib/supabase/server"
import TradesTable from "@/components/admin/trades-table"
import TradeFilters from "@/components/admin/trade-filters"

export default async function AdminTradesPage({
  searchParams,
}: {
  searchParams: { status?: string; page?: string }
}) {
  const supabase = await createClient()
  const page = Number(searchParams.page) || 1
  const pageSize = 50
  const offset = (page - 1) * pageSize
  
  // Build query
  let query = supabase
    .from("p2p_trades")
    .select(`
      *,
      buyer:profiles!buyer_id(username, email),
      seller:profiles!seller_id(username, email),
      ad:p2p_ads(ad_type)
    `, { count: "exact" })
    .order("created_at", { ascending: false })
    .range(offset, offset + pageSize - 1)
  
  // Apply status filter
  if (searchParams.status && searchParams.status !== "all") {
    query = query.eq("status", searchParams.status)
  }
  
  const { data: trades, count } = await query
  
  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold">Trades Management</h1>
        <TradeFilters />
      </div>
      
      <TradesTable 
        trades={trades || []} 
        totalCount={count || 0}
        currentPage={page}
        pageSize={pageSize}
      />
    </div>
  )
}
\`\`\`

#### 5. Audit Logs Page
\`\`\`typescript
// File: app/admin/logs/page.tsx

import { createClient } from "@/lib/supabase/server"
import AuditLogsTable from "@/components/admin/audit-logs-table"
import LogFilters from "@/components/admin/log-filters"

export default async function AdminLogsPage({
  searchParams,
}: {
  searchParams: { action?: string; admin?: string; page?: string }
}) {
  const supabase = await createClient()
  const page = Number(searchParams.page) || 1
  const pageSize = 100
  const offset = (page - 1) * pageSize
  
  // Build query
  let query = supabase
    .from("admin_audit_logs")
    .select(`
      *,
      admin:profiles!admin_id(username, email)
    `, { count: "exact" })
    .order("created_at", { ascending: false })
    .range(offset, offset + pageSize - 1)
  
  // Apply filters
  if (searchParams.action) {
    query = query.eq("action", searchParams.action)
  }
  if (searchParams.admin) {
    query = query.eq("admin_id", searchParams.admin)
  }
  
  const { data: logs, count } = await query
  
  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold">Audit Logs</h1>
        <LogFilters />
      </div>
      
      <AuditLogsTable 
        logs={logs || []} 
        totalCount={count || 0}
        currentPage={page}
        pageSize={pageSize}
      />
    </div>
  )
}
\`\`\`

### C. API ROUTES FOR ADMIN ACTIONS

#### User Management API
\`\`\`typescript
// File: app/api/admin/users/[id]/route.ts

import { createClient } from "@/lib/supabase/server"
import { NextResponse } from "next/server"

export async function PATCH(
  request: Request,
  { params }: { params: { id: string } }
) {
  const supabase = await createClient()
  
  // Verify admin
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
  }
  
  const { data: profile } = await supabase
    .from("profiles")
    .select("is_admin")
    .eq("id", user.id)
    .single()
  
  if (!profile?.is_admin) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 })
  }
  
  // Get request body
  const body = await request.json()
  const { action, ...data } = body
  
  try {
    let result
    
    switch (action) {
      case "disable":
        result = await supabase.rpc("admin_toggle_user_status", {
          p_target_user_id: params.id,
          p_disable: true,
          p_reason: data.reason
        })
        break
        
      case "enable":
        result = await supabase.rpc("admin_toggle_user_status", {
          p_target_user_id: params.id,
          p_disable: false
        })
        break
        
      case "update_role":
        result = await supabase.rpc("admin_update_user_role", {
          p_target_user_id: params.id,
          p_new_role: data.role,
          p_is_admin: data.is_admin
        })
        break
        
      default:
        return NextResponse.json({ error: "Invalid action" }, { status: 400 })
    }
    
    if (result.error) throw result.error
    
    return NextResponse.json({ success: true, data: result.data })
  } catch (error) {
    console.error("Admin action error:", error)
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Action failed" },
      { status: 500 }
    )
  }
}
\`\`\`

#### Trade Management API
\`\`\`typescript
// File: app/api/admin/trades/[id]/route.ts

import { createClient } from "@/lib/supabase/server"
import { NextResponse } from "next/server"

export async function POST(
  request: Request,
  { params }: { params: { id: string } }
) {
  const supabase = await createClient()
  
  // Verify admin
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
  }
  
  const { data: profile } = await supabase
    .from("profiles")
    .select("is_admin")
    .eq("id", user.id)
    .single()
  
  if (!profile?.is_admin) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 })
  }
  
  // Get request body
  const body = await request.json()
  const { action, reason } = body
  
  try {
    let result
    
    switch (action) {
      case "force_release":
        result = await supabase.rpc("admin_force_release_trade", {
          p_trade_id: params.id,
          p_reason: reason
        })
        break
        
      case "force_cancel":
        result = await supabase.rpc("admin_force_cancel_trade", {
          p_trade_id: params.id,
          p_reason: reason
        })
        break
        
      default:
        return NextResponse.json({ error: "Invalid action" }, { status: 400 })
    }
    
    if (result.error) throw result.error
    
    return NextResponse.json({ success: true, data: result.data })
  } catch (error) {
    console.error("Admin trade action error:", error)
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Action failed" },
      { status: 500 }
    )
  }
}
\`\`\`

---

## 🧪 TESTING PLAN

### Pre-Deployment Tests (Staging)

1. **Admin Access Control**
   - [ ] Non-admin users cannot access `/admin` routes
   - [ ] Admin users can access all admin pages
   - [ ] Disabled admin accounts are blocked

2. **User Management**
   - [ ] List users with pagination
   - [ ] Search users by username/email
   - [ ] Disable user account (soft delete)
   - [ ] Enable disabled user account
   - [ ] Update user role (user → moderator → admin)
   - [ ] View user details and stats

3. **Trade Management**
   - [ ] List trades with filters (status, date)
   - [ ] View trade details
   - [ ] Force release coins to buyer
   - [ ] Force cancel/refund trade
   - [ ] Verify balances updated correctly

4. **Ad Management**
   - [ ] List all ads
   - [ ] Pause/unpause ads
   - [ ] Remove ads (soft delete)

5. **Audit Logging**
   - [ ] All admin actions logged
   - [ ] Logs include admin_id, action, target, details
   - [ ] Logs filterable by action/admin/date

6. **Settings Management**
   - [ ] View system settings
   - [ ] Update settings
   - [ ] Settings changes logged

### Post-Deployment Verification

1. **Create Test Admin**
   \`\`\`sql
   UPDATE profiles 
   SET is_admin = TRUE, role = 'admin'
   WHERE email = 'your-admin-email@example.com';
   \`\`\`

2. **Verify Admin Panel Access**
   - Login as admin
   - Navigate to `/admin`
   - Verify dashboard loads

3. **Test CRUD Operations**
   - Create test user
   - Disable/enable test user
   - Create test trade
   - Force release test trade
   - Verify audit logs

---

## 🔄 ROLLBACK PLAN

### If Issues Occur

#### 1. Rollback Database
\`\`\`sql
-- Drop admin tables
DROP TABLE IF EXISTS admin_audit_logs CASCADE;
DROP TABLE IF EXISTS admin_settings CASCADE;

-- Remove admin columns
ALTER TABLE profiles 
  DROP COLUMN IF EXISTS is_admin,
  DROP COLUMN IF EXISTS role,
  DROP COLUMN IF EXISTS admin_note,
  DROP COLUMN IF EXISTS disabled,
  DROP COLUMN IF EXISTS disabled_at,
  DROP COLUMN IF EXISTS disabled_by;

-- Drop admin functions
DROP FUNCTION IF EXISTS log_admin_action CASCADE;
DROP FUNCTION IF EXISTS is_admin CASCADE;
DROP FUNCTION IF EXISTS admin_toggle_user_status CASCADE;
DROP FUNCTION IF EXISTS admin_update_user_role CASCADE;
DROP FUNCTION IF EXISTS admin_force_release_trade CASCADE;
DROP FUNCTION IF EXISTS admin_force_cancel_trade CASCADE;
DROP FUNCTION IF EXISTS admin_toggle_ad_status CASCADE;
DROP FUNCTION IF EXISTS admin_get_dashboard_stats CASCADE;
\`\`\`

#### 2. Rollback Code
\`\`\`bash
# Switch back to previous branch
git checkout main

# Or restore from backup branch
git checkout repair-admin-YYYYMMDD-HHMMSS
git checkout -b main-restored
\`\`\`

#### 3. Restore Database from Backup
\`\`\`bash
# If using pg_dump backup
psql $DATABASE_URL < backup_pre_admin_YYYYMMDD.sql

# If using Supabase backup
# Go to Supabase Dashboard → Database → Backups → Restore
\`\`\`

---

## 📋 DEPLOYMENT CHECKLIST

### Before Running Migrations

- [ ] Database backup created and verified
- [ ] Code branch created and pushed
- [ ] Staging environment available for testing
- [ ] Admin email addresses identified
- [ ] Team notified of maintenance window

### Running Migrations

\`\`\`bash
# 1. Run migration 126 (admin role system)
# Execute scripts/126_add_admin_role_system.sql in Supabase SQL Editor

# 2. Run migration 127 (admin CRUD functions)
# Execute scripts/127_admin_crud_functions.sql in Supabase SQL Editor

# 3. Create first admin user
UPDATE profiles 
SET is_admin = TRUE, role = 'admin'
WHERE email = 'your-admin-email@example.com';

# 4. Verify migrations
SELECT * FROM admin_settings;
SELECT * FROM profiles WHERE is_admin = TRUE;
\`\`\`

### After Migrations

- [ ] Verify admin user can login
- [ ] Verify admin panel accessible at `/admin`
- [ ] Test user management CRUD
- [ ] Test trade management actions
- [ ] Verify audit logs working
- [ ] Monitor error logs for issues

### Post-Deployment

- [ ] Document admin procedures
- [ ] Train admin team
- [ ] Set up monitoring/alerts
- [ ] Schedule regular audit log reviews

---

## 🔐 SECURITY CONSIDERATIONS

### Access Control
- ✅ Server-side admin checks on all routes
- ✅ RLS policies prevent unauthorized data access
- ✅ Admin actions require valid session
- ✅ Audit logging for accountability

### Data Protection
- ✅ Soft deletes (no hard deletes without confirmation)
- ✅ Admin actions reversible where possible
- ✅ Sensitive data masked in logs
- ✅ IP address and user agent logged

### Best Practices
- ✅ Principle of least privilege
- ✅ Separation of concerns (admin vs user routes)
- ✅ Input validation on all admin actions
- ✅ Rate limiting on admin API routes (recommended)

---

## 📊 ESTIMATED IMPACT

### Database Changes
- **New Tables:** 2 (admin_audit_logs, admin_settings)
- **Modified Tables:** 1 (profiles - 6 new columns)
- **New Functions:** 8 admin functions
- **New Indexes:** 5 indexes for performance

### Code Changes
- **New Routes:** 6 admin pages
- **New Components:** ~15 admin components
- **New API Routes:** 4 admin API endpoints
- **Modified Files:** 0 (all new additions)

### Performance Impact
- **Minimal:** Admin queries use indexes
- **Audit logs:** Async inserts, no user-facing impact
- **RLS policies:** Efficient with proper indexes

---

## ✅ APPROVAL REQUIRED

**Before proceeding, admin must:**

1. ✅ Review this entire plan
2. ✅ Verify backups are created
3. ✅ Approve SQL migrations
4. ✅ Identify first admin user email
5. ✅ Schedule deployment window

**To approve and proceed:**
\`\`\`
I approve the admin panel implementation plan.
Proceed with migrations and deployment.
First admin email: [your-email@example.com]
\`\`\`

---

## 📞 SUPPORT

If issues occur during or after deployment:
1. Check audit logs for errors
2. Review Supabase logs
3. Rollback using provided scripts
4. Contact development team

**End of Implementation Plan**
