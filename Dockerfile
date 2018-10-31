FROM node:10.12.0

RUN mkdir /app
WORKDIR /app
ADD . .

RUN npm uninstall --save fsevents
ENV PATH="$PATH:./node_modules/.bin"

ENTRYPOINT make install start || sleep 1000000

EXPOSE 4201

