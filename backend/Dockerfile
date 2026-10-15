FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY key_service key_service
RUN useradd --create-home --uid 10001 kinoue && mkdir /data && chown kinoue:kinoue /data
USER kinoue
ENV KINOUE_DATA_DIR=/data
EXPOSE 8000
CMD ["uvicorn", "key_service.api:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000", "--no-access-log"]
