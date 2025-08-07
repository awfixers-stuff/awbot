"use client";
import { SignIn } from "@clerk/nextjs";

export default function SignInPage() {
  return (
    <main className="flex flex-col items-center justify-center min-h-screen">
      <div className="w-full max-w-md p-8 border rounded shadow bg-white dark:bg-black">
        <h1 className="text-2xl font-bold mb-4 text-center">Sign in with Discord</h1>
        <SignIn
          appearance={{
            elements: {
              socialButtonsBlockButton: "w-full",
              card: "shadow-none border-none",
            },
          }}
          path="/dashboard/sign-in"
          routing="path"
          signUpUrl="/dashboard/sign-in"
          // Only show Discord as a provider
          // See Clerk dashboard: Social Connections > Enabled Providers
          // Make sure Discord is enabled in your Clerk dashboard
          // The UI will only show Discord if it's the only enabled provider
        />
      </div>
    </main>
  );
}