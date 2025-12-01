"use client"

import type React from "react"

import { useState } from "react"
import { Lock, Shield, LogOut } from "lucide-react"

export function SecuritySettings() {
  const [showPasswordForm, setShowPasswordForm] = useState(false)
  const [passwordData, setPasswordData] = useState({
    currentPassword: "",
    newPassword: "",
    confirmPassword: "",
  })

  const handlePasswordChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target
    setPasswordData((prev) => ({ ...prev, [name]: value }))
  }

  const handleUpdatePassword = () => {
    if (passwordData.newPassword !== passwordData.confirmPassword) {
      alert("Passwords do not match")
      return
    }
    setShowPasswordForm(false)
    setPasswordData({ currentPassword: "", newPassword: "", confirmPassword: "" })
    alert("Password updated successfully")
  }

  return (
    <div className="space-y-6">
      {/* Change Password */}
      <div className="glass-card p-8 rounded-2xl border border-white/5">
        <div className="flex items-start justify-between mb-6">
          <div className="flex items-start gap-4">
            <div className="p-3 bg-blue-500/10 rounded-lg">
              <Lock className="w-6 h-6 text-blue-400" />
            </div>
            <div>
              <h3 className="text-xl font-bold mb-1">Change Password</h3>
              <p className="text-gray-400 text-sm">Update your password regularly to keep your account secure</p>
            </div>
          </div>
        </div>

        {!showPasswordForm ? (
          <button
            onClick={() => setShowPasswordForm(true)}
            className="px-4 py-2 rounded-lg border border-green-500/30 text-green-400 hover:bg-green-500/10 transition font-semibold text-sm"
          >
            Change Password
          </button>
        ) : (
          <div className="space-y-4">
            <div>
              <label className="block text-sm text-gray-400 mb-2">Current Password</label>
              <input
                type="password"
                name="currentPassword"
                value={passwordData.currentPassword}
                onChange={handlePasswordChange}
                className="w-full px-4 py-3 rounded-lg bg-white/5 border border-white/10 text-white focus:outline-none focus:border-green-500/50 transition"
              />
            </div>
            <div>
              <label className="block text-sm text-gray-400 mb-2">New Password</label>
              <input
                type="password"
                name="newPassword"
                value={passwordData.newPassword}
                onChange={handlePasswordChange}
                className="w-full px-4 py-3 rounded-lg bg-white/5 border border-white/10 text-white focus:outline-none focus:border-green-500/50 transition"
              />
            </div>
            <div>
              <label className="block text-sm text-gray-400 mb-2">Confirm Password</label>
              <input
                type="password"
                name="confirmPassword"
                value={passwordData.confirmPassword}
                onChange={handlePasswordChange}
                className="w-full px-4 py-3 rounded-lg bg-white/5 border border-white/10 text-white focus:outline-none focus:border-green-500/50 transition"
              />
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => setShowPasswordForm(false)}
                className="flex-1 px-4 py-2 rounded-lg border border-white/10 text-white hover:bg-white/5 transition font-semibold text-sm"
              >
                Cancel
              </button>
              <button
                onClick={handleUpdatePassword}
                className="flex-1 px-4 py-2 rounded-lg btn-primary-gx font-semibold hover:shadow-lg hover:shadow-green-500/50 transition text-sm"
              >
                Update Password
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Two-Factor Authentication */}
      <div className="glass-card p-8 rounded-2xl border border-white/5">
        <div className="flex items-start justify-between">
          <div className="flex items-start gap-4">
            <div className="p-3 bg-purple-500/10 rounded-lg">
              <Shield className="w-6 h-6 text-purple-400" />
            </div>
            <div>
              <h3 className="text-xl font-bold mb-1">Two-Factor Authentication</h3>
              <p className="text-gray-400 text-sm">Add an extra layer of security to your account</p>
            </div>
          </div>
          <button className="px-4 py-2 rounded-lg border border-green-500/30 text-green-400 hover:bg-green-500/10 transition font-semibold text-sm">
            Enable
          </button>
        </div>
      </div>

      {/* Active Sessions */}
      <div className="glass-card p-8 rounded-2xl border border-white/5">
        <h3 className="text-xl font-bold mb-6">Active Sessions</h3>
        <div className="space-y-4">
          <div className="flex items-center justify-between p-4 bg-white/5 rounded-lg">
            <div>
              <p className="font-semibold">Chrome on macOS</p>
              <p className="text-sm text-gray-400">Last active: 2 hours ago</p>
            </div>
            <button className="text-red-400 hover:text-red-300 transition">
              <LogOut className="w-5 h-5" />
            </button>
          </div>
          <div className="flex items-center justify-between p-4 bg-white/5 rounded-lg">
            <div>
              <p className="font-semibold">Safari on iPhone</p>
              <p className="text-sm text-gray-400">Last active: 1 day ago</p>
            </div>
            <button className="text-red-400 hover:text-red-300 transition">
              <LogOut className="w-5 h-5" />
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
