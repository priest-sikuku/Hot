"use client"

import { Globe } from "lucide-react"

export function CountrySelector() {
  return (
    <div className="flex items-center gap-2 px-4 py-2 rounded-lg bg-green-500/10 border border-green-500/30">
      <Globe size={18} className="text-green-400" />
      <span className="text-sm font-semibold text-green-400">Kenya (KES)</span>
    </div>
  )
}
