import { HttpError, json } from "../_shared/http.ts";
import type { Route } from "../_shared/router.ts";
import { str } from "../_shared/validate.ts";

export interface FeedbackRow {
  id: number;
  kesan: string;
  saran: string;
  rating: number;
  created_at: string;
}

export interface FeedbackStore {
  findLatest(userId: number): Promise<FeedbackRow | null>;
  insert(userId: number, kesan: string, saran: string, rating: number): Promise<void>;
  update(id: number, kesan: string, saran: string, rating: number): Promise<void>;
}

const MAX_TEXT = 1000;

function publicRow(r: FeedbackRow | null) {
  return {
    feedback: r && {
      kesan: r.kesan,
      saran: r.saran,
      rating: r.rating,
      created_at: r.created_at,
    },
  };
}

export function createFeedbackRoutes(store: FeedbackStore): Record<string, Route> {
  return {
    mine: {
      handle: async (ctx) => json(publicRow(await store.findLatest(ctx.userId))),
    },

    // Satu jawaban per pengguna: mengirim lagi memperbarui jawaban sebelumnya.
    submit: {
      handle: async (ctx, body) => {
        const kesan = str(body.kesan).trim();
        const saran = str(body.saran).trim();
        const rating = body.rating;

        if (!kesan || kesan.length > MAX_TEXT) {
          throw new HttpError(400, "Kesan wajib diisi (maksimal 1000 karakter)");
        }
        if (!saran || saran.length > MAX_TEXT) {
          throw new HttpError(400, "Saran wajib diisi (maksimal 1000 karakter)");
        }
        if (typeof rating !== "number" || !Number.isInteger(rating) || rating < 1 || rating > 5) {
          throw new HttpError(400, "Rating harus bilangan bulat 1 sampai 5");
        }

        const existing = await store.findLatest(ctx.userId);
        if (existing) await store.update(existing.id, kesan, saran, rating);
        else await store.insert(ctx.userId, kesan, saran, rating);

        return json(publicRow(await store.findLatest(ctx.userId)), existing ? 200 : 201);
      },
    },
  };
}
