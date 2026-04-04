# Migration Catalog

Authoritative reference for migration types, strategies, risk profiles, detection signals, and conversion rules. Used by migration-analyzer, migration-planner, and migration-agent-generator agents.

---

## Migration Strategies

### Strangler Fig
- **How it works**: Gradually replace old code with new behind a router/proxy. Old code stays live until new is validated per-endpoint.
- **Best for**: API services, web apps, anything with clear routing boundaries. HIGH/CRITICAL risk migrations.
- **Coexistence**: Both old and new run simultaneously. Traffic routed by path/feature.
- **Rollback**: Re-route traffic back to old system.
- **Prompt**: "Which routing layer will you use? (nginx / API gateway / code-level / feature flags)"

### Parallel Run
- **How it works**: Run both old and new simultaneously, compare outputs. Catch discrepancies before switching.
- **Best for**: Data pipelines, financial systems, anything where correctness is critical.
- **Coexistence**: Both systems process same input. Outputs compared automatically.
- **Rollback**: Stop routing to new system.
- **Prompt**: "Where should output comparison happen? (CI pipeline / runtime shadow mode / offline batch)"

### Incremental (File-by-File)
- **How it works**: Convert one file at a time. Both versions coexist in the repo.
- **Best for**: Libraries, utilities, low-coupling codebases. JS→TS migrations.
- **Coexistence**: Mixed files in same codebase. Gradual type strictness.
- **Rollback**: Revert individual file conversions.
- **Prompt**: "Priority order? (tests first / leaf modules first / core modules first / most-changed files first)"

### Big Bang
- **How it works**: Rewrite everything at once. High risk, fast completion.
- **Best for**: Small projects, low-stakes code, or when old code is truly abandoned.
- **Coexistence**: None — old code replaced entirely.
- **Rollback**: Git revert to pre-migration branch.
- **Prompt**: "Are you sure? Big bang has no coexistence period. Confirm you have a stable branch to roll back to."

---

## Risk Thresholds

| Overall Score | Level    | Guidance |
|---------------|----------|----------|
| 0-30          | LOW      | Proceed with standard precautions |
| 31-60         | MEDIUM   | Recommend phased approach, extra testing |
| 61-80         | HIGH     | Recommend strangler fig, parallel run, feature flags |
| 81-100        | CRITICAL | Recommend pilot project first, explicit stakeholder sign-off |

---

## Language Migrations

### Python → Java
- **Typical Strategy**: strangler-fig (service-by-service)
- **Risk Baseline**: HIGH
- **Detection Signals**: `pyproject.toml` + `pom.xml`, `.py` + `.java` files coexisting
- **Key Challenges**: Dynamic typing → static typing, pip → maven, pytest → JUnit
- **Bridge Patterns**: REST API boundary, shared protobuf/OpenAPI, database as integration point
- **Conversion Rules**:
  - `dict` → `Map<K,V>` or POJO
  - `list comprehension` → `Stream.map().collect()`
  - `with` → try-with-resources
  - `**kwargs` → Builder pattern
  - `pytest` fixtures → JUnit `@BeforeEach`
  - `async def` → CompletableFuture or reactive
- **Test Approach**: Port tests first, then convert source to pass ported tests
- **Agent Config**: migration-converter (sonnet), migration-safety rule

### Python → TypeScript
- **Typical Strategy**: incremental or strangler-fig
- **Risk Baseline**: MEDIUM
- **Detection Signals**: `pyproject.toml` + `package.json`/`tsconfig.json`, `.py` + `.ts` coexisting
- **Key Challenges**: Dynamic typing → TypeScript types, different async model, different package ecosystem
- **Bridge Patterns**: REST/gRPC API boundary, shared OpenAPI spec
- **Conversion Rules**:
  - `dict` → `Record<string, T>` or interface
  - `list` → `Array<T>`
  - `None` → `null | undefined`
  - `async def` → `async function`
  - `pytest` → `vitest`/`jest`
  - `dataclass` → `interface` or `type`
  - `try/except` → `try/catch`
