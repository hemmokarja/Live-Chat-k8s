FROM python:3.11
WORKDIR /app
COPY . .
RUN pip install Flask Flask-SocketIO gevent Gunicorn redis
EXPOSE 5000
CMD ["gunicorn", "-w", "1", "-k", "gevent", "-b", "0.0.0.0:5000", "app:app"]