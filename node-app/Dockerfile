FROM node:alpine
LABEL org.opencontainers.image.source https://github.com/robsonandradev/devops-examples
WORKDIR /app

COPY package.json .

RUN yarn --prod

COPY src ./src

CMD yarn start
