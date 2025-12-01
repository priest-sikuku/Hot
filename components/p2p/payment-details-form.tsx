"use client"

import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import type { PaymentGateway } from "@/lib/p2p-filters"

interface PaymentDetailsFormProps {
  gateway: PaymentGateway
  details: Record<string, string>
  onChange: (field: string, value: string) => void
}

export default function PaymentDetailsForm({ gateway, details, onChange }: PaymentDetailsFormProps) {
  if (!gateway.field_labels) {
    return (
      <div className="p-4 bg-yellow-500/10 border border-yellow-500/20 rounded-lg">
        <p className="text-sm text-yellow-600">No details required for this payment method</p>
      </div>
    )
  }

  return (
    <div className="space-y-4 p-4 bg-blue-500/10 border border-blue-500/20 rounded-lg">
      <p className="text-sm text-blue-300 font-medium">Enter your {gateway.gateway_name} details</p>

      {Object.entries(gateway.field_labels).map(([key, label]) => (
        <div key={key} className="space-y-1">
          <Label className="text-sm">{label} *</Label>
          <Input
            type={key.includes("number") || key.includes("amount") || key.includes("account") ? "text" : "text"}
            placeholder={`Enter ${label.toLowerCase()}`}
            value={details[key] || ""}
            onChange={(e) => onChange(key, e.target.value)}
            className="bg-white/5 border-white/10"
            required
          />
        </div>
      ))}
    </div>
  )
}
