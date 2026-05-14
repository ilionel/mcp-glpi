# syntax=docker/dockerfile:1
# MCP Server for GLPI — dual transport:
#   stdio (default)  : invoqué par Claude Desktop via docker run -i
#   http (MCP_TRANSPORT=http) : daemon HTTP StreamableHTTP, routé par Traefik sous /mcp

# ── Stage 1 : Build TypeScript ────────────────────────────────────────────────
FROM node:22-alpine AS builder
WORKDIR /app
ENV NPM_CONFIG_UPDATE_NOTIFIER=false
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src/ ./src/
RUN npm run build

# ── Stage 2 : Runtime (image minimale) ───────────────────────────────────────
FROM node:22-alpine AS runtime
WORKDIR /app
ENV NPM_CONFIG_UPDATE_NOTIFIER=false

# Dépendances de production uniquement
COPY package*.json ./
RUN npm ci --omit=dev && rm -rf /root/.npm

# Artifacts compilés
COPY --from=builder /app/dist ./dist

LABEL org.opencontainers.image.title="mcp-glpi" \
      org.opencontainers.image.description="MCP Server for GLPI ITSM" \
      org.opencontainers.image.source="https://github.com/ilionel/mcp-glpi"

# Utilisateur non-root
RUN addgroup -S mcp && adduser -S mcp -G mcp
USER mcp

# Variables d'environnement attendues au runtime
# GLPI_URL          URL de l'instance GLPI (ex: http://glpi en Docker)
# GLPI_APP_TOKEN    Token applicatif GLPI (GLPI_API_APP_TOKEN dans .env)
# GLPI_USER_TOKEN   Token utilisateur GLPI (GLPI_API_USER_TOKEN dans .env)
# MCP_TRANSPORT     "http" pour activer le mode daemon HTTP (défaut: stdio)
# PORT              Port d'écoute en mode HTTP (défaut: 3000)
# MCP_AUTH_TOKEN    Bearer token requis sur /mcp en mode HTTP

# Port HTTP (inactif en mode stdio)
EXPOSE 3000

# Healthcheck HTTP (actif uniquement si MCP_TRANSPORT=http)
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

ENTRYPOINT ["node", "dist/index.js"]
