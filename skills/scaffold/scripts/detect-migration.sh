#!/bin/bash
# Cortex migration signal scanner
# Detects migration signals across 8 categories by analyzing file coexistence,
# comment markers, and config patterns. Outputs MigrationSignals JSON.
# No external dependencies required — pure shell

set -euo pipefail

REPO_DIR="${1:-.}"

# Normalize path
REPO_DIR="$(cd "$REPO_DIR" && pwd)"

# ── Helpers ──────────────────────────────────────────────────────────

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"    # backslashes first
  s="${s//\"/\\\"}"    # double quotes
  s="${s//$'\t'/\\t}"  # tabs
  s="${s//$'\n'/\\n}"  # newlines
  s="${s//$'\r'/\\r}"  # carriage returns
  printf '%s' "$s"
}

count_files() {
  local pattern="$1"
  find "$REPO_DIR" -name "$pattern" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/vendor/*" -not -path "*/dist/*" -not -path "*/__pycache__/*" -not -path "*/target/*" 2>/dev/null | wc -l | tr -d ' '
}

file_exists() {
  local pattern="$1"
  find "$REPO_DIR" -maxdepth 3 -name "$pattern" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -1
}

grep_count() {
  local pattern="$1"
  grep -r "$pattern" "$REPO_DIR" --include="*.py" --include="*.js" --include="*.ts" --include="*.java" --include="*.go" --include="*.rb" --include="*.rs" --include="*.yml" --include="*.yaml" --include="*.md" --include="*.tsx" --include="*.jsx" -l 2>/dev/null | grep -v node_modules | grep -v .git | wc -l | tr -d ' '
}

json_array_from_files() {
  local files="$1"
  local first=true
  echo -n "["
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    local rel="${f#$REPO_DIR/}"
    rel=$(json_escape "$rel")
    if [ "$first" = true ]; then
      first=false
    else
      echo -n ", "
    fi
    echo -n "\"$rel\""
  done <<< "$files"
  echo -n "]"
}

# ── Category 1: Language Migration ───────────────────────────────────

detect_language_migrations() {
  local migrations=""

  # Python + Java coexistence
  local py_count=$(count_files "*.py")
  local java_count=$(count_files "*.java")
  if [ "$py_count" -gt 3 ] && [ "$java_count" -gt 3 ]; then
    local pom=$(file_exists "pom.xml")
    local pyproj=$(file_exists "pyproject.toml")
    local conf=0.6
    [ -n "$pom" ] && [ -n "$pyproj" ] && conf=0.85
    local detail=$(json_escape "$py_count .py files + $java_count .java files")
    migrations="${migrations}{\"category\":\"language\",\"from\":\"Python\",\"to\":\"Java\",\"confidence\":$conf,\"signals\":[{\"type\":\"file_coexistence\",\"detail\":\"$detail\"}]},"
  fi

  # Python + TypeScript coexistence
  local ts_count=$(count_files "*.ts")
  local tsx_count=$(count_files "*.tsx")
  local total_ts=$((ts_count + tsx_count))
  if [ "$py_count" -gt 3 ] && [ "$total_ts" -gt 3 ]; then
    local conf=0.5
    local pkg=$(file_exists "package.json")
    local pyproj=$(file_exists "pyproject.toml")
    [ -n "$pkg" ] && [ -n "$pyproj" ] && conf=0.7
    local detail=$(json_escape "$py_count .py files + $total_ts .ts/.tsx files")
    migrations="${migrations}{\"category\":\"language\",\"from\":\"Python\",\"to\":\"TypeScript\",\"confidence\":$conf,\"signals\":[{\"type\":\"file_coexistence\",\"detail\":\"$detail\"}]},"
  fi

  # JavaScript → TypeScript
  local js_count=$(count_files "*.js")
  local jsx_count=$(count_files "*.jsx")
  local total_js=$((js_count + jsx_count))
  local tsconfig=$(file_exists "tsconfig.json")
  if [ "$total_js" -gt 5 ] && [ "$total_ts" -gt 5 ] && [ -n "$tsconfig" ]; then
    local detail=$(json_escape "$total_js .js/.jsx + $total_ts .ts/.tsx with tsconfig.json")
    migrations="${migrations}{\"category\":\"language\",\"from\":\"JavaScript\",\"to\":\"TypeScript\",\"confidence\":0.80,\"signals\":[{\"type\":\"file_coexistence\",\"detail\":\"$detail\"}]},"
  fi

  # Ruby + Go coexistence (catalog signals: Gemfile + go.mod)
  local rb_count=$(count_files "*.rb")
  local go_count=$(count_files "*.go")
  if [ "$rb_count" -gt 3 ] && [ "$go_count" -gt 3 ]; then
    local conf=0.60
    local gemfile=$(file_exists "Gemfile")
    local gomod=$(file_exists "go.mod")
    [ -n "$gemfile" ] && [ -n "$gomod" ] && conf=0.85
    local detail=$(json_escape "$rb_count .rb files + $go_count .go files")
    migrations="${migrations}{\"category\":\"language\",\"from\":\"Ruby\",\"to\":\"Go\",\"confidence\":$conf,\"signals\":[{\"type\":\"file_coexistence\",\"detail\":\"$detail\"}]},"
  fi

  echo "$migrations"
}

# ── Category 2: Framework Migration ──────────────────────────────────

detect_framework_migrations() {
  local migrations=""

  # Webpack → Vite
  local webpack=$(file_exists "webpack.config.*")
  local vite=$(file_exists "vite.config.*")
  if [ -n "$webpack" ] && [ -n "$vite" ]; then
    migrations="${migrations}{\"category\":\"framework\",\"from\":\"Webpack\",\"to\":\"Vite\",\"confidence\":0.90,\"signals\":[{\"type\":\"config_coexistence\",\"detail\":\"webpack.config.* + vite.config.*\"}]},"
  fi

  # Django → FastAPI
  local django_imports=$(grep_count "from django\|import django")
  local fastapi_imports=$(grep_count "from fastapi\|import fastapi")
  if [ "$django_imports" -gt 0 ] && [ "$fastapi_imports" -gt 0 ]; then
    local detail=$(json_escape "Django imports ($django_imports files) + FastAPI imports ($fastapi_imports files)")
    migrations="${migrations}{\"category\":\"framework\",\"from\":\"Django\",\"to\":\"FastAPI\",\"confidence\":0.75,\"signals\":[{\"type\":\"import_coexistence\",\"detail\":\"$detail\"}]},"
  fi

  # Create React App → Vite/Next
  local cra=$(file_exists "react-scripts")
  if [ -n "$vite" ] && [ -n "$cra" ]; then
    migrations="${migrations}{\"category\":\"framework\",\"from\":\"CRA\",\"to\":\"Vite\",\"confidence\":0.80,\"signals\":[{\"type\":\"config_coexistence\",\"detail\":\"react-scripts + vite.config\"}]},"
  fi

  # Express → Fastify or Nest
  local express_imports=$(grep_count "require.*express\|from.*express")
  local fastify_imports=$(grep_count "require.*fastify\|from.*fastify")
  local nest_imports=$(grep_count "from.*@nestjs")
  if [ "$express_imports" -gt 0 ] && [ "$fastify_imports" -gt 0 ]; then
    migrations="${migrations}{\"category\":\"framework\",\"from\":\"Express\",\"to\":\"Fastify\",\"confidence\":0.70,\"signals\":[{\"type\":\"import_coexistence\",\"detail\":\"Express + Fastify imports\"}]},"
  fi
  if [ "$express_imports" -gt 0 ] && [ "$nest_imports" -gt 0 ]; then
    migrations="${migrations}{\"category\":\"framework\",\"from\":\"Express\",\"to\":\"NestJS\",\"confidence\":0.65,\"signals\":[{\"type\":\"import_coexistence\",\"detail\":\"Express + NestJS imports\"}]},"
  fi

  echo "$migrations"
}

# ── Category 3: Architecture Migration ───────────────────────────────

detect_architecture_migrations() {
  local migrations=""

  # Monolith → Microservices (service directories appearing alongside monolith)
  local services_dir=$(find "$REPO_DIR" -maxdepth 2 -type d -name "services" 2>/dev/null | head -1)
  local docker_compose=$(file_exists "docker-compose*.yml")
  local models_count=$(count_files "*.model.*")
  if [ -n "$services_dir" ] && [ -n "$docker_compose" ]; then
    local svc_count=$(find "$services_dir" -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    if [ "$svc_count" -gt 2 ]; then
      local detail=$(json_escape "services/ dir with $svc_count subdirs + docker-compose")
      migrations="${migrations}{\"category\":\"architecture\",\"from\":\"monolith\",\"to\":\"microservices\",\"confidence\":0.65,\"signals\":[{\"type\":\"structure\",\"detail\":\"$detail\"}]},"
    fi
  fi

  # REST → GraphQL
  local rest_routes=$(grep_count "app\.\(get\|post\|put\|delete\|patch\)\|@GetMapping\|@PostMapping\|@app\.route")
  local graphql_files=$(count_files "*.graphql")
  local graphql_resolvers=$(grep_count "resolver\|@Resolver\|graphql")
  if [ "$rest_routes" -gt 3 ] && [ "$graphql_files" -gt 0 ]; then
    migrations="${migrations}{\"category\":\"architecture\",\"from\":\"REST\",\"to\":\"GraphQL\",\"confidence\":0.70,\"signals\":[{\"type\":\"pattern_coexistence\",\"detail\":\"REST routes + .graphql files\"}]},"
  fi

  echo "$migrations"
}

# ── Category 4: Cloud Migration ──────────────────────────────────────

detect_cloud_migrations() {
  local migrations=""

  # AWS → GCP / Azure (Terraform with multiple providers)
  local aws_tf=$(grep_count "provider.*aws\|aws_")
  local gcp_tf=$(grep_count "provider.*google\|google_")
  local azure_tf=$(grep_count "provider.*azurerm\|azurerm_")
  if [ "$aws_tf" -gt 0 ] && [ "$gcp_tf" -gt 0 ]; then
    local detail=$(json_escape "AWS ($aws_tf refs) + GCP ($gcp_tf refs) in Terraform")
    migrations="${migrations}{\"category\":\"cloud\",\"from\":\"AWS\",\"to\":\"GCP\",\"confidence\":0.75,\"signals\":[{\"type\":\"iac_coexistence\",\"detail\":\"$detail\"}]},"
  fi
  if [ "$aws_tf" -gt 0 ] && [ "$azure_tf" -gt 0 ]; then
    local detail=$(json_escape "AWS ($aws_tf refs) + Azure ($azure_tf refs) in Terraform")
    migrations="${migrations}{\"category\":\"cloud\",\"from\":\"AWS\",\"to\":\"Azure\",\"confidence\":0.75,\"signals\":[{\"type\":\"iac_coexistence\",\"detail\":\"$detail\"}]},"
  fi

  echo "$migrations"
}

# ── Category 5: DevOps/CI Migration ──────────────────────────────────

detect_devops_migrations() {
  local migrations=""

  # GitLab CI → GitHub Actions
  local gitlab=$(file_exists ".gitlab-ci.yml")
  local github_wf=$(find "$REPO_DIR/.github/workflows" -name "*.yml" -o -name "*.yaml" 2>/dev/null | head -1)
  if [ -n "$gitlab" ] && [ -n "$github_wf" ]; then
    migrations="${migrations}{\"category\":\"devops\",\"from\":\"GitLab CI\",\"to\":\"GitHub Actions\",\"confidence\":0.90,\"signals\":[{\"type\":\"config_coexistence\",\"detail\":\".gitlab-ci.yml + .github/workflows/\"}]},"
  fi

  # CircleCI → GitHub Actions
  local circleci=$(file_exists "config.yml")
  local circleci_dir=$(find "$REPO_DIR/.circleci" -maxdepth 0 -type d 2>/dev/null | head -1)
  if [ -n "$circleci_dir" ] && [ -n "$github_wf" ]; then
    migrations="${migrations}{\"category\":\"devops\",\"from\":\"CircleCI\",\"to\":\"GitHub Actions\",\"confidence\":0.85,\"signals\":[{\"type\":\"config_coexistence\",\"detail\":\".circleci/ + .github/workflows/\"}]},"
  fi

  # Jenkins → GitHub Actions
  local jenkinsfile=$(file_exists "Jenkinsfile")
  if [ -n "$jenkinsfile" ] && [ -n "$github_wf" ]; then
    migrations="${migrations}{\"category\":\"devops\",\"from\":\"Jenkins\",\"to\":\"GitHub Actions\",\"confidence\":0.80,\"signals\":[{\"type\":\"config_coexistence\",\"detail\":\"Jenkinsfile + .github/workflows/\"}]},"
  fi

  echo "$migrations"
}

# ── Category 6: Infrastructure Migration ─────────────────────────────

detect_infra_migrations() {
  local migrations=""

  # Docker Compose → Kubernetes
  local compose=$(file_exists "docker-compose*.yml")
  local k8s_dir=$(find "$REPO_DIR" -maxdepth 2 -type d \( -name "kubernetes" -o -name "k8s" \) 2>/dev/null | head -1)
  local helm=$(file_exists "Chart.yaml")
  if [ -n "$compose" ] && { [ -n "$k8s_dir" ] || [ -n "$helm" ]; }; then
    migrations="${migrations}{\"category\":\"infrastructure\",\"from\":\"Docker Compose\",\"to\":\"Kubernetes\",\"confidence\":0.80,\"signals\":[{\"type\":\"config_coexistence\",\"detail\":\"docker-compose + kubernetes manifests\"}]},"
  fi

  # Heroku → AWS/GCP (Procfile + Terraform/CDK)
  local procfile=$(file_exists "Procfile")
  local terraform=$(file_exists "*.tf")
  if [ -n "$procfile" ] && [ -n "$terraform" ]; then
    migrations="${migrations}{\"category\":\"infrastructure\",\"from\":\"Heroku\",\"to\":\"Cloud IaC\",\"confidence\":0.70,\"signals\":[{\"type\":\"config_coexistence\",\"detail\":\"Procfile + .tf files\"}]},"
  fi

  echo "$migrations"
}

# ── Category 7: IDE/Toolchain Migration ──────────────────────────────

detect_toolchain_migrations() {
  local migrations=""

  # npm → pnpm / yarn
  local npm_lock=$(file_exists "package-lock.json")
  local pnpm_lock=$(file_exists "pnpm-lock.yaml")
  local yarn_lock=$(file_exists "yarn.lock")
  if [ -n "$npm_lock" ] && [ -n "$pnpm_lock" ]; then
    migrations="${migrations}{\"category\":\"toolchain\",\"from\":\"npm\",\"to\":\"pnpm\",\"confidence\":0.85,\"signals\":[{\"type\":\"lockfile_coexistence\",\"detail\":\"package-lock.json + pnpm-lock.yaml\"}]},"
  fi
  if [ -n "$npm_lock" ] && [ -n "$yarn_lock" ]; then
    migrations="${migrations}{\"category\":\"toolchain\",\"from\":\"npm\",\"to\":\"Yarn\",\"confidence\":0.85,\"signals\":[{\"type\":\"lockfile_coexistence\",\"detail\":\"package-lock.json + yarn.lock\"}]},"
  fi

  # Grunt/Gulp → modern bundler
  local grunt=$(file_exists "Gruntfile*")
  local gulp=$(file_exists "gulpfile*")
  local vite=$(file_exists "vite.config.*")
  local rollup=$(file_exists "rollup.config.*")
  if [ -n "$grunt" ] && { [ -n "$vite" ] || [ -n "$rollup" ]; }; then
    local to_tool="Vite"
    [ -n "$rollup" ] && to_tool="Rollup"
    local esc_tool=$(json_escape "$to_tool")
    migrations="${migrations}{\"category\":\"toolchain\",\"from\":\"Grunt\",\"to\":\"$esc_tool\",\"confidence\":0.80,\"signals\":[{\"type\":\"config_coexistence\",\"detail\":\"Gruntfile + modern bundler config\"}]},"
  fi

  echo "$migrations"
}

# ── Category 8: AI Tool Migration ────────────────────────────────────

detect_ai_tool_migrations() {
  local migrations=""

  # Cursor-only → multi-tool
  local cursor_dir=$(find "$REPO_DIR/.cursor" -maxdepth 0 -type d 2>/dev/null | head -1)
  local claude_dir=$(find "$REPO_DIR/.claude" -maxdepth 0 -type d 2>/dev/null | head -1)
  local claude_md=$(file_exists "CLAUDE.md")
  if [ -n "$cursor_dir" ] && [ -z "$claude_dir" ] && [ -z "$claude_md" ]; then
    migrations="${migrations}{\"category\":\"ai-tools\",\"from\":\"Cursor-only\",\"to\":\"Multi-tool\",\"confidence\":0.70,\"signals\":[{\"type\":\"config_presence\",\"detail\":\".cursor/ exists without .claude/ or CLAUDE.md\"}]},"
  fi

  # No AI config at all — only if the repo has actual source files (not empty/blank)
  if [ -z "$cursor_dir" ] && [ -z "$claude_dir" ] && [ -z "$claude_md" ]; then
    local src_file_count=$(find "$REPO_DIR" -maxdepth 3 -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.java" -o -name "*.go" -o -name "*.rb" -o -name "*.rs" -o -name "*.c" -o -name "*.cpp" -o -name "*.cs" \) -not -path "*/.git/*" -not -path "*/node_modules/*" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$src_file_count" -gt 0 ]; then
      migrations="${migrations}{\"category\":\"ai-tools\",\"from\":\"None\",\"to\":\"AI-assisted\",\"confidence\":0.90,\"signals\":[{\"type\":\"config_absence\",\"detail\":\"No .cursor/, .claude/, or CLAUDE.md found\"}]},"
    fi
  fi

  echo "$migrations"
}

# ── Comment Marker Detection ─────────────────────────────────────────

detect_comment_markers() {
  local todo_migrate=$(grep_count "TODO.*migrat\|TODO.*MIGRAT")
  local deprecated=$(grep_count "@deprecated\|DEPRECATED\|# DEPRECATED")
  local legacy=$(grep_count "LEGACY\|legacy.*code\|old.*implementation")
  local migrated=$(grep_count "MIGRATED\|# MIGRATED")

  echo "{\"todo_migrate\":$todo_migrate,\"deprecated\":$deprecated,\"legacy\":$legacy,\"migrated\":$migrated}"
}

# ── Migration Documentation Detection ───────────────────────────────

detect_migration_docs() {
  local docs=""
  local first=true
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    local rel="${f#$REPO_DIR/}"
    rel=$(json_escape "$rel")
    if [ "$first" = true ]; then
      first=false
    else
      docs="${docs}, "
    fi
    docs="${docs}\"$rel\""
  done < <(find "$REPO_DIR" -maxdepth 3 -type f \( -iname "*migration*" -o -iname "*migrate*" -o -iname "MIGRATION*" \) -not -path "*/.git/*" -not -path "*/node_modules/*" 2>/dev/null)

  echo "[$docs]"
}

# ── Dual Config Detection ───────────────────────────────────────────

detect_dual_configs() {
  local pairs=""
  local first=true

  # Check common config pairs
  local config_pairs=(
    "webpack.config.js:vite.config.ts"
    "webpack.config.js:vite.config.js"
    ".gitlab-ci.yml:.github/workflows"
    "Jenkinsfile:.github/workflows"
    "docker-compose.yml:kubernetes"
    "package-lock.json:pnpm-lock.yaml"
    "package-lock.json:yarn.lock"
    "Gruntfile.js:rollup.config.js"
    "Procfile:main.tf"
  )

  for pair in "${config_pairs[@]}"; do
    local f1="${pair%%:*}"
    local f2="${pair##*:}"
    local found1=$(file_exists "$f1")
    local found2=$(file_exists "$f2")
    if [ -n "$found1" ] && [ -n "$found2" ]; then
      if [ "$first" = true ]; then
        first=false
      else
        pairs="${pairs}, "
      fi
      local esc_f1=$(json_escape "$f1")
      local esc_f2=$(json_escape "$f2")
      pairs="${pairs}[\"$esc_f1\", \"$esc_f2\"]"
    fi
  done

  echo "[$pairs]"
}

# ── Main Output ──────────────────────────────────────────────────────

lang_migrations=$(detect_language_migrations)
fw_migrations=$(detect_framework_migrations)
arch_migrations=$(detect_architecture_migrations)
cloud_migrations=$(detect_cloud_migrations)
devops_migrations=$(detect_devops_migrations)
infra_migrations=$(detect_infra_migrations)
toolchain_migrations=$(detect_toolchain_migrations)
ai_migrations=$(detect_ai_tool_migrations)

all_migrations="${lang_migrations}${fw_migrations}${arch_migrations}${cloud_migrations}${devops_migrations}${infra_migrations}${toolchain_migrations}${ai_migrations}"

# Remove trailing comma
all_migrations="${all_migrations%,}"

comment_markers=$(detect_comment_markers)
migration_docs=$(detect_migration_docs)
dual_configs=$(detect_dual_configs)

# Determine if any migration was detected
detected="false"
if [ -n "$all_migrations" ]; then
  detected="true"
fi

# Count deprecation markers
dep_count=$(echo "$comment_markers" | sed 's/.*"deprecated":\([0-9]*\).*/\1/')

esc_repo_dir=$(json_escape "$REPO_DIR")

cat <<EOF
{
  "detected": $detected,
  "scannedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "repoDir": "$esc_repo_dir",
  "migrations": [$all_migrations],
  "migrationDocs": $migration_docs,
  "commentMarkers": $comment_markers,
  "dualConfigs": $dual_configs,
  "deprecationMarkers": $dep_count
}
EOF
