FROM python:3.11
WORKDIR /app
COPY . .
RUN pip install Flask Flask-SocketIO eventlet Gunicorn redis
EXPOSE 5002
CMD ["gunicorn", "-w", "1", "-k", "eventlet", "-b", "0.0.0.0:5002", "backend:app"]
