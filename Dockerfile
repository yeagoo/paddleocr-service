FROM paddlepaddle/paddle:3.3.1

RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

# Install PaddleX 3.5.1 with OCR extras
RUN pip install --no-cache-dir "paddlex[ocr]>=3.5.1,<3.6.0"

# Install serving plugin
RUN paddlex --install serving

# Auth proxy dependencies (fastapi + uvicorn already installed by paddlex serving)
RUN pip install --no-cache-dir httpx

# Copy config first so model pre-download uses it (enables chart recognition)
COPY pipeline_config.yaml /app/pipeline_config.yaml

# Pre-download all models including PP-Chart2Table
RUN python -c "from paddlex import create_pipeline; create_pipeline(pipeline='/app/pipeline_config.yaml'); print('All models downloaded')"

COPY auth_proxy.py /app/auth_proxy.py
COPY start.sh /app/start.sh

WORKDIR /app
EXPOSE 8000

HEALTHCHECK --interval=15s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["bash", "start.sh"]
