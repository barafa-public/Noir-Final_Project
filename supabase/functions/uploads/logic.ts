import { HttpError, json } from "../_shared/http.ts";
import type { Route } from "../_shared/router.ts";
import { str } from "../_shared/validate.ts";

export const MAX_AVATAR_BYTES = 1_048_576; // 1 MB setelah didekode
export const MAX_AVATAR_BASE64_CHARS = Math.ceil(MAX_AVATAR_BYTES / 3) * 4 + 8;

export interface UploadsStore {
  getAvatarPath(userId: number): Promise<string | null>;
  setAvatarPath(userId: number, path: string): Promise<void>;
  putAvatar(path: string, bytes: Uint8Array, contentType: string): Promise<void>;
  removeAvatar(path: string): Promise<void>;
  signAvatar(path: string): Promise<string | null>;
}

export interface ImageType {
  mime: string;
  ext: string;
}

const ascii = (b: Uint8Array, from: number, to: number) =>
  String.fromCharCode(...b.slice(from, to));

/** Jenis gambar ditentukan dari ISI file (magic bytes), bukan dari klaim klien. */
export function detectImageType(b: Uint8Array): ImageType | null {
  if (b.length >= 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) {
    return { mime: "image/jpeg", ext: "jpg" };
  }
  const png = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (b.length >= 8 && png.every((v, i) => b[i] === v)) {
    return { mime: "image/png", ext: "png" };
  }
  if (b.length >= 12 && ascii(b, 0, 4) === "RIFF" && ascii(b, 8, 12) === "WEBP") {
    return { mime: "image/webp", ext: "webp" };
  }
  return null;
}

export function decodeBase64(s: string): Uint8Array | null {
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(s) || s.length % 4 !== 0) return null;
  try {
    return Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
  } catch {
    return null;
  }
}

export function createUploadsRoutes(
  store: UploadsStore,
  now: () => number = () => Date.now(),
): Record<string, Route> {
  return {
    avatar: {
      handle: async (ctx, body) => {
        const b64 = str(body.image_base64);
        if (!b64) throw new HttpError(400, "Gambar wajib dikirim");
        if (b64.length > MAX_AVATAR_BASE64_CHARS) {
          throw new HttpError(413, "Ukuran foto maksimal 1 MB");
        }
        const bytes = decodeBase64(b64);
        if (!bytes) throw new HttpError(400, "Data gambar tidak valid");
        if (bytes.length > MAX_AVATAR_BYTES) throw new HttpError(413, "Ukuran foto maksimal 1 MB");

        const type = detectImageType(bytes);
        if (!type) throw new HttpError(400, "Format foto harus JPG, PNG, atau WebP");

        // Folder = id pemilik token. Klien tidak bisa memilih lokasi simpan.
        const path = `${ctx.userId}/avatar-${now()}.${type.ext}`;
        const oldPath = await store.getAvatarPath(ctx.userId);

        await store.putAvatar(path, bytes, type.mime);
        try {
          await store.setAvatarPath(ctx.userId, path);
        } catch (e) {
          await store.removeAvatar(path).catch(() => {}); // jangan tinggalkan file yatim
          throw e;
        }
        if (oldPath) await store.removeAvatar(oldPath).catch(() => {}); // foto lama, best-effort

        return json({ foto_url: await store.signAvatar(path) });
      },
    },
  };
}
