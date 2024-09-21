FROM python:3.11
WORKDIR /app
COPY . .
RUN pip install Flask Flask-SocketIO eventlet
CMD ["python", "backend.py"]
