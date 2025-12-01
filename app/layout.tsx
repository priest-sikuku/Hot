import type React from "react"
import type { Metadata } from "next"
import { Geist, Geist_Mono, Inter } from "next/font/google"
import { Analytics } from "@vercel/analytics/next"
import "./globals.css"
import { PWAInstaller } from "@/components/pwa-installer"
import { MobileBottomNav } from "@/components/mobile-bottom-nav"

const _geist = Geist({ subsets: ["latin"] })
const _geistMono = Geist_Mono({ subsets: ["latin"] })
const inter = Inter({ subsets: ["latin"], variable: "--font-inter" })

export const metadata: Metadata = {
  title: "AfriX — The Coin That Never Sleeps",
  description: "AfriX (AFX) — The Coin That Never Sleeps. Mine every 3 hours. 3% daily growth. P2P trading.",
  generator: "v0.app",
  manifest: "/manifest.json",
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "AfriX",
  },
  icons: {
    icon: [
      { url: "/icon-192x192.jpg", sizes: "192x192", type: "image/png" },
      { url: "/icon-512x512.jpg", sizes: "512x512", type: "image/png" },
    ],
    apple: [{ url: "/icon-192x192.jpg", sizes: "192x192", type: "image/png" }],
  },
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en">
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=5, user-scalable=yes" />
        <meta name="theme-color" content="#1C1C1C" />
        <link rel="manifest" href="/manifest.json" />
        <link rel="apple-touch-icon" href="/icon-192x192.jpg" />
      </head>
      <body
        className={`${inter.variable} font-sans antialiased bg-gradient-to-b from-[#0f1720] to-[#071124] text-[#e6eef8]`}
      >
        {children}
        <MobileBottomNav />
        <Analytics />
        <PWAInstaller />
      </body>
    </html>
  )
}
