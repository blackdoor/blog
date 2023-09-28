FROM squidfunk/mkdocs-material as build

WORKDIR /app

COPY . /app
RUN mkdocs build

FROM nginx
COPY --from=build /app /usr/share/nginx/html