# Set the base image
FROM alpine:3.15.0

# Install required packages
RUN apk -v --update add \
    mariadb-connector-c \
    python3 \
    py-pip \
    groff \
    less \
    mailcap \
    mysql-client \
    curl \
    py-crcmod \
    bash \
    libc6-compat \
    gnupg \
    coreutils \
    gzip \
    go \
    git && \
    pip3 install --upgrade python-magic && \
    rm /var/cache/apk/*
    

# Set Default Environment Variables
ENV BACKUP_CREATE_DATABASE_STATEMENT=false
ENV TARGET_DATABASE_PORT=3306
ENV GOOGLE_CHAT_ENABLED=false
# Release commit for https://github.com/FiloSottile/age/tree/v1.0.0
ENV AGE_VERSION=552aa0a07de0b42c16126d3107bd8895184a69e7

COPY resources/google-chat-alert.sh /
RUN chmod +x /google-chat-alert.sh

# Copy sync script and execute
COPY resources/perform-sync.sh /
RUN chmod +x /perform-sync.sh
CMD ["sh", "/perform-sync.sh"]