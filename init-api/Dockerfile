FROM python:3.12-slim

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends fonts-dejavu-core postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Prepared on a working connection and SHA-256 verified against official PyPI.
# Python dependencies install without contacting PyPI from the Timeweb builder.
COPY deploy-wheels /tmp/gbou-wheels
RUN python -m pip install --disable-pip-version-check --no-cache-dir \
    --no-index --find-links=/tmp/gbou-wheels --only-binary=:all: \
    --require-hashes -r /tmp/gbou-wheels/requirements.lock \
    && python -m pip check \
    && rm -rf /tmp/gbou-wheels

# Copy runtime sources explicitly, keeping wheels, local environments and
# developer configuration out of the application tree.
COPY app/ ./app/
COPY scripts/ ./scripts/
COPY alembic/ ./alembic/
COPY alembic.ini entrypoint.sh requirements.txt ./

RUN chmod +x entrypoint.sh scripts/backup_database.sh

EXPOSE 8080

CMD ["./entrypoint.sh"]
