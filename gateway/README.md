# Shared gateway (example)

A single Caddy instance that path-routes to multiple independently-deployed apps on the
same host, so they can eventually sit behind one domain instead of one port each.

`Caddyfile` here is a template with placeholder paths (`/app1`, `/app2`) and ports — copy
it, fill in your own app names/ports, and keep your filled-in version out of a public repo
(or in a private one), since it will name your actual internal services and hostnames.
`docker-compose.yml` and `deploy.sh` need no per-app changes.

Each app keeps its own independent deploy pipeline, database, and standalone port exactly
as before — this gateway only adds a routing layer in front of them. Nothing about an
individual app's own deploy changes because this exists.

## Deploying the gateway itself

```
./deploy.sh
```

Brings up Caddy on **host port 8888** (see the port 80/443 note in `docker-compose.yml`).
Verify: `curl http://localhost:8888/`, `curl http://localhost:8888/app1`, etc.

## The basePath requirement

A path-mounted app has to know it's mounted under that prefix, or its page loads but then
requests its own JS/CSS bundles from the wrong (root) path and 404s. This needs to be
solved per app, at build time:

- **Next.js**: `basePath` / `assetPrefix` config, typically driven by a build-time env var
  so the app's normal root-mounted deploy is unaffected and a path-mounted build is a
  second, separate image.
- **A client-side-routed SPA** (e.g. Vite + React Router): your bundler's `base` option,
  plus passing the equivalent value as your router's `basename` so client-side route
  matching agrees with where the app is actually mounted.

Until an app has this wired in and a path-mounted build has actually been produced and
deployed, routing a path prefix to its normal (unprefixed) deploy will load a page with
broken styling/JS — the gateway routing itself isn't the problem, the upstream just isn't
gateway-aware yet.

## Going live on a real domain

This gateway works today at `http://<this-host>:8888/`. Two more things are needed to make
it what your real domain actually resolves to, and both are infrastructure decisions for
whoever owns the server, not something to change silently:

1. **DNS**: point your domain at this host's public IP.
2. **Port 80/443**: if something else already answers on port 80 on this host, either move
   this gateway there and put the existing service behind it instead (e.g. at its own path
   or subdomain), or give this gateway a dedicated public IP/port and leave the existing
   service where it is.

Once both are settled, add HTTPS by changing the Caddyfile's `:80` block to
`yourdomain.com, www.yourdomain.com { ... }` (Caddy auto-provisions a Let's Encrypt cert
for real domains) and updating `docker-compose.yml`'s published ports to `80:80` / `443:443`.
