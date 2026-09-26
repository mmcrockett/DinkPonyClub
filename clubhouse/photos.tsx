import { leagueFetch } from "./request";
("use client");
import { useEffect, useState, FormEvent } from "react";
import {
  Dialog,
  DialogContent,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
type Photo = {
  id: string;
  author: string;
  caption: string;
  createdAt: string;
  canDelete: boolean;
};
export default function Photos() {
  const [photos, setPhotos] = useState<Photo[]>([]),
    [next, setNext] = useState<number | null>(null),
    [file, setFile] = useState<File | null>(null),
    [caption, setCaption] = useState(""),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false),
    [loading, setLoading] = useState(true),
    [view, setView] = useState<Photo | null>(null),
    [remove, setRemove] = useState<Photo | null>(null),
    [inputKey, setInputKey] = useState(0);
  async function load(offset = 0) {
    setLoading(true);
    try {
      const r = await leagueFetch("/clubhouse/api/photos?offset=" + offset),
        d: any = await r.json();
      if (!r.ok) throw Error(d.error);
      setPhotos((old) => (offset ? [...old, ...d.photos] : d.photos));
      setNext(d.nextOffset);
      setError("");
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
  }
  useEffect(() => {
    load();
  }, []);
  async function upload(e: FormEvent) {
    e.preventDefault();
    if (!file) return;
    setBusy(true);
    setError("");
    try {
      if (!["image/jpeg", "image/png", "image/webp"].includes(file.type))
        throw Error(
          "Choose a JPEG, PNG, or WebP photo. Export HEIC photos as JPEG first.",
        );
      if (file.size > 30 * 1024 * 1024)
        throw Error("Choose a photo smaller than 30 MB.");
      const bitmap = await createImageBitmap(file),
        scale = Math.min(1, 2400 / Math.max(bitmap.width, bitmap.height)),
        canvas = document.createElement("canvas");
      canvas.width = Math.round(bitmap.width * scale);
      canvas.height = Math.round(bitmap.height * scale);
      const ctx = canvas.getContext("2d");
      if (!ctx) throw Error("Your browser could not prepare this photo.");
      ctx.fillStyle = "#fff";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
      bitmap.close();
      const blob = await new Promise<Blob>((resolve, reject) =>
        canvas.toBlob(
          (b) => (b ? resolve(b) : reject(Error("Could not prepare photo."))),
          "image/jpeg",
          0.88,
        ),
      );
      const data = new FormData();
      data.append("photo", blob, "league-photo.jpg");
      data.append("caption", caption);
      const r = await leagueFetch("/clubhouse/api/photos", {
          method: "POST",
          body: data,
        }),
        result: any = await r.json();
      if (!r.ok) throw Error(result.error);
      setFile(null);
      setCaption("");
      setInputKey((k) => k + 1);
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  async function deletePhoto() {
    if (!remove) return;
    setBusy(true);
    try {
      const r = await leagueFetch("/clubhouse/api/photos?id=" + remove.id, {
          method: "DELETE",
        }),
        d: any = await r.json();
      if (!r.ok) throw Error(d.error);
      setRemove(null);
      setView(null);
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <section>
      <div className="section-heading">
        <div>
          <h2>From the courts.</h2>
          <p>Share league photos with fellow members.</p>
        </div>
      </div>
      <form className="info-panel photo-upload" onSubmit={upload}>
        <label className="field">
          Photo
          <input
            key={inputKey}
            type="file"
            accept="image/jpeg,image/png,image/webp"
            required
            disabled={busy}
            onChange={(e) => setFile(e.target.files?.[0] || null)}
          />
        </label>
        <label className="field">
          Caption (optional)
          <input
            value={caption}
            maxLength={500}
            disabled={busy}
            onChange={(e) => setCaption(e.target.value)}
            placeholder="A great night on the courts…"
          />
        </label>
        <p className="muted">
          JPEG, PNG, or WebP, up to 30 MB. Photos are resized for the gallery
          and location metadata is removed.
        </p>
        <button className="primary" disabled={busy || !file}>
          {busy ? "Saving…" : "Upload photo"}
        </button>
      </form>
      {error && (
        <div className="error-banner" role="alert">
          {error}{" "}
          <button onClick={() => load()} disabled={busy}>
            Refresh gallery
          </button>
        </div>
      )}
      <div className="photo-grid">
        {photos.map((p) => (
          <article className="photo-card" key={p.id}>
            <button
              className="photo-image"
              onClick={() => setView(p)}
              aria-label={"View photo: " + (p.caption || "by " + p.author)}
            >
              <img
                src={"/clubhouse/api/photos?image=" + p.id}
                alt={p.caption || "League photo by " + p.author}
                loading="lazy"
              />
            </button>
            <div>
              <p>{p.caption}</p>
              <span className="muted">
                {p.author} · {new Date(p.createdAt).toLocaleDateString()}
              </span>
              {p.canDelete && (
                <button
                  className="text-button"
                  disabled={busy}
                  onClick={() => setRemove(p)}
                >
                  Delete
                </button>
              )}
            </div>
          </article>
        ))}
      </div>
      {loading ? (
        <p role="status">Loading photos…</p>
      ) : !photos.length && !error ? (
        <div className="empty">
          No photos yet. Share the first one from the courts.
        </div>
      ) : null}
      {next !== null && (
        <button
          className="secondary"
          disabled={loading || busy}
          onClick={() => load(next)}
        >
          Load more photos
        </button>
      )}
      <Dialog open={!!view} onOpenChange={(v) => !v && setView(null)}>
        <DialogContent className="photo-dialog">
          <DialogTitle>{view?.caption || "League photo"}</DialogTitle>
          <DialogDescription>Shared by {view?.author}</DialogDescription>
          {view && (
            <img
              src={"/clubhouse/api/photos?image=" + view.id}
              alt={view.caption || "League photo"}
            />
          )}
        </DialogContent>
      </Dialog>
      <Dialog
        open={!!remove}
        onOpenChange={(v) => !v && !busy && setRemove(null)}
      >
        <DialogContent>
          <DialogTitle>Delete this photo?</DialogTitle>
          <DialogDescription>
            This removes it from the league gallery.
          </DialogDescription>
          <div className="dialog-actions">
            <button
              className="secondary"
              disabled={busy}
              onClick={() => setRemove(null)}
            >
              Keep photo
            </button>
            <button className="primary" disabled={busy} onClick={deletePhoto}>
              {busy ? "Deleting…" : "Delete photo"}
            </button>
          </div>
        </DialogContent>
      </Dialog>
    </section>
  );
}
