import { NextRequest, NextResponse } from "next/server";

export async function POST(req: NextRequest) {
  try {
    const { token } = await req.json();
    const secretKey = process.env.TURNSTILE_SECRET_KEY;

    if (!token || !secretKey) {
      return NextResponse.json(
        { success: false, message: "Missing token or secret key" },
        { status: 400 }
      );
    }

    const verifyRes = await fetch(
      "https://challenges.cloudflare.com/turnstile/v0/siteverify",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          secret: secretKey,
          response: token,
        }),
      }
    );

    const data = await verifyRes.json();

    if (data.success) {
      // Set a cookie to indicate the user is verified
      const response = NextResponse.json({ success: true });
      response.cookies.set("turnstile_verified", "true", {
        httpOnly: true,
        sameSite: "lax",
        path: "/",
        maxAge: 60 * 60 * 24, // 1 day
      });
      return response;
    } else {
      return NextResponse.json(
        { success: false, message: "Turnstile verification failed", ...data },
        { status: 400 }
      );
    }
  } catch (error) {
    return NextResponse.json(
      { success: false, message: "Server error", error: String(error) },
      { status: 500 }
    );
  }
}