export default function SignInLoading() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-gray-900 via-black to-gray-900">
      <div className="w-full max-w-md p-8">
        <div className="bg-gray-800/50 backdrop-blur-sm rounded-2xl border border-gray-700 p-8 space-y-6 animate-pulse">
          {/* Logo skeleton */}
          <div className="flex justify-center mb-6">
            <div className="h-12 w-12 bg-gray-700 rounded-full"></div>
          </div>
          
          {/* Title skeleton */}
          <div className="space-y-2">
            <div className="h-8 bg-gray-700 rounded w-3/4 mx-auto"></div>
            <div className="h-4 bg-gray-700 rounded w-1/2 mx-auto"></div>
          </div>

          {/* Form fields skeleton */}
          <div className="space-y-4">
            <div className="h-12 bg-gray-700 rounded"></div>
            <div className="h-12 bg-gray-700 rounded"></div>
            <div className="h-12 bg-gray-700 rounded"></div>
          </div>

          {/* Link skeleton */}
          <div className="h-4 bg-gray-700 rounded w-2/3 mx-auto"></div>
        </div>
      </div>
    </div>
  )
}
