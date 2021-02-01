
FROM node:10.12.0-alpine as builder

RUN mkdir /app
WORKDIR /app
COPY .env Dockerfile Makefile elm-package.json package*json ./
COPY dist elm-stuff jssrc node_modules scss server* src tokenserver ./

ENV PATH="node_modules/.bin:$PATH"
RUN apk add --update \
           make \
           bash \
           build-dependencies \
           build-base \
           ruby \
           ruby-dev \
           rbenv \
           libffi-dev \
       && gem install --no-document \
           json \
           compass \
       && make prod \
           build-bundle build-js-minify-prod build-css-minify \
       && apk del build-dependencies
# we should just be able to do `npm install sass` see https://sass-lang.com/install



FROM mhart/alpine-node:10

WORKDIR /app
COPY --from=builder /app /app

EXPOSE 4201

CMD [ "npm", "start" ] # || sleep 1000000

