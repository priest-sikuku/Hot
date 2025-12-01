import { Trash2, Eye } from "lucide-react"

interface Listing {
  id: number
  type: "buy" | "sell"
  amount: number
  price: number
  total: number
  paymentMethod: string
  status: "active" | "completed" | "cancelled"
  createdAt: string
}

interface MyListingsProps {
  listings: Listing[]
}

export function MyListings({ listings }: MyListingsProps) {
  const statusColors = {
    active: "bg-green-500/10 text-green-400",
    completed: "bg-blue-500/10 text-blue-400",
    cancelled: "bg-red-500/10 text-red-400",
  }

  return (
    <div className="space-y-4">
      {listings.length === 0 ? (
        <div className="glass-card p-12 rounded-2xl border border-white/5 text-center">
          <p className="text-gray-400 mb-4">You haven't created any listings yet.</p>
          <button className="px-6 py-2 rounded-lg btn-primary-gx font-semibold hover:shadow-lg hover:shadow-green-500/50 transition">
            Create Your First Listing
          </button>
        </div>
      ) : (
        listings.map((listing) => (
          <div
            key={listing.id}
            className="glass-card p-6 rounded-xl border border-white/5 hover:border-green-500/30 transition"
          >
            <div className="grid grid-cols-1 md:grid-cols-6 gap-4 items-center">
              <div>
                <p className="text-sm text-gray-400 mb-1">Type</p>
                <p className="font-semibold capitalize">{listing.type}</p>
              </div>

              <div>
                <p className="text-sm text-gray-400 mb-1">Amount</p>
                <p className="font-semibold">{listing.amount} GX</p>
              </div>

              <div>
                <p className="text-sm text-gray-400 mb-1">Price</p>
                <p className="font-semibold">${listing.price}</p>
              </div>

              <div>
                <p className="text-sm text-gray-400 mb-1">Total</p>
                <p className="font-semibold text-green-400">${listing.total}</p>
              </div>

              <div>
                <p className="text-sm text-gray-400 mb-1">Status</p>
                <span className={`px-3 py-1 rounded-full text-xs font-semibold ${statusColors[listing.status]}`}>
                  {listing.status}
                </span>
              </div>

              <div className="flex gap-2">
                <button className="p-2 rounded-lg hover:bg-white/10 transition">
                  <Eye className="w-4 h-4 text-gray-400" />
                </button>
                <button className="p-2 rounded-lg hover:bg-red-500/10 transition">
                  <Trash2 className="w-4 h-4 text-red-400" />
                </button>
              </div>
            </div>
          </div>
        ))
      )}
    </div>
  )
}
