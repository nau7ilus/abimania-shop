FROM pretix/standalone:stable

USER root

ADD plugins /opt/plugins

RUN DJANGO_SETTINGS_MODULE= pip install -U /opt/plugins/pretix-abimania-theme && \
    cd /pretix/src && \
    sudo -u pretixuser make production

USER pretixuser

ENTRYPOINT ["pretix"]
CMD ["all"]
