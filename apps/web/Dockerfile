# node:24.21.0-bookworm-slim
FROM node:26.12.1-bookworm-slim@sha256:88e480776c6149ff1d098cd304f44bf18057fb5d284a3329b78162d29821e28c AS base
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

FROM node:26.12.1-bookworm-slim@sha256:88e480776c6149ff1d098cd304f44bf18057fb5d284a3329b78162d29821e28c AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build --chown=node:node /prod/web .
USER node
EXPOSE 3000
CMD ["node", "src/server.js"]
