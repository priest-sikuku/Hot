"use client"

import { useState } from "react"
import Footer from "@/components/footer"
import { UserProfile } from "@/components/user-profile"
import { SecuritySettings } from "@/components/security-settings"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"

export default function Profile() {
  const [activeTab, setActiveTab] = useState("profile")

  return (
    <div className="min-h-screen flex flex-col pb-20 md:pb-0">
      <main className="flex-1">
        <div className="max-w-4xl mx-auto px-6 py-12">
          <div className="mb-8">
            <h1 className="text-4xl font-bold mb-2">Account Settings</h1>
            <p className="text-gray-400">Manage your profile and security</p>
          </div>

          <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
            <TabsList className="grid w-full grid-cols-2 mb-8 bg-white/5 border border-white/10">
              <TabsTrigger value="profile">Profile</TabsTrigger>
              <TabsTrigger value="security">Security</TabsTrigger>
            </TabsList>

            <TabsContent value="profile">
              <UserProfile />
            </TabsContent>

            <TabsContent value="security">
              <SecuritySettings />
            </TabsContent>
          </Tabs>
        </div>
      </main>
      <Footer />
    </div>
  )
}
