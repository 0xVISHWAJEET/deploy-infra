# Shared gateway

A single Caddy instance that path-routes to every project on this box, so they can
eventually all sit behind one domain instead of five separate ports:

| Path | Project | Upstream |
|---|---|---|
| `/` | aspirez (flagship site) | `host.docker.internal:8080` |
| `/land*` | land-registry-chain | `host.docker.internal:3082` (gateway-flavored build, see below) |
| `/media*` | media-ops | `host.docker.internal:8083` |
| `/jan-score*` | jan-score | `host.docker.internal:8081` |
| `/identity*` | p-iden | `host.docker.internal:8084` |

Each project keeps its own independent deploy pipeline, database, and standalone port
exactly as before — this gateway only adds a routing layer in front of them. Nothing about
an individual project's own deploy changes because this exists.

## Deploying the gateway itself

```
./deploy.sh
```

Brings up Caddy on **host port 8888** (deliberately not 80/443 — see "Going live" below).
Verify: `curl http://localhost:8888/`, `curl http://localhost:8888/land`, etc.

## The basePath requirement (why /media, /jan-score, /identity aren't finished yet)

A path-mounted app has to know it's mounted under that prefix, or its page loads but then
requests its own JS/CSS bundles from the wrong (root) path and 404s. Every affected
frontend already has this wired in as a build-time toggle, defaulting off (their normal
standalone deploy is completely unaffected):

- **land-registry-chain** (Next.js): `NEXT_PUBLIC_BASE_PATH` build arg in
  `frontend/Dockerfile` / `next.config.js`. **Done** — a gateway build (`/land`) exists and
  is deployed on port 3082 via `land-registry-chain/scripts/deploy-gateway-frontend.sh`.
- **media-ops** (Next.js): same pattern, `frontend/next.config.js`. Code is ready; no
  gateway-flavored image has been built/deployed yet.
- **jan-score** (Next.js): same pattern, `next.config.ts`. Code is ready; no gateway-flavored
  image has been built/deployed yet.
- **p-iden** (Vite/React, client-side routed): `VITE_BASE_PATH` build arg +
  `BrowserRouter basename` in `frontend/src/main.tsx`. Code is ready; no gateway-flavored
  build has been produced yet.

To finish one of the remaining three: build that project's frontend image with the
relevant base-path build arg set (mirroring `deploy-gateway-frontend.sh`'s pattern), run it
as its own container published on a free host port, and point this Caddyfile's matching
`handle` block at that port instead of the project's existing unprefixed one. Until that's
done, hitting `/media`, `/jan-score`, or `/identity` here will load a page with broken
styling/JS — the routing is correct, the upstream just isn't gateway-aware yet.

## Going live on aspireztech.com

This gateway is real and fully working today at `http://<this-host>:8888/`. Two things are
still needed to make it the thing `aspireztech.com` actually resolves to, and both are
infrastructure decisions for whoever owns this server, not something to change silently:

1. **DNS**: point `aspireztech.com` (and ideally `www.aspireztech.com`) at this host's
   public IP.
2. **Port 80/443**: this host's port 80 is currently serving an unrelated existing site
   (Nextcloud). Port 443 is unclaimed. To let this gateway answer on the real ports, either:
   - move this gateway to 80/443 and put Nextcloud behind it instead (e.g. at a path or
     subdomain of its own), or
   - give this gateway a dedicated public IP/port and leave Nextcloud where it is.

   Either is a reasonable choice; this repo doesn't make it for you.

Once both are settled, add HTTPS by changing the Caddyfile's `:80` block to
`aspireztech.com, www.aspireztech.com { ... }` (Caddy auto-provisions a Let's Encrypt
cert for real domains) and updating `docker-compose.yml`'s published ports to `80:80` /
`443:443`.