- **Test Approach**: Convert tests alongside source files
- **Agent Config**: migration-converter (sonnet), migration-safety rule

### JavaScript → TypeScript
- **Typical Strategy**: incremental (file-by-file, strict mode off initially)
- **Risk Baseline**: LOW
- **Detection Signals**: `tsconfig.json` + `.js`/`.jsx` files + `.ts`/`.tsx` files coexisting
- **Key Challenges**: Adding types to dynamic patterns, any-casting, third-party typings
- **Bridge Pattern**: `allowJs: true` in tsconfig, rename `.js` → `.ts` progressively
- **Conversion Rules**:
  - Add type annotations to function signatures
  - Replace `require()` with `import`
  - Add interfaces for object shapes
  - Convert `module.exports` to `export`
- **Test Approach**: Tests work as-is, add type checking to CI
- **Agent Config**: migration-converter (haiku — low complexity), ts-strictness rule

### Ruby → Go
- **Typical Strategy**: strangler-fig
- **Risk Baseline**: HIGH
- **Detection Signals**: `Gemfile` + `go.mod`, `.rb` + `.go` files coexisting
- **Key Challenges**: Dynamic → static typing, GC differences, concurrency model
- **Bridge Patterns**: REST API boundary, message queue
- **Conversion Rules**:
  - `class` → `struct` + methods
  - `module` → `package`
  - `block` → `func` parameter
  - `each` → `for range`
  - ActiveRecord → SQL or ORM (GORM/sqlx)
- **Agent Config**: migration-converter (sonnet)

### Java → Kotlin
- **Typical Strategy**: incremental (file-by-file)
- **Risk Baseline**: LOW
- **Detection Signals**: `.java` + `.kt` files coexisting, `build.gradle.kts`
- **Key Challenges**: Null safety, data classes, coroutines
- **Conversion Rules**:
  - POJO → `data class`
  - `Optional<T>` → nullable `T?`
  - `Stream` → Kotlin collections
  - Setter/getter → properties
- **Agent Config**: migration-converter (haiku)

---

## Framework Migrations

### Django → FastAPI
- **Typical Strategy**: strangler-fig (route-by-route)
- **Risk Baseline**: MEDIUM
- **Detection Signals**: Django + FastAPI imports coexisting
- **Key Challenges**: ORM (Django ORM → SQLAlchemy/Tortoise), middleware, auth, template → API-only
- **Bridge Pattern**: Django serves legacy routes, FastAPI serves new. Nginx routes by path prefix.
- **Conversion Rules**:
  - `@api_view` → `@app.get/post/put/delete`
  - Django ORM → SQLAlchemy models
  - `serializers.Serializer` → Pydantic model
  - `django.test.TestCase` → `pytest` + `httpx.AsyncClient`
- **Agent Config**: migration-converter (sonnet), coexistence rule

### Webpack → Vite
- **Typical Strategy**: big-bang (config replacement)
- **Risk Baseline**: LOW
- **Detection Signals**: `webpack.config.*` + `vite.config.*`
- **Key Challenges**: Loader → plugin mapping, dev server config, env variable handling
- **Conversion Rules**:
  - `module.rules` → Vite plugins
  - `webpack.DefinePlugin` → `define` in vite config
  - `devServer` → `server` in vite config
  - `require.context` → `import.meta.glob`
- **Agent Config**: migration-converter (haiku)

### Express → NestJS
- **Typical Strategy**: strangler-fig
- **Risk Baseline**: MEDIUM
- **Detection Signals**: Express + NestJS imports coexisting
- **Key Challenges**: Middleware, DI container, decorators, module system
- **Conversion Rules**:
  - `app.get()` → `@Get()` controller method
  - Middleware → NestJS middleware/guard/interceptor
  - Manual DI → `@Injectable()` + module providers
- **Agent Config**: migration-converter (sonnet)

