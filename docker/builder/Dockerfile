FROM python:3.12-bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash ca-certificates curl gnupg nodejs npm postgresql-client \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://pgp.mongodb.com/server-7.0.asc | gpg --dearmor -o /etc/apt/keyrings/mongodb-server-7.0.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/mongodb-server-7.0.gpg] https://repo.mongodb.org/apt/debian bookworm/mongodb-org/7.0 main" > /etc/apt/sources.list.d/mongodb-org-7.0.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends mongodb-mongosh \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY docker/builder/entrypoint.sh /usr/local/bin/valley-builder

RUN chmod +x /usr/local/bin/valley-builder

ENTRYPOINT ["valley-builder"]
CMD ["release"]
