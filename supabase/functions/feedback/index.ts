import { requireAuth } from "../_shared/auth_guard.ts";
import { getDb } from "../_shared/db.ts";
import { createRouter } from "../_shared/router.ts";
import { createFeedbackRoutes, type FeedbackRow, type FeedbackStore } from "./logic.ts";

const COLUMNS = "id, kesan, saran, rating, created_at";

const store: FeedbackStore = {
  async findLatest(userId) {
    const { data, error } = await getDb()
      .from("feedback")
      .select(COLUMNS)
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error) throw error;
    return data as FeedbackRow | null;
  },
  async insert(userId, kesan, saran, rating) {
    const { error } = await getDb().from("feedback").insert({ user_id: userId, kesan, saran, rating });
    if (error) throw error;
  },
  async update(id, kesan, saran, rating) {
    const { error } = await getDb().from("feedback").update({ kesan, saran, rating }).eq("id", id);
    if (error) throw error;
  },
};

Deno.serve(createRouter(createFeedbackRoutes(store), (req, roles) => requireAuth(req, { roles })));
