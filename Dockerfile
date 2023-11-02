FROM elixir:1.15.6-slim

WORKDIR /app

ADD . /app

RUN apt-get update && apt-get -y install npm build-essential inotify-tools
RUN npm install --prefix ./assets
RUN mix local.hex --force && mix local.rebar --force
RUN mix do deps.get, compile

EXPOSE 4000

CMD ["./dev"]