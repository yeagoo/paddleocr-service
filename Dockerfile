FROM ccr-2vdh3abv-pub.cnc.bj.baidubce.com/paddlex/hps:paddlex3.0.3-cpu

# Official PaddleX HPS image already includes PaddlePaddle 3.0.0 +
# PaddleX + Serving plugin. No need for manual pip install.

# httpx for auth proxy (fastapi + uvicorn already in the image)
RUN pip install --no-cache-dir httpx

COPY pipeline_config.yaml /app/pipeline_config.yaml

# Pre-download all models at build time for fast cold starts
RUN python -c "from paddlex import create_pipeline; create_pipeline(pipeline='/app/pipeline_config.yaml'); print('All models downloaded')"

COPY auth_proxy.py /app/auth_proxy.py
COPY start.sh /app/start.sh

WORKDIR /app
EXPOSE 8000

HEALTHCHECK --interval=15s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["bash", "start.sh"]
