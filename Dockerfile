FROM postgres:latest

# Set default database credentials; override at runtime as needed.
ENV POSTGRES_DB=db \
    POSTGRES_USER=demigod

# POSTGRES_PASSWORD intentionally omitted so the value is provided at runtime.

COPY init.sql /docker-entrypoint-initdb.d/001-init.sql

EXPOSE 5432

