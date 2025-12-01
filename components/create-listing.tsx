"use client"

import type React from "react"

import { useState } from "react"
import { Plus } from "lucide-react"

interface CreateListingProps {
  onCreateListing: (listing: any) => void
}

export function CreateListing({ onCreateListing }: CreateListingProps) {
  const [showForm, setShowForm] = useState(false)
  const [formData, setFormData] = useState({
    amount: "",
    price: "",
    paymentMethod: "M-Pesa",
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    const amount = Number.parseFloat(formData.amount)
    const price = Number.parseFloat(formData.price)
    const total = amount * price

    onCreateListing({
      type: "sell",
      amount,
      price,
      total,
      paymentMethod: formData.paymentMethod,
      status: "active",
      createdAt: "just now",
    })

    setFormData({ amount: "", price: "", paymentMethod: "M-Pesa" })
    setShowForm(false)
  }

  return (
    <div className="glass-card p-6 rounded-2xl border border-white/5 sticky top-6">
      <h3 className="text-xl font-bold mb-4">Create Listing</h3>

      {!showForm ? (
        <button
          onClick={() => setShowForm(true)}
          className="w-full px-4 py-3 rounded-lg btn-primary-gx font-semibold hover:shadow-lg hover:shadow-green-500/50 transition flex items-center justify-center gap-2"
        >
          <Plus className="w-5 h-5" />
          Create New Listing
        </button>
      ) : (
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm text-gray-400 mb-2">Amount (GX)</label>
            <input
              type="number"
              step="0.01"
              value={formData.amount}
              onChange={(e) => setFormData({ ...formData, amount: e.target.value })}
              placeholder="500"
              className="w-full px-4 py-2 rounded-lg bg-white/5 border border-white/10 text-white placeholder-gray-500 focus:outline-none focus:border-green-500/50"
              required
            />
          </div>

          <div>
            <label className="block text-sm text-gray-400 mb-2">Price per GX ($)</label>
            <input
              type="number"
              step="0.01"
              value={formData.price}
              onChange={(e) => setFormData({ ...formData, price: e.target.value })}
              placeholder="0.85"
              className="w-full px-4 py-2 rounded-lg bg-white/5 border border-white/10 text-white placeholder-gray-500 focus:outline-none focus:border-green-500/50"
              required
            />
          </div>

          <div>
            <label className="block text-sm text-gray-400 mb-2">Payment Method</label>
            <select
              value={formData.paymentMethod}
              onChange={(e) => setFormData({ ...formData, paymentMethod: e.target.value })}
              className="w-full px-4 py-2 rounded-lg bg-white/5 border border-white/10 text-white focus:outline-none focus:border-green-500/50"
            >
              <option value="M-Pesa">M-Pesa</option>
              <option value="Bank Transfer">Bank Transfer</option>
              <option value="Airtel Money">Airtel Money</option>
            </select>
          </div>

          {formData.amount && formData.price && (
            <div className="bg-green-500/10 border border-green-500/30 rounded-lg p-3">
              <p className="text-sm text-gray-400">Total</p>
              <p className="text-xl font-bold text-green-400">
                ${(Number.parseFloat(formData.amount) * Number.parseFloat(formData.price)).toFixed(2)}
              </p>
            </div>
          )}

          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => setShowForm(false)}
              className="flex-1 px-4 py-2 rounded-lg border border-white/10 text-white hover:bg-white/5 transition font-semibold text-sm"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="flex-1 px-4 py-2 rounded-lg btn-primary-gx font-semibold hover:shadow-lg hover:shadow-green-500/50 transition text-sm"
            >
              Create
            </button>
          </div>
        </form>
      )}
    </div>
  )
}