### React Class → Functional Components
- **Typical Strategy**: incremental
- **Risk Baseline**: LOW
- **Detection Signals**: Both `class X extends Component` and `function X()` / arrow components
- **Conversion Rules**:
  - `componentDidMount` → `useEffect(..., [])`
  - `componentDidUpdate` → `useEffect(..., [deps])`
  - `this.state` → `useState`
  - `this.props` → function parameters
- **Agent Config**: migration-converter (haiku)

---

## Architecture Migrations

### Monolith → Microservices
- **Typical Strategy**: strangler-fig (extract bounded contexts)
- **Risk Baseline**: CRITICAL
- **Detection Signals**: Monolith app + `services/` directories, docker-compose with multiple services
- **Key Challenges**: Data decomposition, distributed transactions, service discovery, observability
- **Bridge Pattern**: Shared database initially, then event-driven data sync
- **Phase Template**:
  1. Identify bounded contexts (domain mapping)
  2. Add API boundaries within monolith (modular monolith)
  3. Extract first service (lowest coupling)
  4. Add inter-service communication
  5. Extract remaining services
  6. Decompose database
- **Agent Config**: service-extractor (sonnet), api-contract rule

### REST → GraphQL
- **Typical Strategy**: strangler-fig (endpoint-by-endpoint)
- **Risk Baseline**: MEDIUM
- **Detection Signals**: REST controllers + `.graphql` files or resolver imports
- **Key Challenges**: N+1 queries, auth in resolvers, caching strategy change
- **Conversion Rules**:
  - REST endpoint → GraphQL query/mutation
  - Response DTO → GraphQL type
  - Path params → query arguments
  - Pagination → cursor-based or relay-style
- **Agent Config**: migration-converter (sonnet)

---

## Cloud Migrations

### AWS → GCP
- **Typical Strategy**: parallel-run then cutover
- **Risk Baseline**: HIGH
- **Detection Signals**: AWS + GCP Terraform providers, dual SDK imports
- **Key Challenges**: Service mapping (S3→GCS, Lambda→Cloud Functions, RDS→Cloud SQL)
- **Conversion Rules**:
  - `aws_s3_bucket` → `google_storage_bucket`
  - `aws_lambda_function` → `google_cloudfunctions_function`
  - `aws_dynamodb_table` → `google_bigtable_table` or Firestore
  - IAM policy format differences
- **Agent Config**: migration-infra (sonnet), cloud-safety rule

### AWS → Azure
- **Typical Strategy**: parallel-run then cutover
- **Risk Baseline**: HIGH
- **Detection Signals**: AWS + Azure Terraform providers
- **Key Challenges**: Service mapping, identity model (IAM→RBAC), networking
- **Conversion Rules**:
  - `aws_s3_bucket` → `azurerm_storage_container`
  - `aws_lambda_function` → `azurerm_function_app`
  - `aws_rds_instance` → `azurerm_postgresql_server`
- **Agent Config**: migration-infra (sonnet)

### Heroku → Cloud IaC
- **Typical Strategy**: incremental
- **Risk Baseline**: MEDIUM
- **Detection Signals**: `Procfile` + `.tf` files
- **Conversion Rules**:
  - `Procfile` → Dockerfile + deployment manifest
  - Heroku addons → managed cloud services
  - Heroku config vars → environment/secrets management
- **Agent Config**: migration-infra (sonnet)

---

## DevOps Migrations

### GitLab CI → GitHub Actions
- **Typical Strategy**: parallel-run (both CIs run during transition)
- **Risk Baseline**: MEDIUM
- **Detection Signals**: `.gitlab-ci.yml` + `.github/workflows/`
- **Conversion Rules**:
  - `stages:` → `jobs:` with `needs:`
  - `image:` → `runs-on:` + `container:`
  - `services:` → `services:` (same concept)
  - `variables:` → `env:` or `${{ secrets.X }}`
  - `artifacts: paths:` → `actions/upload-artifact@v4`
  - `cache: paths:` → `actions/cache@v4`
  - `rules: - if:` → `on:` triggers + `if:` conditions
  - `include: - template:` → reusable workflow
  - `environment:` → GitHub Environments
