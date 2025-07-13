FROM node:20-alpine

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm install

COPY . .

EXPOSE 9000

CMD sh -c "until nc -z -v -w30 $RDS_INS 5432; do echo 'Waiting for database...'; sleep 5; done && npx medusa db:migrate && npm run dev"

