# ---- 1段目：作る（ライブラリを入れる道具がそろった大きいイメージ）
FROM python:3.14 AS build
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- 2段目：動かす（必要なものだけを小さいイメージに）
FROM python:3.14-slim
COPY --from=build /install /usr/local
WORKDIR /app
COPY . .
RUN useradd --create-home appuser
USER appuser
EXPOSE 8000
CMD ["fastapi", "run", "main.py", "--port", "8000"]
