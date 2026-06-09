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

async function hashCode(userId: string, email: string, code: string) {
  const secret = Deno.env.get("SCHOOL_VERIFICATION_SECRET");
  if (!secret) throw new Error("SCHOOL_VERIFICATION_SECRET is not configured");

  const input = new TextEncoder().encode(`${userId}:${email}:${code}:${secret}`);
  const digest = await crypto.subtle.digest("SHA-256", input);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
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

    const { email: rawEmail, code: rawCode } = await req.json();
    const email = normalizeEmail(rawEmail);
    const code = String(rawCode ?? "").trim();

    if (!isAllowedSchoolEmail(email)) {
      return json({ error: "중앙대학교 학교 이메일만 인증할 수 있어요." }, 400);
    }
    if (!/^\d{6}$/.test(code)) {
      return json({ error: "인증 코드가 올바르지 않아요." }, 400);
    }

    const { data: row, error: selectError } = await supabase
      .from("student_email_verifications")
      .select("id, code_hash, expires_at")
      .eq("user_id", userData.user.id)
      .eq("email", email)
      .is("consumed_at", null)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (selectError) throw selectError;
    if (!row) return json({ error: "인증 코드가 올바르지 않아요." }, 400);

    if (new Date(row.expires_at).getTime() < Date.now()) {
      return json({ error: "인증 코드가 만료됐어요." }, 400);
    }

    const codeHash = await hashCode(userData.user.id, email, code);
    if (codeHash !== row.code_hash) {
      return json({ error: "인증 코드가 올바르지 않아요." }, 400);
    }

    const verifiedAt = new Date().toISOString();
    const { error: consumeError } = await supabase
      .from("student_email_verifications")
      .update({ consumed_at: verifiedAt })
      .eq("id", row.id);
    if (consumeError) throw consumeError;

    const { error: updateError } = await supabase
      .from("users")
      .update({
        school_email: email,
        student_verified: true,
        student_verified_at: verifiedAt,
      })
      .eq("id", userData.user.id);
    if (updateError) throw updateError;

    return json({
      ok: true,
      school_email: email,
      student_verified: true,
      student_verified_at: verifiedAt,
    });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
