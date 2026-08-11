# ╔═════════════════════════════════════════════════════╗
# ║                       SETUP                         ║
# ╚═════════════════════════════════════════════════════╝
# GLOBAL
  ARG APP_UID=1000 \
      APP_GID=1000 \
      APP_GO_VERSION=0 \
      APP_OTEL_BUILD="hec"

# :: FOREIGN IMAGES
  FROM 11notes/distroless AS distroless
  FROM 11notes/distroless:localhealth AS distroless-localhealth


# ╔═════════════════════════════════════════════════════╗
# ║                       BUILD                         ║
# ╚═════════════════════════════════════════════════════╝
# :: ENTRYPOINT
  FROM 11notes/go:${APP_GO_VERSION} AS entrypoint
  ARG APP_GO_VERSION \
      APP_OTEL_BUILD
  COPY ./build/entrypoint /go/entrypoint
  RUN set -ex; \
    cd /go/entrypoint; \
    go mod edit -go=${APP_GO_VERSION}; \
    sed -i 's|APP_OTEL_BUILD|'${APP_OTEL_BUILD}'|g' ./main.go; \
    eleven go build /entrypoint main.go; \
    eleven distroless /entrypoint;

# :: OPENTELEMETRY-COLLECTOR
  FROM 11notes/go:${APP_GO_VERSION} AS build
  COPY ./build/opentelemetry-collector /go/opentelemetry-collector
  ARG APP_VERSION \
      APP_OTEL_BUILD \
      BUILD_ROOT=/go/opentelemetry-collector

  RUN set -ex; \
    go install go.opentelemetry.io/collector/cmd/builder@v${APP_VERSION};

  RUN set -ex; \
    cd ${BUILD_ROOT}; \
    mkdir -p ${BUILD_ROOT}/.dist; \
    sed -i 's|APP_VERSION|'${APP_VERSION}'|g' ./${APP_OTEL_BUILD}.yml; \
    builder --config ${APP_OTEL_BUILD}.yml; \
    mv ${BUILD_ROOT}/.dist/opentelemetry-collector* ${BUILD_ROOT}/.dist/opentelemetry-collector;

  RUN set -ex; \
    eleven distroless ${BUILD_ROOT}/.dist/opentelemetry-collector;

# :: FILE SYSTEM
  FROM alpine AS file-system
  ARG APP_ROOT

  RUN set -ex; \
    mkdir -p /distroless${APP_ROOT}/etc;


# ╔═════════════════════════════════════════════════════╗
# ║                       IMAGE                         ║
# ╚═════════════════════════════════════════════════════╝
# :: HEADER
  FROM scratch

  # :: default arguments
    ARG TARGETPLATFORM \
        TARGETOS \
        TARGETARCH \
        TARGETVARIANT \
        APP_IMAGE \
        APP_NAME \
        APP_VERSION \
        APP_ROOT \
        APP_UID \
        APP_GID \
        APP_NO_CACHE

  # :: default environment
    ENV APP_IMAGE=${APP_IMAGE} \
        APP_NAME=${APP_NAME} \
        APP_VERSION=${APP_VERSION} \
        APP_ROOT=${APP_ROOT}

  # :: multi-stage
    COPY --from=distroless / /
    COPY --from=distroless-localhealth / /
    COPY --from=entrypoint /distroless/ /
    COPY --from=build /distroless/ /
    COPY --from=file-system --chown=${APP_UID}:${APP_GID} /distroless/ /
    COPY --chown=${APP_UID}:${APP_GID} ./rootfs/ /

# :: PERSISTENT DATA
  VOLUME ["${APP_ROOT}/etc"]

# :: MONITORING
  HEALTHCHECK --interval=5s --timeout=2s --start-period=5s \
    CMD ["/usr/local/bin/localhealth", "http://127.0.0.1:13133/"]

# :: EXECUTE
  USER ${APP_UID}:${APP_GID}
  ENTRYPOINT ["/usr/local/bin/entrypoint"]