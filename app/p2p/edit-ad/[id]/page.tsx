"use client"

import type React from "react"

import { useEffect, useState } from "react"
import { ArrowLeft, Save } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import Header from "@/components/header"
import Footer from "@/components/footer"
import { createClient } from "@/lib/supabase/client"
import { useRouter, useParams } from "next/navigation"

export default function EditAdPage() {
  const params = useParams()
  const adId = params.id as string
  const router = useRouter()
  const supabase = createClient()

  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [currentPrice, setCurrentPrice] = useState(0)
  const [formData, setFormData] = useState({
    afx_amount: "",
    min_amount: "",
    max_amount: "",
    price_per_afx: "",
    account_number: "",
    mpesa_number: "",
    paybill_number: "",
    airtel_money: "",
    terms_of_trade: "",
  })

  useEffect(() => {
    fetchCurrentPrice()
    fetchAdData()
  }, [])

  async function fetchCurrentPrice() {
    const { data } = await supabase.from("afx_current_price").select("price").single()
    if (data) {
      setCurrentPrice(data.price)
    }
  }

  async function fetchAdData() {
    try {
      const { data, error } = await supabase.from("p2p_ads").select("*").eq("id", adId).single()

      if (error || !data) {
        alert("Ad not found")
        router.push("/p2p/my-ads")
        return
      }

      setFormData({
        afx_amount: data.afx_amount.toString(),
        min_amount: data.min_amount.toString(),
        max_amount: data.max_amount.toString(),
        price_per_afx: data.price_per_afx.toString(),
        account_number: data.account_number || "",
        mpesa_number: data.mpesa_number || "",
        paybill_number: data.paybill_number || "",
        airtel_money: data.airtel_money || "",
        terms_of_trade: data.terms_of_trade || "",
      })
    } catch (error) {
      console.error("[v0] Error fetching ad:", error)
    } finally {
      setLoading(false)
    }
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setSaving(true)

    try {
      const afxAmount = Number.parseFloat(formData.afx_amount)
      const minAmount = Number.parseFloat(formData.min_amount)
      const maxAmount = Number.parseFloat(formData.max_amount)
      const pricePerAfx = Number.parseFloat(formData.price_per_afx)

      // Validation
      if (afxAmount < 50) {
        alert("Minimum AFX amount is 50 AFX")
        setSaving(false)
        return
      }

      if (minAmount < 2) {
        alert("Minimum tradable amount is 2 AFX")
        setSaving(false)
        return
      }

      if (maxAmount > afxAmount) {
        alert("Maximum amount cannot exceed total AFX amount")
        setSaving(false)
        return
      }

      // Price validation (±4% from current price)
      const minPrice = currentPrice * 0.96
      const maxPrice = currentPrice * 1.04
      if (pricePerAfx < minPrice || pricePerAfx > maxPrice) {
        alert(`Price must be within ±4% of current AFX price (${minPrice.toFixed(2)} - ${maxPrice.toFixed(2)} KES)`)
        setSaving(false)
        return
      }

      const { error } = await supabase
        .from("p2p_ads")
        .update({
          afx_amount: afxAmount,
          min_amount: minAmount,
          max_amount: maxAmount,
          price_per_afx: pricePerAfx,
          account_number: formData.account_number,
          mpesa_number: formData.mpesa_number,
          paybill_number: formData.paybill_number,
          airtel_money: formData.airtel_money,
          terms_of_trade: formData.terms_of_trade,
          updated_at: new Date().toISOString(),
        })
        .eq("id", adId)

      if (error) {
        alert("Failed to update ad: " + error.message)
        return
      }

      alert("Ad updated successfully!")
      router.push("/p2p/my-ads")
    } catch (error) {
      console.error("[v0] Error:", error)
      alert("Failed to update ad")
    } finally {
      setSaving(false)
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen flex flex-col">
        <Header />
        <main className="flex-1 flex items-center justify-center">
          <p className="text-gray-400">Loading ad...</p>
        </main>
        <Footer />
      </div>
    )
  }

  return (
    <div className="min-h-screen flex flex-col">
      <Header />
      <main className="flex-1">
        <div className="max-w-3xl mx-auto px-6 py-12">
          <Button variant="ghost" className="mb-6 hover:bg-white/5" onClick={() => router.push("/p2p/my-ads")}>
            <ArrowLeft size={20} className="mr-2" />
            Back to My Ads
          </Button>

          <div className="mb-8">
            <h1 className="text-4xl font-bold mb-2">Edit Advertisement</h1>
            <p className="text-gray-400">Update your ad details</p>
          </div>

          <form onSubmit={handleSubmit} className="glass-card p-8 rounded-xl border border-white/10 space-y-6">
            <div className="space-y-2">
              <Label htmlFor="afx_amount">AFX Amount (Min: 50 AFX)</Label>
              <Input
                id="afx_amount"
                type="number"
                step="0.01"
                value={formData.afx_amount}
                onChange={(e) => setFormData({ ...formData, afx_amount: e.target.value })}
                required
                className="bg-white/5 border-white/10"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="min_amount">Min Amount (Min: 2 AFX)</Label>
                <Input
                  id="min_amount"
                  type="number"
                  step="0.01"
                  value={formData.min_amount}
                  onChange={(e) => setFormData({ ...formData, min_amount: e.target.value })}
                  required
                  className="bg-white/5 border-white/10"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="max_amount">Max Amount</Label>
                <Input
                  id="max_amount"
                  type="number"
                  step="0.01"
                  value={formData.max_amount}
                  onChange={(e) => setFormData({ ...formData, max_amount: e.target.value })}
                  required
                  className="bg-white/5 border-white/10"
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="price_per_afx">
                Price per AFX (KES) - Must be within ±4% of current price ({(currentPrice * 0.96).toFixed(2)} -{" "}
                {(currentPrice * 1.04).toFixed(2)})
              </Label>
              <Input
                id="price_per_afx"
                type="number"
                step="0.01"
                value={formData.price_per_afx}
                onChange={(e) => setFormData({ ...formData, price_per_afx: e.target.value })}
                required
                className="bg-white/5 border-white/10"
              />
            </div>

            <div className="space-y-4">
              <h3 className="text-lg font-semibold">Payment Methods</h3>

              <div className="space-y-2">
                <Label htmlFor="account_number">Account Number</Label>
                <Input
                  id="account_number"
                  type="text"
                  value={formData.account_number}
                  onChange={(e) => setFormData({ ...formData, account_number: e.target.value })}
                  className="bg-white/5 border-white/10"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="mpesa_number">M-Pesa Number</Label>
                <Input
                  id="mpesa_number"
                  type="text"
                  value={formData.mpesa_number}
                  onChange={(e) => setFormData({ ...formData, mpesa_number: e.target.value })}
                  className="bg-white/5 border-white/10"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="paybill_number">Paybill Number</Label>
                <Input
                  id="paybill_number"
                  type="text"
                  value={formData.paybill_number}
                  onChange={(e) => setFormData({ ...formData, paybill_number: e.target.value })}
                  className="bg-white/5 border-white/10"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="airtel_money">Airtel Money Number</Label>
                <Input
                  id="airtel_money"
                  type="text"
                  value={formData.airtel_money}
                  onChange={(e) => setFormData({ ...formData, airtel_money: e.target.value })}
                  className="bg-white/5 border-white/10"
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="terms_of_trade">Terms of Trade</Label>
              <Textarea
                id="terms_of_trade"
                value={formData.terms_of_trade}
                onChange={(e) => setFormData({ ...formData, terms_of_trade: e.target.value })}
                rows={4}
                className="bg-white/5 border-white/10"
              />
            </div>

            <Button
              type="submit"
              disabled={saving}
              className="w-full bg-gradient-to-r from-green-500 to-green-600 text-black hover:shadow-lg hover:shadow-green-500/50"
            >
              <Save size={20} className="mr-2" />
              {saving ? "Saving..." : "Save Changes"}
            </Button>
          </form>
        </div>
      </main>
      <Footer />
    </div>
  )
}
