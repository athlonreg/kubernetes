#FROM altinity/clickhouse-server:22.8.15.25.altinitystable
FROM clickhouse/clickhouse-server:22.8-alpine

ENV TZ Asia/Shanghai

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories && \
    apk add --update --no-cache tzdata && cp /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo ${TZ} > /etc/timezone