- **Agent Config**: migration-ci-converter (sonnet)

### CircleCI → GitHub Actions
- **Typical Strategy**: parallel-run
- **Risk Baseline**: MEDIUM
- **Detection Signals**: `.circleci/config.yml` + `.github/workflows/`
- **Conversion Rules**:
  - `jobs:` → GitHub Actions `jobs:`
  - `orbs:` → GitHub Actions from marketplace
  - `executors:` → `runs-on:` + `container:`
  - `workflows:` → separate workflow files or job dependencies
- **Agent Config**: migration-ci-converter (sonnet)

### Jenkins → GitHub Actions
- **Typical Strategy**: parallel-run
- **Risk Baseline**: MEDIUM
- **Detection Signals**: `Jenkinsfile` + `.github/workflows/`
- **Conversion Rules**:
  - `pipeline { stages { ... } }` → workflow jobs
  - `agent { docker { image } }` → `container:`
  - `environment { ... }` → `env:` block
  - `post { always/success/failure }` → `if: always()` / job status checks
- **Agent Config**: migration-ci-converter (sonnet)

---

## Infrastructure Migrations

### Docker Compose → Kubernetes
- **Typical Strategy**: incremental (service-by-service)
- **Risk Baseline**: MEDIUM-HIGH
- **Detection Signals**: `docker-compose.yml` + `kubernetes/` or `Chart.yaml`
- **Conversion Rules**:
  - `services:` → Deployment + Service manifests
  - `volumes:` → PersistentVolumeClaim
  - `ports:` → Service `spec.ports`
  - `environment:` → ConfigMap or Secret
  - `depends_on:` → init containers or readiness probes
  - `networks:` → NetworkPolicy
- **Agent Config**: migration-infra (sonnet)

### VM → Containers
- **Typical Strategy**: incremental
- **Risk Baseline**: MEDIUM
- **Detection Signals**: Ansible/Chef/Puppet configs + Dockerfile
- **Conversion Rules**:
  - Provisioning scripts → Dockerfile stages
  - Config management → container env vars + ConfigMap
  - Service management → container orchestration
- **Agent Config**: migration-infra (sonnet)

---

## Toolchain Migrations

### npm → pnpm
- **Typical Strategy**: big-bang
- **Risk Baseline**: LOW
- **Detection Signals**: `package-lock.json` + `pnpm-lock.yaml`
- **Conversion Rules**:
  - Delete `package-lock.json`, run `pnpm import` then `pnpm install`
  - Update CI to use `pnpm`
  - Update scripts from `npm run` to `pnpm`
- **Agent Config**: minimal — rule only

### Grunt/Gulp → Modern Bundler
- **Typical Strategy**: big-bang
- **Risk Baseline**: LOW
- **Detection Signals**: `Gruntfile*` or `gulpfile*` + modern bundler config
- **Conversion Rules**:
  - Task → build script or plugin
  - Watch → dev server HMR
  - Concat/minify → bundler built-in
- **Agent Config**: migration-converter (haiku)

---

## AI Tool Migrations

### Cursor-only → Multi-tool
- **Typical Strategy**: incremental
- **Risk Baseline**: LOW
- **Detection Signals**: `.cursor/` without `.claude/` or `CLAUDE.md`
- **Conversion Approach**: Run standard `/scaffold` to generate Claude Code + Codex setup alongside Cursor
- **Agent Config**: none needed — standard scaffold handles this

### No AI → AI-assisted
- **Typical Strategy**: big-bang
- **Risk Baseline**: LOW
- **Detection Signals**: No `.cursor/`, `.claude/`, or `CLAUDE.md`
- **Conversion Approach**: Run standard `/scaffold` for full AI setup
- **Agent Config**: none needed — standard scaffold handles this
