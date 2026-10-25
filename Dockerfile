FROM dart:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get --enforce-lockfile
COPY . .
RUN dart compile exe bin/yt2rssffs.dart -o /app/server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/server /app/server
EXPOSE 8080
ENTRYPOINT ["/app/server"]
