# trunk-ignore-all(checkov/CKV_DOCKER_2)
# trunk-ignore-all(checkov/CKV_DOCKER_3)
# trunk-ignore-all(hadolint/DL3013)
# trunk-ignore-all(hadolint/DL3033)
FROM amazon/aws-lambda-python:3.10

RUN yum update -y && \
    yum install -y gcc gmp-devel && \
    yum clean all && \
    rm -rf /var/cache/yum

WORKDIR /var/task

RUN pip install --no-cache-dir uv && uv venv

COPY pyproject.toml ./

RUN pip install --no-cache-dir -e '.[lambda-dependencies]'

COPY build ./build
COPY deployments ./deployments
COPY relayers.json ./relayers.json
COPY .env ./
COPY fee_balancer.py ./
COPY constants.py ./kakarot_scripts/constants.py
COPY starknet.py ./kakarot_scripts/utils/starknet.py
COPY data ./kakarot_scripts/data

CMD ["fee_balancer.lambda_handler"]
