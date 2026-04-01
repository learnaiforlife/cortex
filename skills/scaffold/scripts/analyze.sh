#!/bin/bash
# Cortex heuristic pre-scanner
# Outputs a quick ProjectProfile JSON from file system analysis
# No external dependencies required — pure shell

REPO_DIR="${1:-.}"

echo "{"
echo "  \"rootDir\": \"$REPO_DIR\","
echo "  \"scannedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","

# Detect languages by file count
echo "  \"detectedFiles\": {"
FIRST=true
for ext in ts tsx js jsx py go rs java kt rb php dart cs swift c cpp h hpp vue svelte; do
  count=$(find "$REPO_DIR" -name "*.${ext}" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/vendor/*" -not -path "*/dist/*" -not -path "*/__pycache__/*" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$count" -gt 0 ]; then
    [ "$FIRST" = true ] && FIRST=false || echo ","
    printf "    \"%s\": %s" "$ext" "$count"
  fi
done
echo ""
echo "  },"

# Detect key config/manifest files
echo "  \"keyFiles\": ["
FIRST=true
for f in package.json pyproject.toml requirements.txt go.mod Cargo.toml pom.xml build.gradle \
         docker-compose.yml docker-compose.yaml Dockerfile \
         .github/workflows .gitlab-ci.yml Jenkinsfile .circleci/config.yml \
         tsconfig.json next.config.js next.config.ts next.config.mjs \
         vite.config.ts vite.config.js webpack.config.js \
         tailwind.config.js tailwind.config.ts \
         prisma/schema.prisma \
         openapi.yaml openapi.json swagger.yaml swagger.json \
         .eslintrc.js .eslintrc.json eslint.config.js eslint.config.mjs \
         .prettierrc .prettierrc.json prettier.config.js \
         biome.json ruff.toml \
         turbo.json nx.json lerna.json pnpm-workspace.yaml \
         vercel.json netlify.toml fly.toml railway.toml \
         README.md CLAUDE.md AGENTS.md .cursorrules; do
  if [ -f "$REPO_DIR/$f" ] || [ -d "$REPO_DIR/$f" ]; then
    [ "$FIRST" = true ] && FIRST=false || echo ","
    printf "    \"%s\"" "$f"
  fi
done
echo ""
echo "  ],"

# Detect services from docker-compose
echo "  \"dockerServices\": ["
if [ -f "$REPO_DIR/docker-compose.yml" ] || [ -f "$REPO_DIR/docker-compose.yaml" ]; then
  DC_FILE="$REPO_DIR/docker-compose.yml"
  [ -f "$DC_FILE" ] || DC_FILE="$REPO_DIR/docker-compose.yaml"
  FIRST=true
  for svc in postgres mysql mongo redis rabbitmq kafka elasticsearch; do
    if grep -qi "$svc" "$DC_FILE" 2>/dev/null; then
      [ "$FIRST" = true ] && FIRST=false || echo ","
      printf "    \"%s\"" "$svc"
    fi
  done
  echo ""
fi
echo "  ],"

# Check existing AI setup
echo "  \"existingSetup\": {"
CLAUDE_MD="false"; [ -f "$REPO_DIR/CLAUDE.md" ] && CLAUDE_MD="true"
AGENTS_MD="false"; [ -f "$REPO_DIR/AGENTS.md" ] && AGENTS_MD="true"
CLAUDE_DIR="false"; [ -d "$REPO_DIR/.claude" ] && CLAUDE_DIR="true"
CURSOR_DIR="false"; [ -d "$REPO_DIR/.cursor" ] && CURSOR_DIR="true"
MCP_JSON="false"; [ -f "$REPO_DIR/.mcp.json" ] && MCP_JSON="true"
echo "    \"CLAUDE.md\": $CLAUDE_MD,"
echo "    \"AGENTS.md\": $AGENTS_MD,"
echo "    \".claude/\": $CLAUDE_DIR,"
echo "    \".cursor/\": $CURSOR_DIR,"
echo "    \".mcp.json\": $MCP_JSON"
echo "  }"

echo "}"
