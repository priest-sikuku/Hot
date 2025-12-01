"use client"

import { useState } from "react"
import { ChevronDown, X } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { KENYA_PAYMENT_METHODS } from "@/lib/p2p-filters"

interface FilterSidebarProps {
  onFilterChange: (filters: {
    paymentMethods: string[]
    priceMin: number | null
    priceMax: number | null
    minAmount: number | null
  }) => void
}

export default function FilterSidebar({ onFilterChange }: FilterSidebarProps) {
  const [selectedPaymentMethods, setSelectedPaymentMethods] = useState<string[]>([])
  const [priceMin, setPriceMin] = useState<string>("")
  const [priceMax, setPriceMax] = useState<string>("")
  const [minAmount, setMinAmount] = useState<string>("")
  const [expandedSections, setExpandedSections] = useState({
    payment: false,
    price: false,
  })

  const handleApplyFilters = () => {
    onFilterChange({
      paymentMethods: selectedPaymentMethods,
      priceMin: priceMin ? Number(priceMin) : null,
      priceMax: priceMax ? Number(priceMax) : null,
      minAmount: minAmount ? Number(minAmount) : null,
    })
  }

  const handleReset = () => {
    setSelectedPaymentMethods([])
    setPriceMin("")
    setPriceMax("")
    setMinAmount("")
    onFilterChange({
      paymentMethods: [],
      priceMin: null,
      priceMax: null,
      minAmount: null,
    })
  }

  const toggleSection = (section: keyof typeof expandedSections) => {
    setExpandedSections((prev) => ({
      ...prev,
      [section]: !prev[section],
    }))
  }

  return (
    <div className="bg-[#1a1d24] rounded-xl border border-white/5 p-5 space-y-6">
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-semibold">Filters</h3>
        {selectedPaymentMethods.length > 0 && (
          <Button
            variant="ghost"
            size="sm"
            onClick={handleReset}
            className="text-xs text-gray-400 hover:text-white hover:bg-white/5"
          >
            <X size={14} className="mr-1" />
            Reset
          </Button>
        )}
      </div>

      {/* Kenya Only Notice */}
      <div className="bg-green-500/10 border border-green-500/30 p-3 rounded-lg">
        <p className="text-xs text-green-400 font-semibold">Kenya Only • KES Currency</p>
        <p className="text-xs text-green-300/70 mt-1">All trades in Kenyan Shillings with local payment methods</p>
      </div>

      {/* Payment Methods Filter */}
      <div className="space-y-3">
        <button
          onClick={() => toggleSection("payment")}
          className="w-full flex items-center justify-between text-sm font-medium hover:text-white/80 transition"
        >
          <span>Payment Methods</span>
          <ChevronDown size={16} className={`transition-transform ${expandedSections.payment ? "rotate-180" : ""}`} />
        </button>

        {expandedSections.payment && (
          <div className="space-y-2">
            {KENYA_PAYMENT_METHODS.map((method) => (
              <div key={method.code} className="flex items-center space-x-2">
                <Checkbox
                  id={`payment-${method.code}`}
                  checked={selectedPaymentMethods.includes(method.code)}
                  onCheckedChange={(checked) => {
                    if (checked) {
                      setSelectedPaymentMethods([...selectedPaymentMethods, method.code])
                    } else {
                      setSelectedPaymentMethods(selectedPaymentMethods.filter((m) => m !== method.code))
                    }
                  }}
                />
                <Label htmlFor={`payment-${method.code}`} className="text-sm cursor-pointer flex-1">
                  {method.name}
                </Label>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Price Range Filter */}
      <div className="space-y-3">
        <button
          onClick={() => toggleSection("price")}
          className="w-full flex items-center justify-between text-sm font-medium hover:text-white/80 transition"
        >
          <span>Price Range (KES)</span>
          <ChevronDown size={16} className={`transition-transform ${expandedSections.price ? "rotate-180" : ""}`} />
        </button>

        {expandedSections.price && (
          <div className="space-y-2">
            <div>
              <Label className="text-xs text-gray-400 mb-1">Min Price</Label>
              <Input
                type="number"
                placeholder="Min"
                value={priceMin}
                onChange={(e) => setPriceMin(e.target.value)}
                className="bg-white/5 border-white/10 text-xs"
              />
            </div>
            <div>
              <Label className="text-xs text-gray-400 mb-1">Max Price</Label>
              <Input
                type="number"
                placeholder="Max"
                value={priceMax}
                onChange={(e) => setPriceMax(e.target.value)}
                className="bg-white/5 border-white/10 text-xs"
              />
            </div>
          </div>
        )}
      </div>

      {/* Minimum Amount Filter */}
      <div className="space-y-2">
        <Label className="text-sm font-medium">Min Amount (AFX)</Label>
        <Input
          type="number"
          placeholder="Minimum amount"
          value={minAmount}
          onChange={(e) => setMinAmount(e.target.value)}
          className="bg-white/5 border-white/10"
        />
      </div>

      {/* Apply Filters Button */}
      <div className="space-y-2 pt-2">
        <Button
          onClick={handleApplyFilters}
          className="w-full bg-[#0ecb81] text-black hover:bg-[#0ecb81]/90 font-semibold"
        >
          Apply Filters
        </Button>
      </div>
    </div>
  )
}
