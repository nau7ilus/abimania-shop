FROM pretix/standalone:stable

USER root

RUN pip install -U pretix-passbook && \
    cd /pretix/src && \
    sudo -u pretixuser make production

USER pretixuser

ENTRYPOINT ["pretix"]
CMD ["all"]
