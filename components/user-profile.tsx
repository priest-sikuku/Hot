"use client"

import type React from "react"
import { useState } from "react"
import { User, Mail, Phone, MapPin } from "lucide-react"

export function UserProfile() {
  const [isEditing, setIsEditing] = useState(false)
  const [formData, setFormData] = useState({
    name: "John Doe",
    email: "john@example.com",
    phone: "+254 712 345 678",
    location: "Nairobi, Kenya",
    bio: "Crypto enthusiast and GrowX miner",
  })

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target
    setFormData((prev) => ({ ...prev, [name]: value }))
  }

  const handleSave = () => {
    setIsEditing(false)
    // Save to backend
  }

  return (
    <div className="space-y-6">
      <div className="glass-card p-8 rounded-2xl border border-white/5">
        <div className="flex items-start justify-between mb-8">
          <div>
            <h2 className="text-2xl font-bold mb-2">Profile Information</h2>
            <p className="text-gray-400">Update your personal details</p>
          </div>
          <button
            onClick={() => setIsEditing(!isEditing)}
            className="px-4 py-2 rounded-lg border border-green-500/30 text-green-400 hover:bg-green-500/10 transition font-semibold text-sm"
          >
            {isEditing ? "Cancel" : "Edit"}
          </button>
        </div>

        <div className="space-y-6">
          {/* Avatar */}
          <div className="flex items-center gap-4">
            <div className="w-20 h-20 rounded-full bg-gradient-to-br from-green-400 to-green-600 flex items-center justify-center">
              <User className="w-10 h-10 text-white" />
            </div>
            {isEditing && (
              <button className="px-4 py-2 rounded-lg border border-white/10 text-white hover:bg-white/5 transition text-sm">
                Change Avatar
              </button>
            )}
          </div>

          {/* Form Fields */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Name */}
            <div>
              <label className="block text-sm text-gray-400 mb-2">Full Name</label>
              {isEditing ? (
                <input
                  type="text"
                  name="name"
                  value={formData.name}
                  onChange={handleChange}
                  className="w-full px-4 py-3 rounded-lg bg-white/5 border border-white/10 text-white focus:outline-none focus:border-green-500/50 transition"
                />
              ) : (
                <p className="text-white">{formData.name}</p>
              )}
            </div>

            {/* Email */}
            <div>
              <label className="block text-sm text-gray-400 mb-2 flex items-center gap-2">
                <Mail className="w-4 h-4" />
                Email
              </label>
              {isEditing ? (
                <input
                  type="email"
                  name="email"
                  value={formData.email}
                  onChange={handleChange}
                  className="w-full px-4 py-3 rounded-lg bg-white/5 border border-white/10 text-white focus:outline-none focus:border-green-500/50 transition"
                />
              ) : (
                <p className="text-white">{formData.email}</p>
              )}
            </div>

            {/* Phone */}
            <div>
              <label className="block text-sm text-gray-400 mb-2 flex items-center gap-2">
                <Phone className="w-4 h-4" />
                Phone
              </label>
              {isEditing ? (
                <input
                  type="tel"
                  name="phone"
                  value={formData.phone}
                  onChange={handleChange}
                  className="w-full px-4 py-3 rounded-lg bg-white/5 border border-white/10 text-white focus:outline-none focus:border-green-500/50 transition"
                />
              ) : (
                <p className="text-white">{formData.phone}</p>
              )}
            </div>

            {/* Location */}
            <div>
              <label className="block text-sm text-gray-400 mb-2 flex items-center gap-2">
                <MapPin className="w-4 h-4" />
                Location
              </label>
              {isEditing ? (
                <input
                  type="text"
                  name="location"
                  value={formData.location}
                  onChange={handleChange}
                  className="w-full px-4 py-3 rounded-lg bg-white/5 border border-white/10 text-white focus:outline-none focus:border-green-500/50 transition"
                />
              ) : (
                <p className="text-white">{formData.location}</p>
              )}
            </div>
          </div>

          {/* Bio */}
          <div>
            <label className="block text-sm text-gray-400 mb-2">Bio</label>
            {isEditing ? (
              <textarea
                name="bio"
                value={formData.bio}
                onChange={handleChange}
                rows={4}
                className="w-full px-4 py-3 rounded-lg bg-white/5 border border-white/10 text-white focus:outline-none focus:border-green-500/50 transition resize-none"
              />
            ) : (
              <p className="text-white">{formData.bio}</p>
            )}
          </div>

          {/* Save Button */}
          {isEditing && (
            <button
              onClick={handleSave}
              className="w-full px-4 py-3 rounded-lg btn-primary-gx font-semibold hover:shadow-lg hover:shadow-green-500/50 transition"
            >
              Save Changes
            </button>
          )}
        </div>
      </div>
    </div>
  )
}
