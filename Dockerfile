FROM certbot/dns-route53

# For standalone plugin
EXPOSE 80

RUN apk add --no-cache bash &&\
    pip install awscli

COPY certbot-s3 /bin/
RUN chmod u+x /bin/certbot-s3

ENTRYPOINT [ "certbot-s3" ]
