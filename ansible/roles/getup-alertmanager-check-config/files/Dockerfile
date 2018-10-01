
FROM alpine

WORKDIR /

COPY run.sh /

RUN apk add nmap-ncat bash --no-cache && \
    chmod +x run.sh

USER 1001

CMD ["./run.sh"]

