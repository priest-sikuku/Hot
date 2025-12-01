"use client"

import type React from "react"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import Header from "@/components/header"
import Footer from "@/components/footer"
import { ArrowLeft, Loader2 } from "lucide-react"
import { createClient } from "@/lib/supabase/client"

const KENYA_PAYMENT_METHODS = [
  { id: "mpesa", name: "M-Pesa (Personal)", code: "mpesa" },
  { id: "mpesa-paybill", name: "M-Pesa Paybill", code: "mpesa_paybill" },
  { id: "bank-transfer", name: "Bank Transfer", code: "bank_transfer" },
  { id: "airtel-money", name: "Airtel Money", code: "airtel_money" },
]

const PAYMENT_METHOD_FIELDS: Record<string, Record<string, string>> = {
  mpesa: { phone: "M-Pesa Phone Number" },
  mpesa_paybill: { paybill: "Paybill Number", account: "Account Number" },
  bank_transfer: { bank: "Bank Name", account: "Account Number", name: "Account Holder Name" },
  airtel_money: { phone: "Airtel Money Phone Number" },
}

export default function PostAdPage() {
  const router = useRouter()
  const supabase = createClient()

  const [adType, setAdType] = useState<"buy" | "sell">("sell")
  const [loading, setLoading] = useState(false)
  const [currentAFXPrice, setCurrentAFXPrice] = useState<number>(0)

  const userCountry = "KE"
  const userCurrency = "KES"
  const selectedCurrency = "KES"

  const [selectedPaymentMethods, setSelectedPaymentMethods] = useState<string[]>([])
  const [paymentDetails, setPaymentDetails] = useState<Record<string, Record<string, string>>>({})

  useEffect(() => {
    const fetchUserAndPrice = async () => {
      const supabase = createClient()

      const {
        data: { user },
      } = await supabase.auth.getUser()
      if (!user) {
        router.push("/auth/sign-in")
        return
      }

      // Fetch latest price from coin_ticks table
      const { data, error } = await supabase
        .from("coin_ticks")
        .select("price")
        .order("tick_timestamp", { ascending: false })
        .limit(1)
        .single()

      if (!error && data) {
        const livePrice = Number(data.price)
        setCurrentAFXPrice(livePrice)
        setFormData((prev) => ({ ...prev, pricePerAFX: "" }))
      } else {
        console.error("[v0] Error fetching from coin_ticks:", error)
        const { data: currentPrice } = await supabase.from("afx_current_price").select("price").single()

        const fallbackPrice = currentPrice?.price ? Number(currentPrice.price) : 13.0
        setCurrentAFXPrice(fallbackPrice)
        setFormData((prev) => ({ ...prev, pricePerAFX: "" }))
      }
    }

    fetchUserAndPrice()
  }, [])

  const handlePaymentMethodToggle = (methodId: string, checked: boolean) => {
    if (checked) {
      setSelectedPaymentMethods([...selectedPaymentMethods, methodId])
      setPaymentDetails({
        ...paymentDetails,
        [methodId]: {},
      })
    } else {
      setSelectedPaymentMethods(selectedPaymentMethods.filter((m) => m !== methodId))
      const updatedDetails = { ...paymentDetails }
      delete updatedDetails[methodId]
      setPaymentDetails(updatedDetails)
    }
  }

  const handlePaymentDetailChange = (methodId: string, field: string, value: string) => {
    setPaymentDetails((prev) => ({
      ...prev,
      [methodId]: {
        ...prev[methodId],
        [field]: value,
      },
    }))
  }

  const getSuggestedPrice = (): number => {
    return currentAFXPrice || 16.29
  }

  const getPriceRange = () => {
    const suggested = getSuggestedPrice()
    const min = Math.max(1, suggested * 0.96)
    const max = suggested * 1.04
    return { min, max }
  }

  const priceRange = getPriceRange()
  const suggestedPrice = getSuggestedPrice()

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()

    if (adType === "sell" && selectedPaymentMethods.length === 0) {
      alert("Please select at least one payment method")
      return
    }

    setLoading(true)

    try {
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (!user) {
        alert("Please sign in first")
        setLoading(false)
        return
      }

      if (adType === "sell") {
        const { data: coinsData } = await supabase
          .from("coins")
          .select("amount")
          .eq("user_id", user.id)
          .eq("status", "available")
          .single()

        const availableCoins = coinsData?.amount || 0
        const adCreationCost = 10 // Cost to create a sell ad

        if (availableCoins < adCreationCost) {
          alert(`You need at least ${adCreationCost} coins to create a sell ad. You have ${availableCoins} coins.`)
          setLoading(false)
          return
        }
      }

      if (!formData.afxAmount || !formData.pricePerAFX || !formData.minAmount || !formData.maxAmount) {
        alert("Please fill in all required fields")
        setLoading(false)
        return
      }

      const afxAmount = Number.parseFloat(formData.afxAmount)
      const pricePerAFX = Number.parseFloat(formData.pricePerAFX)
      const minAmount = Number.parseFloat(formData.minAmount)
      const maxAmount = Number.parseFloat(formData.maxAmount)

      if (isNaN(afxAmount) || isNaN(pricePerAFX) || isNaN(minAmount) || isNaN(maxAmount)) {
        alert("Invalid number format")
        setLoading(false)
        return
      }

      if (afxAmount < 5) {
        alert("Minimum AFX amount is 5")
        setLoading(false)
        return
      }

      if (minAmount < 1) {
        alert("Minimum amount must be at least 1 AFX")
        setLoading(false)
        return
      }

      if (minAmount > maxAmount) {
        alert("Min amount cannot be greater than max amount")
        setLoading(false)
        return
      }

      if (maxAmount > afxAmount) {
        alert("Max amount cannot exceed total AFX amount")
        setLoading(false)
        return
      }

      if (pricePerAFX < priceRange.min || pricePerAFX > priceRange.max) {
        alert(`Price must be between ${priceRange.min.toFixed(2)} and ${priceRange.max.toFixed(2)} KES`)
        setLoading(false)
        return
      }

      let mpesaNumber = ""
      let paybillNumber = ""
      let paybillAccount = ""
      let bankName = ""
      let bankAccount = ""
      let bankAccountName = ""
      let airtelNumber = ""

      if (adType === "sell") {
        selectedPaymentMethods.forEach((methodId) => {
          const methodCode = KENYA_PAYMENT_METHODS.find((m) => m.id === methodId)?.code
          const details = paymentDetails[methodId] || {}

          if (methodCode === "mpesa") {
            mpesaNumber = details.phone || ""
          } else if (methodCode === "mpesa_paybill") {
            paybillNumber = details.paybill || ""
            paybillAccount = details.account || ""
          } else if (methodCode === "bank_transfer") {
            bankName = details.bank || ""
            bankAccount = details.account || ""
            bankAccountName = details.name || ""
          } else if (methodCode === "airtel_money") {
            airtelNumber = details.phone || ""
          }
        })
      }

      const { data, error } = await supabase.from("p2p_ads").insert([
        {
          user_id: user.id,
          ad_type: adType,
          afx_amount: afxAmount,
          remaining_amount: afxAmount,
          price_per_afx: pricePerAFX,
          min_amount: minAmount,
          max_amount: maxAmount,
          mpesa_number: mpesaNumber,
          paybill_number: paybillNumber,
          account_number: bankAccount,
          airtel_money: airtelNumber,
          payment_methods_selected: selectedPaymentMethods.map((methodId) => {
            const method = KENYA_PAYMENT_METHODS.find((m) => m.id === methodId)
            return {
              id: methodId,
              code: method?.code,
              name: method?.name,
            }
          }),
          terms_of_trade: formData.termsOfTrade || "",
          status: "active",
          expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
        },
      ])

      if (error) {
        console.error("[v0] Error creating ad:", error)
        alert(error.message || "Failed to create ad")
        return
      }

      if (adType === "sell") {
        const adCreationCost = 10
        const { error: deductError } = await supabase.rpc("deduct_coins_for_ad", {
          p_user_id: user.id,
          p_amount: adCreationCost,
        })

        if (deductError) {
          console.error("[v0] Error deducting coins:", deductError)
          // Optionally delete the ad if coin deduction fails
          await supabase.from("p2p_ads").delete().eq("id", data[0]?.id)
          alert("Failed to deduct coins. Ad creation cancelled.")
          return
        }
      }

      alert("Ad created successfully!")
      router.push("/p2p/my-ads")
    } catch (error) {
      console.error("[v0] Error:", error)
      alert("An error occurred while creating the ad")
    } finally {
      setLoading(false)
    }
  }

  const [formData, setFormData] = useState({
    afxAmount: "",
    pricePerAFX: "",
    minAmount: "",
    maxAmount: "",
    termsOfTrade: "",
  })

  return (
    <div className="min-h-screen flex flex-col bg-black pb-20 md:pb-0">
      <Header />
      <main className="flex-1">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 py-8">
          <button onClick={() => router.back()} className="flex items-center gap-2 text-gray-400 hover:text-white mb-6">
            <ArrowLeft size={20} />
            Go Back
          </button>

          <h1 className="text-3xl font-bold mb-2">Post a P2P Ad</h1>
          <p className="text-gray-400 mb-8">Kenya (KES) - All trades in Kenyan Shillings only</p>

          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Ad Type Selection */}
            <div className="bg-[#1a1d24] rounded-xl p-6 border border-white/5">
              <Label className="text-base font-semibold mb-4 block">I want to *</Label>
              <div className="flex gap-4">
                <button
                  type="button"
                  onClick={() => setAdType("buy")}
                  className={`flex-1 py-3 rounded-lg font-semibold transition-all ${
                    adType === "buy"
                      ? "bg-[#0ecb81] text-black"
                      : "bg-white/5 text-white border border-white/10 hover:bg-white/10"
                  }`}
                >
                  Buy
                </button>
                <button
                  type="button"
                  onClick={() => setAdType("sell")}
                  className={`flex-1 py-3 rounded-lg font-semibold transition-all ${
                    adType === "sell"
                      ? "bg-[#f6465d] text-white"
                      : "bg-white/5 text-white border border-white/10 hover:bg-white/10"
                  }`}
                >
                  Sell
                </button>
              </div>
            </div>

            {/* Kenya Notice */}
            <div className="bg-green-500/10 border border-green-500/30 p-4 rounded-lg">
              <p className="text-sm text-green-400 font-semibold">Kenya Only • Currency: KES</p>
              <p className="text-xs text-green-300/70 mt-1">
                This ad will be listed for Kenyan traders only with KES pricing
              </p>
            </div>

            {/* Amount and Price */}
            <div className="space-y-2">
              <Label htmlFor="afxAmount">Amount of AFX * (Minimum: 5 AFX)</Label>
              <Input
                id="afxAmount"
                type="number"
                step="0.01"
                min="5"
                placeholder="Enter AFX amount (min 5)"
                value={formData.afxAmount}
                onChange={(e) => setFormData({ ...formData, afxAmount: e.target.value })}
                required
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="pricePerAFX">Price per AFX (KSh {selectedCurrency}) *</Label>
              <Input
                id="pricePerAFX"
                type="number"
                step="0.01"
                min={priceRange.min.toFixed(2)}
                max={priceRange.max.toFixed(2)}
                placeholder={`Between ${priceRange.min.toFixed(2)} - ${priceRange.max.toFixed(2)} KES`}
                value={formData.pricePerAFX}
                onChange={(e) => setFormData({ ...formData, pricePerAFX: e.target.value })}
                required
              />
              <p className="text-xs text-gray-400">
                Current AFX price: {suggestedPrice.toFixed(4)} KES. Allowed range: {priceRange.min.toFixed(2)} -{" "}
                {priceRange.max.toFixed(2)} KES (±4%)
              </p>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="minAmount">Min Amount (AFX) * (Minimum: 1 AFX)</Label>
                <Input
                  id="minAmount"
                  type="number"
                  step="0.01"
                  min="1"
                  placeholder="Minimum (min 1)"
                  value={formData.minAmount}
                  onChange={(e) => setFormData({ ...formData, minAmount: e.target.value })}
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="maxAmount">Max Amount (AFX) *</Label>
                <Input
                  id="maxAmount"
                  type="number"
                  step="0.01"
                  placeholder="Maximum"
                  value={formData.maxAmount}
                  onChange={(e) => setFormData({ ...formData, maxAmount: e.target.value })}
                  required
                />
              </div>
            </div>

            {/* Kenya Payment Methods */}
            <div className="space-y-4">
              <h3 className="text-lg font-semibold">Kenya Payment Methods</h3>

              <div className="space-y-4">
                <div className="space-y-3">
                  <Label className="text-sm font-medium">
                    {adType === "sell"
                      ? "Select Payment Methods * (at least one)"
                      : "Accepted Payment Methods (select which ones you'll accept)"}
                  </Label>
                  <div className="space-y-2">
                    {KENYA_PAYMENT_METHODS.map((method) => (
                      <div
                        key={method.id}
                        className="flex items-start space-x-3 p-3 bg-white/5 rounded-lg border border-white/10 hover:bg-white/10 transition-colors cursor-pointer"
                      >
                        <input
                          type="checkbox"
                          id={`payment-${method.id}`}
                          checked={selectedPaymentMethods.includes(method.id)}
                          onChange={(e) => handlePaymentMethodToggle(method.id, e.target.checked)}
                          className="mt-1 w-4 h-4 cursor-pointer"
                        />
                        <label htmlFor={`payment-${method.id}`} className="flex-1 cursor-pointer">
                          <span className="text-sm font-medium">{method.name}</span>
                        </label>
                      </div>
                    ))}
                  </div>
                </div>

                {selectedPaymentMethods.length > 0 && (
                  <div className="space-y-4 p-4 bg-blue-500/10 border border-blue-500/20 rounded-lg">
                    {selectedPaymentMethods.map((methodId) => {
                      const method = KENYA_PAYMENT_METHODS.find((m) => m.id === methodId)
                      const methodCode = method?.code || ""
                      const fields = PAYMENT_METHOD_FIELDS[methodCode] || {}

                      return (
                        <div key={methodId} className="space-y-3 pb-4 border-b border-blue-500/20 last:border-b-0">
                          <p className="text-sm text-blue-300 font-medium">{method?.name} Details</p>
                          {Object.entries(fields).map(([fieldKey, fieldLabel]) => (
                            <div key={fieldKey} className="space-y-1">
                              <Label className="text-sm">
                                {fieldLabel} {adType === "sell" ? "*" : ""}
                              </Label>
                              <Input
                                type="text"
                                placeholder={`Enter ${fieldLabel.toLowerCase()}`}
                                value={paymentDetails[methodId]?.[fieldKey] || ""}
                                onChange={(e) => handlePaymentDetailChange(methodId, fieldKey, e.target.value)}
                                className="w-full px-3 py-2 bg-white/5 border border-white/10 rounded-lg text-sm text-white placeholder-gray-500 focus:outline-none focus:border-blue-500/50"
                                required={adType === "sell"}
                              />
                            </div>
                          ))}
                        </div>
                      )
                    })}
                  </div>
                )}
              </div>
            </div>

            {/* Terms of Trade */}
            <div className="space-y-2">
              <Label htmlFor="termsOfTrade">Terms of Trade (Optional)</Label>
              <textarea
                id="termsOfTrade"
                placeholder="e.g., 'Please send money first' or 'Must complete within 1 hour'"
                value={formData.termsOfTrade}
                onChange={(e) => setFormData({ ...formData, termsOfTrade: e.target.value })}
                className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white text-sm min-h-24"
              />
            </div>

            {/* Submit Button */}
            <Button
              type="submit"
              disabled={loading}
              className="w-full bg-[#0ecb81] text-black font-semibold hover:bg-[#0ecb81]/90 py-3"
            >
              {loading && <Loader2 size={18} className="mr-2 animate-spin" />}
              {loading ? "Creating Ad..." : "Create Ad"}
            </Button>
          </form>
        </div>
      </main>
      <Footer />
    </div>
  )
}
