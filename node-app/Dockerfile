FROM node:alpine
WORKDIR /app

COPY package.json .

RUN yarn --prod

COPY src ./src

CMD yarn start
