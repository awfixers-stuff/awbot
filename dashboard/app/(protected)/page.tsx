import { SignedIn, SignedOut, SignInButton, UserButton } from "@clerk/nextjs";
import { auth } from "@clerk/nextjs/server";

export default async function ProtectedPage() {
  // Server-side Clerk auth check
  const { userId } = auth();

  return (
    <main className="flex flex-col items-center justify-center min-h-screen">
      <SignedIn>
        <div className="flex flex-col items-center gap-4">
          <h1 className="text-2xl font-bold">Protected Page</h1>
          <p className="text-lg">
            You are signed in and can view this protected content.
          </p>
          <div className="text-base">
            <strong>Server-side userId:</strong> {userId ?? "None"}
          </div>
          <UserButton />
        </div>
      </SignedIn>
      <SignedOut>
        <div className="flex flex-col items-center gap-4">
          <h1 className="text-2xl font-bold">Authentication Required</h1>
          <p className="text-lg">You must sign in to view this page.</p>
          <SignInButton mode="modal" />
        </div>
      </SignedOut>
    </main>
  );
}