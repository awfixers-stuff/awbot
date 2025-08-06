import { NextRequest, NextResponse } from "next/server";

// Set this to your Turnstile siteverify endpoint and secret key
const TURNSTILE_SECRET_KEY = process.env.TURNSTILE_SECRET_KEY;

// The name of the cookie that stores Turnstile verification status
const TURNSTILE_COOKIE = "turnstile_verified";

// Paths that should NOT require Turnstile (e.g., static, API for verification, auth, etc.)
const EXEMPT_PATHS = [
  "/api/verify-turnstile",
  "/favicon.ico",
  "/robots.txt",
  "/manifest.json",
  "/_next",
  "/static",
  "/public",
  "/sign-in",
  "/sign-up",
];

// Utility: Check if the request path is exempt from Turnstile
function isExemptPath(path: string) {
  return EXEMPT_PATHS.some((exempt) =>
    path === exempt || path.startsWith(exempt + "/")
  );
}

// Middleware entry point
export async function middleware(req: NextRequest) {
  const url = req.nextUrl.clone();
  const { pathname } = url;

  // Allow exempt paths
  if (isExemptPath(pathname)) {
    return NextResponse.next();
  }

  // Check for Turnstile verification cookie
  const verified = req.cookies.get(TURNSTILE_COOKIE)?.value === "true";

  if (verified) {
    // User has passed Turnstile, allow access
    return NextResponse.next();
  }

  // If not verified, redirect to Turnstile challenge page
  url.pathname = "/turnstile-challenge";
  url.searchParams.set("redirect", pathname);
  return NextResponse.redirect(url);
}

// Optionally, export config for Next.js matcher
export const config = {
  matcher: [
    /*
      Match all routes except:
      - Next.js internals
      - static files
      - API for Turnstile verification
      - sign-in/up pages
    */
    "/((?!_next|static|public|favicon.ico|robots.txt|manifest.json|api/verify-turnstile|sign-in|sign-up).*)",
  ],
};