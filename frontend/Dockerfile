FROM node:lts-alpine AS dev

WORKDIR /app

COPY . /app

RUN npm install

EXPOSE 5173

ENTRYPOINT [ "npm", "run", "dev"]
