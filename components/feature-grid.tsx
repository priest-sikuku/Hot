export function FeatureGrid() {
  const features = [
    {
      title: "Auto Growth",
      description: "Compounds daily to grow holders' balances.",
    },
    {
      title: "P2P Trading",
      description: "Direct swaps between users with escrow options.",
    },
  ]

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
      {features.map((feature, idx) => (
        <div key={idx} className="glass-card p-6 rounded-xl border border-white/5 hover:border-green-500/30 transition">
          <h4 className="font-bold text-white mb-2">{feature.title}</h4>
          <p className="text-sm text-gray-400">{feature.description}</p>
        </div>
      ))}
    </div>
  )
}
