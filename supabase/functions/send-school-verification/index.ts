import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const allowedDomains = new Set(["cau.ac.kr", "m365.cau.ac.kr"]);

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizeEmail(value: unknown) {
  return String(value ?? "").trim().toLowerCase();
}

function isAllowedSchoolEmail(email: string) {
  const parts = email.split("@");
  return parts.length === 2 && parts[0].length > 0 && allowedDomains.has(parts[1]);
}

function generateCode() {
  const value = crypto.getRandomValues(new Uint32Array(1))[0] % 1000000;
  return value.toString().padStart(6, "0");
}

async function hashCode(userId: string, email: string, code: string) {
  const secret = Deno.env.get("SCHOOL_VERIFICATION_SECRET");
  if (!secret) throw new Error("SCHOOL_VERIFICATION_SECRET is not configured");

  const input = new TextEncoder().encode(`${userId}:${email}:${code}:${secret}`);
  const digest = await crypto.subtle.digest("SHA-256", input);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function sendEmail(email: string, code: string) {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("MAIL_FROM");
  if (!apiKey || !from) {
    throw new Error("RESEND_API_KEY or MAIL_FROM is not configured");
  }

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: email,
      subject: "밥구구 학교 이메일 인증 코드",
      html: `
        <div style="font-family:Arial,sans-serif;line-height:1.6;color:#222">
          <h2>밥구구 학교 이메일 인증</h2>
          <p>아래 인증 코드를 앱에 입력해 주세요.</p>
          <p style="font-size:28px;font-weight:700;letter-spacing:4px">${code}</p>
          <p>이 코드는 10분 동안만 사용할 수 있어요.</p>
        </div>
      `,
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Email send failed: ${text}`);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) {
      return json({ error: "Supabase function environment is not configured" }, 500);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "");
    if (!jwt) return json({ error: "로그인이 필요해요." }, 401);

    const supabase = createClient(supabaseUrl, serviceKey);
    const { data: userData, error: userError } = await supabase.auth.getUser(jwt);
    if (userError || !userData.user) return json({ error: "로그인이 필요해요." }, 401);

    const { email: rawEmail } = await req.json();
    const email = normalizeEmail(rawEmail);
    if (!isAllowedSchoolEmail(email)) {
      return json({ error: "중앙대학교 학교 이메일만 인증할 수 있어요." }, 400);
    }

    const since = new Date(Date.now() - 60_000).toISOString();
    const { data: recentRows } = await supabase
      .from("student_email_verifications")
      .select("id")
      .eq("user_id", userData.user.id)
      .eq("email", email)
      .gte("created_at", since)
      .limit(1);
    if (recentRows && recentRows.length > 0) {
      return json({ error: "요청이 많아요. 1분 뒤 다시 시도해 주세요." }, 429);
    }

    const code = generateCode();
    const codeHash = await hashCode(userData.user.id, email, code);
    const expiresAt = new Date(Date.now() + 10 * 60_000).toISOString();

    const { error: insertError } = await supabase
      .from("student_email_verifications")
      .insert({
        user_id: userData.user.id,
        email,
        code_hash: codeHash,
        expires_at: expiresAt,
      });
    if (insertError) throw insertError;

    await sendEmail(email, code);
    return json({ ok: true });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
