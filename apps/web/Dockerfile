# node:24.21.0-bookworm-slim
FROM node:26.13.0-bookworm-slim@sha256:add5c17c14752c54d2f3d519ec46a3815684d41c33f198bcb09fb998f7dcbf68 AS base
RUN corepack enable
WORKDIR /app

FROM base AS build
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/api/package.json apps/api/
COPY apps/web/package.json apps/web/
RUN pnpm install --frozen-lockfile --filter @devops-task/web --prod
COPY apps/web apps/web
RUN pnpm deploy --legacy --filter=@devops-task/web --prod /prod/web \
  && test -f /prod/web/public/index.html \
  && test -f /prod/web/src/server.js

FROM node:26.13.0-bookworm-slim@sha256:add5c17c14752c54d2f3d519ec46a3815684d41c33f198bcb09fb998f7dcbf68 AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build --chown=node:node /prod/web .
USER node
EXPOSE 3000
CMD ["node", "src/server.js"]
