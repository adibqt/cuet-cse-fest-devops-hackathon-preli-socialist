
FROM node:20-alpine

WORKDIR /app

ENV NODE_ENV=production
USER node

COPY --chown=node:node package*.json ./
RUN npm ci --only=production && npm cache clean --force

COPY --chown=node:node src ./src

EXPOSE 5921

CMD ["node", "src/gateway.js"]