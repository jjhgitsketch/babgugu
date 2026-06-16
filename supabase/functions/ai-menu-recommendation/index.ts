import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type SoloPlace = {
  id: string;
  name: string;
  category?: string;
  group?: string;
  distance?: string;
  address?: string;
  hours?: string;
  menu?: string;
  tags?: string[];
  score?: number;
};

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizePlaces(value: unknown): SoloPlace[] {
  if (!Array.isArray(value)) return [];
  return value
    .slice(0, 20)
    .map((item) => {
      const row = item as Record<string, unknown>;
      return {
        id: String(row.id ?? "").trim(),
        name: String(row.name ?? "").trim(),
        category: String(row.category ?? "").trim(),
        group: String(row.group ?? "").trim(),
        distance: String(row.distance ?? "").trim(),
        address: String(row.address ?? "").trim(),
        hours: String(row.hours ?? "").trim(),
        menu: String(row.menu ?? "").trim(),
        tags: Array.isArray(row.tags) ? row.tags.map((tag) => String(tag)) : [],
        score: typeof row.score === "number" ? row.score : undefined,
      };
    })
    .filter((place) => place.id.length > 0 && place.name.length > 0);
}

function sanitizeRecommendation(value: unknown, places: SoloPlace[]) {
  const raw = value && typeof value === "object" ? value as Record<string, unknown> : {};
  const ids = new Set(places.map((place) => place.id));
  let placeId = String(raw.place_id ?? "").trim();
  if (!ids.has(placeId)) placeId = places[0]?.id ?? "";
  const place = places.find((item) => item.id === placeId) ?? places[0];

  const rawAlternatives = Array.isArray(raw.alternatives) ? raw.alternatives : [];
  const alternatives = rawAlternatives
    .slice(0, 2)
    .map((item) => item as Record<string, unknown>)
    .map((item) => {
      const id = String(item.place_id ?? "").trim();
      const altPlace = places.find((candidate) => candidate.id === id);
      if (!altPlace) return null;
      return {
        place_id: altPlace.id,
        place_name: altPlace.name,
        menu: String(item.menu ?? altPlace.menu ?? "추천 메뉴"),
      };
    })
    .filter(Boolean);

  return {
    place_id: place?.id ?? "",
    place_name: place?.name ?? "",
    recommended_menu: String(raw.recommended_menu ?? place?.menu ?? "추천 메뉴"),
    reason: String(raw.reason ?? "요청한 조건과 가장 잘 맞는 혼밥 장소예요."),
    tip: String(raw.tip ?? "방문 전 영업시간을 한 번 확인해 주세요."),
    alternatives,
  };
}

async function callOpenAI(message: string, userTags: string[], places: SoloPlace[]) {
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) throw new Error("OPENAI_API_KEY is not configured");

  const model = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini";
  const systemPrompt = `너는 밥구구 앱의 혼밥 메뉴 추천 AI야.
반드시 사용자가 제공한 places 목록 안에서만 한 곳을 골라야 해.
없는 식당, 없는 메뉴, 없는 가격을 만들지 마.
한국어로 짧고 실용적으로 답해.
응답은 반드시 JSON object 하나만 반환해.
스키마: {
  "place_id": string,
  "place_name": string,
  "recommended_menu": string,
  "reason": string,
  "tip": string,
  "alternatives": [{"place_id": string, "place_name": string, "menu": string}]
}`;

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      temperature: 0.45,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: systemPrompt },
        {
          role: "user",
          content: JSON.stringify({
            user_message: message,
            user_tags: userTags,
            places,
          }),
        },
      ],
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    let message = "AI 추천 요청을 처리하지 못했어요.";
    let code = "openai_request_failed";

    try {
      const parsed = JSON.parse(text);
      const error = parsed?.error;
      if (error?.code === "insufficient_quota" || error?.type === "insufficient_quota") {
        message = "OpenAI API 크레딧 또는 결제 한도가 부족해요. OpenAI Billing을 확인해 주세요.";
        code = "insufficient_quota";
      } else if (typeof error?.message === "string") {
        message = error.message;
        code = String(error?.code ?? error?.type ?? code);
      }
    } catch (_) {
      if (text.trim().length > 0) message = text.slice(0, 180);
    }

    const error = new Error(message);
    error.name = code;
    throw error;
  }

  const data = await response.json();
  const content = data?.choices?.[0]?.message?.content;
  if (typeof content !== "string" || content.trim().length === 0) {
    throw new Error("OpenAI returned an empty recommendation");
  }
  return JSON.parse(content);
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

    const body = await req.json();
    const message = String(body.message ?? "").trim();
    const userTags = Array.isArray(body.user_tags)
      ? body.user_tags.map((tag: unknown) => String(tag)).slice(0, 20)
      : [];
    const places = normalizePlaces(body.places);

    if (message.length < 2) return json({ error: "먹고 싶은 조건을 조금 더 적어 주세요." }, 400);
    if (places.length === 0) return json({ error: "추천할 혼밥 장소 데이터가 없어요." }, 400);

    const aiResult = await callOpenAI(message, userTags, places);
    const recommendation = sanitizeRecommendation(aiResult, places);

    await supabase.from("ai_recommendation_logs").insert({
      user_id: userData.user.id,
      user_message: message,
      recommended_place_id: recommendation.place_id,
      recommended_menu: recommendation.recommended_menu,
      reason: recommendation.reason,
      response_json: recommendation,
    });

    return json(recommendation);
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : String(error), code: error instanceof Error ? error.name : "unknown" }, 500);
  }
});