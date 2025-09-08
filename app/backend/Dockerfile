FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY server.py .
ENV REDIS_URL=redis://redis:6379
EXPOSE 8081
CMD ["python","server.py"]
