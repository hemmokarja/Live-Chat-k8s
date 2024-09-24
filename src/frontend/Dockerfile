FROM python:3.11
WORKDIR /app
COPY . .
RUN pip install requests Flask Gunicorn
EXPOSE 5001
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5001", "frontend:app"]