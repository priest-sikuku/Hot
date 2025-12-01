"use client"

import { useState } from "react"
import { Star, Shield } from "lucide-react"

interface Listing {
  id: number
  seller: string
  amount: number
  price: number
  total: number
  paymentMethod: string
  rating: number
  trades: number
  escrow: boolean
}

interface MarketListingsProps {
  listings: Listing[]
  type: "buy" | "sell"
}

export function MarketListings({ listings, type }: MarketListingsProps) {
  const [selectedListing, setSelectedListing] = useState<Listing | null>(null)
  const [showModal, setShowModal] = useState(false)

  const handleTrade = (listing: Listing) => {
    setSelectedListing(listing)
    setShowModal(true)
  }

  return (
    <>
      <div className="space-y-4">
        {listings.map((listing) => (
          <div
            key={listing.id}
            className="glass-card p-6 rounded-xl border border-white/5 hover:border-green-500/30 transition"
          >
            <div className="grid grid-cols-1 md:grid-cols-5 gap-4 items-center">
              {/* Seller Info */}
              <div>
                <p className="text-sm text-gray-400 mb-1">Seller</p>
                <p className="font-semibold text-white">{listing.seller}</p>
                <div className="flex items-center gap-1 mt-2">
                  <Star className="w-4 h-4 text-yellow-400 fill-yellow-400" />
                  <span className="text-xs text-gray-400">
                    {listing.rating} ({listing.trades} trades)
                  </span>
                </div>
              </div>

              {/* Amount */}
              <div>
                <p className="text-sm text-gray-400 mb-1">Amount</p>
                <p className="font-semibold text-white">{listing.amount} GX</p>
              </div>

              {/* Price */}
              <div>
                <p className="text-sm text-gray-400 mb-1">Price per GX</p>
                <p className="font-semibold text-white">${listing.price}</p>
              </div>

              {/* Total */}
              <div>
                <p className="text-sm text-gray-400 mb-1">Total</p>
                <p className="font-semibold text-green-400">${listing.total}</p>
                <p className="text-xs text-gray-400 mt-1">{listing.paymentMethod}</p>
              </div>

              {/* Action */}
              <div className="flex flex-col gap-2">
                <button
                  onClick={() => handleTrade(listing)}
                  className="px-4 py-2 rounded-lg btn-primary-gx font-semibold hover:shadow-lg hover:shadow-green-500/50 transition text-sm"
                >
                  {type === "buy" ? "Buy" : "Sell"}
                </button>
                {listing.escrow && (
                  <div className="flex items-center justify-center gap-1 text-xs text-blue-400">
                    <Shield className="w-3 h-3" />
                    <span>Escrow</span>
                  </div>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Trade Modal */}
      {showModal && selectedListing && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="glass-card p-8 rounded-2xl border border-white/5 max-w-md w-full">
            <h2 className="text-2xl font-bold mb-6">
              {type === "buy" ? "Buy" : "Sell"} GX from {selectedListing.seller}
            </h2>

            <div className="space-y-4 mb-6">
              <div className="flex justify-between">
                <span className="text-gray-400">Amount</span>
                <span className="font-semibold">{selectedListing.amount} GX</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Price per GX</span>
                <span className="font-semibold">${selectedListing.price}</span>
              </div>
              <div className="border-t border-white/5 pt-4 flex justify-between">
                <span className="text-gray-400">Total</span>
                <span className="font-bold text-green-400">${selectedListing.total}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Payment Method</span>
                <span className="font-semibold">{selectedListing.paymentMethod}</span>
              </div>
            </div>

            <div className="bg-blue-500/10 border border-blue-500/30 rounded-lg p-4 mb-6">
              <div className="flex gap-2 items-start">
                <Shield className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                <div>
                  <p className="text-sm font-semibold text-blue-400 mb-1">Escrow Protected</p>
                  <p className="text-xs text-gray-400">
                    Funds are held securely until both parties confirm the transaction.
                  </p>
                </div>
              </div>
            </div>

            <div className="flex gap-3">
              <button
                onClick={() => setShowModal(false)}
                className="flex-1 px-4 py-3 rounded-lg border border-white/10 text-white hover:bg-white/5 transition font-semibold"
              >
                Cancel
              </button>
              <button className="flex-1 px-4 py-3 rounded-lg btn-primary-gx font-semibold hover:shadow-lg hover:shadow-green-500/50 transition">
                Confirm {type === "buy" ? "Purchase" : "Sale"}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
