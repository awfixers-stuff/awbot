"use client";
import { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Turnstile from "react-turnstile";

export default function TurnstileChallengePage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [token, setToken] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  // Get redirect path from query params (default to "/")
  const redirect = searchParams.get("redirect") || "/";

  useEffect(() => {
    if (token) {
      setSubmitting(true);
      // Send token to API for verification and set cookie
      fetch("/api/verify-turnstile", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token }),
      })
        .then(async (res) => {
          if (!res.ok) {
            const data = await res.json();
            throw new Error(data.message || "Verification failed");
          }
          // On success, reload to redirect to original page
          router.replace(redirect);
        })
        .catch((err) => {
          setError(err.message || "Verification failed");
          setSubmitting(false);
        });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  return (
    <main className="flex flex-col items-center justify-center min-h-screen bg-gray-50">
      <div className="bg-white rounded shadow p-8 flex flex-col items-center max-w-md w-full">
        <h1 className="text-2xl font-bold mb-4">Human Verification Required</h1>
        <p className="mb-6 text-gray-700 text-center">
          Please complete the challenge below to continue.
        </p>
        <Turnstile
          sitekey="YOUR_TURNSTILE_SITE_KEY"
          onVerify={setToken}
          className="mb-4"
        />
        {submitting && (
          <div className="text-blue-600 font-medium mt-2">Verifying...</div>
        )}
        {error && (
          <div className="text-red-600 font-medium mt-2">{error}</div>
        )}
      </div>
    </main>
  );
}