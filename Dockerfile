FROM postgres:latest

# Set default database credentials; override at runtime as needed.
ENV POSTGRES_DB=app_db \
    POSTGRES_USER=app_user \
    POSTGRES_PASSWORD=app_password

COPY init.sql /docker-entrypoint-initdb.d/001-init.sql

EXPOSE 5432

