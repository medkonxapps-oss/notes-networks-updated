FROM node:20-alpine

WORKDIR /app

# Install system deps for sharp and pdf processing
RUN apk add --no-cache \
  python3 make g++ \
  poppler-utils \
  libjpeg-turbo-dev

COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

EXPOSE 3000

CMD ["npm", "start"]
