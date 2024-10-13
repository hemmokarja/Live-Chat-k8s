FROM python:3.11-slim
WORKDIR /app
COPY . .
RUN pip install --no-cache-dir -r requirements.txt
CMD ["/bin/sh", "-c", "exec gunicorn -w 4 -b 0.0.0.0:$CONTAINER_PORT app:app"]