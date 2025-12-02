import Link from "next/link"
import Header from "@/components/header"
import Footer from "@/components/footer"
import { AlertCircle } from "lucide-react"

export default function NotFound() {
  return (
    <div className="min-h-screen flex flex-col pb-20 md:pb-0">
      <Header />
      <main className="flex-1 flex items-center justify-center">
        <div className="text-center px-6 py-12">
          <div className="mb-6 flex justify-center">
            <div className="p-4 bg-red-500/10 rounded-full border border-red-500/20">
              <AlertCircle className="w-12 h-12 text-red-400" />
            </div>
          </div>

          <h1 className="text-5xl md:text-6xl font-bold mb-4 text-white">404</h1>
          <p className="text-xl text-gray-400 mb-2">Page Not Found</p>
          <p className="text-gray-500 mb-8 max-w-md mx-auto">
            The page you're looking for doesn't exist. It might have been moved or deleted.
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link
              href="/"
              className="glass-card px-6 py-3 rounded-lg border border-green-500/20 hover:border-green-500/50 hover:bg-green-500/10 transition font-semibold text-white"
            >
              Go Home
            </Link>
            <Link
              href="/dashboard"
              className="glass-card px-6 py-3 rounded-lg border border-blue-500/20 hover:border-blue-500/50 hover:bg-blue-500/10 transition font-semibold text-white"
            >
              Go to Dashboard
            </Link>
          </div>
        </div>
      </main>
      <Footer />
    </div>
  )
}
