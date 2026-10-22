FROM python:3.13-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && useradd --uid 10001 --create-home mysold
COPY . .
USER 10001
EXPOSE 8000
CMD ["sh", "-c", "python manage.py migrate && exec gunicorn --bind 0.0.0.0:8000 --workers 2 --threads 4 --timeout 90 --error-logfile - app:app"]
