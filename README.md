# **Tech Maturity**

----

## What is Tech Maturity?
Tech Maturity is a portal that measures the engineering maturity of software
products. It helps teams find growth opportunities, set clearly defined targets,
and track progress over time toward continuous delivery and operational
excellence.

Every asset is assessed against **two maturity models in a single process**:

- **Tech Maturity** — build-time engineering quality across *Code, Build & Test,
  Release, Operate,* and *Optimize*.
- **SRE Maturity** — run-time reliability across *SLOs & Error Budgets,
  Monitoring & Observability, Incident Response, Learning & Postmortems,* and
  *Toil & Reliability Engineering* (mapped to Google's SRE practices).

Each capability is scored 1–4 against a rubric, so a product carries a Tech score
*and* an SRE score, produced together. The dashboard aggregates scores across all
assessed assets so an organization can see its overall maturity at a glance. The
models don't prescribe solutions — they offer standards that give teams a clear
path toward efficient product development at scale, and can be tailored to your
needs by editing the framework definition files (see *Maturity models* below).

----
## Try it out!
1. [Get Docker](https://www.docker.com/get-docker)
2. run `docker compose up` (or `docker-compose up` on older Docker)
3. open `http://localhost:8080` in your web browser 🚀

On startup the container creates and migrates the database and seeds the maturity
model definitions automatically — there's nothing else to set up. Use the **Data**
page (enabled outside production) to load demo assets, or add your own from the UI.

----
## Assess a repository (optional AI)
When adding a score you can point the assessor at a **repository** (a local path
or a git URL) and it will pre-fill the capabilities it can detect:

- **File detectors** infer a baseline from signals in the source (a test suite, a
  CI config, a Dockerfile, dependency lockfiles, Prometheus/Grafana config, etc.).
- **LLM analysis** (optional) reads the *whole* repo — chunked and scored
  map-reduce style against each model's rubric — to grade the deeper capabilities
  detectors can't see (code-commenting strategy, code reuse, quality engineering,
  …). It runs as a **background job** with a live progress bar, then drops you into
  the pre-filled review form.

The AI pass is **off unless configured**, and the app degrades gracefully to the
file detectors without it. To enable it, create a `.env` file (gitignored) in the
project root:

```
OR_DELPHI_API_KEY=sk-or-...        # OpenRouter API key
AI_ANALYSIS_MODEL=qwen/qwen3-coder-next   # optional; this is the default
```

`docker compose` loads `.env` automatically. The repo URL is **not** filtered —
any reachable git URL (including internal hosts) is accepted.

----
## Configuration
Feature flags live in `config/application.yml` per environment and are read into
the `CONFIGS` hash:

| Flag | Default (dev) | What it gates |
| --- | --- | --- |
| `enable_repo_assessment` | on | the "Assess from repository" flow |
| `enable_ai_analysis` | on (needs key) | the LLM analysis pass (off in test) |
| `enable_data_management` | on | the demo-data / PIN-gated DB-reset page |

All three default **off in production** — enable them explicitly (and set a strong
`RESET_PIN`) only on trusted deployments.

----
## Maturity models
Framework definitions are reference data, seeded idempotently on every boot
(`FrameworkSeeder`, via `db/seed`). To change a model, edit its source and restart
— the seeder reconciles the database to the files (including removing capabilities
you delete):

- **Tech**: `app/assets/constants/capabilities.yaml` (+ `formatted_capabilities.yaml`)
- **SRE**: `db/frameworks/sre.yml`

----
## Running the tests
The app targets **Ruby 3.3.6** and **Rails 7.2**. The simplest way to run the
suite is inside the container (the image bundles headless Chromium for the system
tests):

```
docker compose run --rm -e RAILS_ENV=test -e DISABLE_SPRING=1 techmaturity \
  sh -c "bin/rails db:prepare && bin/rails test && bin/rails test:system"
```

- `bin/rails test` — model, controller/integration, job, and service tests
  (the LLM pass is stubbed off in test, so the suite never makes network calls).
- `bin/rails test:system` — Capybara/Selenium system tests in headless Chromium
  (multi-step score form, dashboard + score charts, live product search, asset
  actions).

Coverage spans the combined Tech+SRE assessment flow, the repo file-detectors and
the chunked LLM analyzer's logic, the background scan job + model, framework
seeding/pruning, and the charts.

To run locally instead of in Docker you need Ruby 3.3.6, a Postgres instance, and
Chromium on your `PATH`; then `bundle install` and the same `bin/rails` commands.

----
## Contribution
1. Branch from `main`
2. Make your change with tests
3. Open a pull request
