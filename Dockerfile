FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt /app
RUN pip install -r requirements.txt
COPY . /app

# I know it's sensitive but it's fine
ENV IN_DOCKER=true MYSQL_ROOT_PASSWORD=root_password

EXPOSE 8000
CMD ["fastapi", "run", "api.py"]
