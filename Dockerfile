# Copyright 2022 The Sigstore Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM registry.access.redhat.com/ubi9/go-toolset@sha256:e91cbbd0b659498d029dd43e050c8a009c403146bfba22cbebca8bcd0ee7925f AS builder
ENV APP_ROOT=/opt/app-root
ENV GOPATH=$APP_ROOT

WORKDIR $APP_ROOT/src/
ADD go.mod go.sum $APP_ROOT/src/
RUN go mod download

# Add source code
ADD ./cmd/ $APP_ROOT/src/cmd/
ADD ./pkg/ $APP_ROOT/src/pkg/

ARG SERVER_LDFLAGS
RUN go build -ldflags "${SERVER_LDFLAGS}" ./cmd/timestamp-server
RUN CGO_ENABLED=0 go build -gcflags "all=-N -l" -ldflags "${SERVER_LDFLAGS}" -o timestamp-server_debug ./cmd/timestamp-server

# Multi-Stage production build
FROM registry.access.redhat.com/ubi9/go-toolset@sha256:e91cbbd0b659498d029dd43e050c8a009c403146bfba22cbebca8bcd0ee7925f as deploy

# Retrieve the binary from the previous stage
COPY --from=builder /opt/app-root/src/timestamp-server /usr/local/bin/timestamp-server

# Set the binary as the entrypoint of the container
CMD ["timestamp-server", "serve"]

# debug compile options & debugger
FROM registry.access.redhat.com/ubi9/go-toolset@sha256:e91cbbd0b659498d029dd43e050c8a009c403146bfba22cbebca8bcd0ee7925f as debug
COPY --from=deploy /usr/local/bin/timestamp-server /usr/local/bin/timestamp-server

WORKDIR $APP_ROOT/src/
ADD hack/tools/go.mod hack/tools/go.sum $APP_ROOT/src/
RUN go mod download

RUN go install github.com/go-delve/delve/cmd/dlv@v1.9.0

LABEL description="tsa"
LABEL io.k8s.description="tsa"
LABEL io.k8s.display-name="tsa"
LABEL io.openshift.tags="tsa"
LABEL summary="tsa"

# overwrite server and include debugger
COPY --from=builder /opt/app-root/src/timestamp-server_debug /usr/local/bin/timestamp-server
