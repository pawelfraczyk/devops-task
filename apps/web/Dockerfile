# node:24.21.0-bookworm-slim
FROM node:26.12.0-bookworm-slim@sha256:742a0fe7320e09e0321222b68165e6ac731d30470e7ea7f98f9bfc3a6e1034fe AS base
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

FROM node:26.12.0-bookworm-slim@sha256:742a0fe7320e09e0321222b68165e6ac731d30470e7ea7f98f9bfc3a6e1034fe AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build --chown=node:node /prod/web .
USER node
EXPOSE 3000
CMD ["node", "src/server.js"]
