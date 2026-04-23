FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY admin /app/admin
COPY scripts /app/scripts

EXPOSE 8080

CMD ["python", "scripts/serve_valley_admin.py", "--host", "0.0.0.0", "--port", "8080", "--root", "/app/admin", "--data", "/app/admin/valley_admin_data.json"]
